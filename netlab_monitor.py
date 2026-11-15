import subprocess
import socket
import os
import json
import argparse
from datetime import datetime


ESCALERA_CAPAS = [
    "Enlace/VLAN",
    "IP/Gateway",
    "Rutas/OSPF",
    "NAT",
    "Servicios"
]


def cargar_config(ruta_json):
    """Carga el archivo de configuracion externo JSON."""
    with open(ruta_json, "r", encoding="utf-8") as f:
        return json.load(f)


def run_host_cmd(comando):
    """Ejecuta un comando en el sistema anfitrion."""
    try:
        res = subprocess.run(comando, shell=True, capture_output=True, text=True, timeout=5)
        return res.stdout.strip(), res.returncode
    except Exception as e:
        return str(e), 1


def run_docker_cmd(nodo, comando, prefijo="clab-proyecto-grupo1-"):
    """Ejecuta comandos dentro de un contenedor y maneja errores sin abortar el script."""
    cmd_completo = f"docker exec {prefijo}{nodo} {comando}"
    try:
        res = subprocess.run(cmd_completo, shell=True, capture_output=True, text=True, timeout=6)
        salida = (res.stdout + "\n" + res.stderr).strip()
        return salida, res.returncode
    except Exception as e:
        return str(e), 1


def check_inventario(config):
    """Verificacion 1: Inventario de nodos e IPs desde la configuracion."""
    fallas = []
    detalles_ok = []
    prefijo = config.get("prefijo_clab", "clab-proyecto-grupo1-")
    print("[*] 1. Revisando Inventario (Nodos e IPs)...")

    for nodo, ip_esperada in config.get("nodos", {}).items():
        if ip_esperada == "bridge":
            out, rc = run_host_cmd(f"ip -br link show {nodo}")
            if rc != 0 or not out:
                fallas.append(f"Bridge {nodo} no existe en el host (Capa: Enlace/VLAN)")
            else:
                detalles_ok.append(f"Bridge {nodo} activo en host")
            continue

        out, rc = run_docker_cmd(nodo, "sh -c 'ip -br a 2>/dev/null || ip a'", prefijo)
        if rc != 0:
            fallas.append(f"Contenedor {nodo} no responde a docker exec (Capa: Enlace/VLAN)")
        elif ip_esperada not in out:
            fallas.append(f"Falta IP esperada {ip_esperada} en el nodo {nodo} (Capa: IP/Gateway)")
        else:
            detalles_ok.append(f"Nodo {nodo} tiene IP {ip_esperada}")

    return len(fallas) == 0, fallas if fallas else detalles_ok


def check_vlans(config):
    """Verificacion 2: Interfaces y VLANs usando 'ip -br a' e 'ip -d link' por nodo."""
    fallas = []
    detalles_ok = []
    prefijo = config.get("prefijo_clab", "clab-proyecto-grupo1-")
    print("[*] 2. Revisando Interfaces y VLANs (ip -br a / ip -d link)...")

    # 1. Revisar 'ip -br a' e 'ip -d link' por cada nodo del inventario
    for nodo, ip_esperada in config.get("nodos", {}).items():
        if ip_esperada == "bridge":
            continue
        out_br, rc_br = run_docker_cmd(nodo, "sh -c 'ip -br a 2>/dev/null || ip a'", prefijo)
        out_link, rc_link = run_docker_cmd(nodo, "sh -c 'ip -d link 2>/dev/null || ip link'", prefijo)
        if rc_br != 0 or rc_link != 0:
            fallas.append(f"No se pudo leer 'ip -br a' o 'ip -d link' en {nodo} (Capa: Enlace/VLAN)")

    # 2. Verificar subinterfaces 802.1Q en r2 y en los clientes segun config["vlans"]
    out_r2_br, _ = run_docker_cmd("r2", "sh -c 'ip -br a 2>/dev/null || ip a'", prefijo)
    out_r2_link, _ = run_docker_cmd(
        "r2",
        "sh -c 'ip -d link 2>/dev/null; ip link; cat /proc/net/vlan/config 2>/dev/null'",
        prefijo
    )

    for vlan in config.get("vlans", []):
        vlan_id = vlan["id"]
        red = vlan["red"]
        mascara = red.split("/")[1]
        gw_cidr = f"{vlan['gateway']}/{mascara}"

        tiene_subif_r2 = (
            f"vlan protocol 802.1Q id {vlan_id}" in out_r2_link
            or f"id {vlan_id}" in out_r2_link
            or f".{vlan_id}@" in out_r2_link
            or f"| {vlan_id} " in out_r2_link
        )
        if not tiene_subif_r2:
            fallas.append(f"Falta subinterfaz 802.1Q para VLAN {vlan_id} en r2 (Capa: Enlace/VLAN)")
        elif gw_cidr not in out_r2_br and vlan["gateway"] not in out_r2_br:
            fallas.append(f"Falta IP de Gateway {gw_cidr} para VLAN {vlan_id} en r2 (Capa: IP/Gateway)")
        else:
            detalles_ok.append(f"r2 subinterfaz VLAN {vlan_id} activa con gateway {gw_cidr}")

        # Verificar cliente asociado a la VLAN (si esta definido o si se deduce por prefijo de red)
        cliente = vlan.get("cliente")
        if not cliente:
            prefijo_ip = ".".join(vlan["gateway"].split(".")[:3]) + "."
            base_red = int(red.split("/")[0].split(".")[3])
            host_max = base_red + (2 ** (32 - int(mascara))) - 1
            for n, ip_n in config.get("nodos", {}).items():
                if n.startswith("pc-") and ip_n.startswith(prefijo_ip):
                    ultimo_octeto = int(ip_n.split(".")[3])
                    if base_red < ultimo_octeto < host_max:
                        cliente = n
                        break

        if cliente and cliente in config.get("nodos", {}):
            out_cli_link, rc_cli = run_docker_cmd(
                cliente,
                "sh -c 'ip -d link 2>/dev/null; ip link; cat /proc/net/vlan/config 2>/dev/null'",
                prefijo
            )
            out_cli_br, _ = run_docker_cmd(cliente, "sh -c 'ip -br a 2>/dev/null || ip a'", prefijo)
            ip_cli = config["nodos"][cliente]
            tiene_vlan_cli = (
                f"id {vlan_id}" in out_cli_link
                or f".{vlan_id}@" in out_cli_link
                or f"| {vlan_id} " in out_cli_link
            )
            if rc_cli != 0:
                fallas.append(f"No se pudo verificar interfaz VLAN en {cliente} (Capa: Enlace/VLAN)")
            elif not tiene_vlan_cli:
                fallas.append(f"VLAN ID incorrecto o ausente en {cliente}: se esperaba VLAN {vlan_id} (Capa: Enlace/VLAN)")
            elif ip_cli not in out_cli_br:
                fallas.append(f"Cliente {cliente} no tiene asignada la IP {ip_cli} en su interfaz VLAN {vlan_id} (Capa: IP/Gateway)")
            else:
                detalles_ok.append(f"Cliente {cliente} en VLAN {vlan_id} (802.1Q id {vlan_id}) con IP {ip_cli}")

    return len(fallas) == 0, fallas if fallas else detalles_ok


def check_rutas(config):
    """Verificacion 3: 'ip route' por router contra las rutas esperadas e ip_forward."""
    fallas = []
    detalles_ok = []
    prefijo = config.get("prefijo_clab", "clab-proyecto-grupo1-")
    print("[*] 3. Revisando Rutas (ip route por router)...")

    for router in config.get("ospf_routers", ["r1", "r2", "r3"]):
        out_fw, rc_fw = run_docker_cmd(router, "sysctl -n net.ipv4.ip_forward", prefijo)
        if rc_fw != 0 or out_fw.strip() != "1":
            fallas.append(f"IP forwarding (net.ipv4.ip_forward) esta apagado en {router} (Capa: IP/Gateway)")

    for router, rutas in config.get("rutas_esperadas", {}).items():
        out, rc = run_docker_cmd(router, "ip route", prefijo)
        if rc != 0:
            fallas.append(f"Error al consultar 'ip route' en {router} (Capa: Rutas/OSPF)")
            continue
        faltantes = []
        for ruta in rutas:
            if ruta not in out:
                faltantes.append(ruta)
                fallas.append(f"Ruta esperada '{ruta}' no encontrada en {router} (Capa: Rutas/OSPF)")
        if not faltantes:
            detalles_ok.append(f"Router {router} contiene todas las rutas esperadas ({', '.join(rutas)})")

    return len(fallas) == 0, fallas if fallas else detalles_ok


def check_conectividad(config):
    """Verificacion 4: Matriz de ping y traceroute clientes -> servidores y clientes -> externo."""
    fallas = []
    detalles_ok = []
    prefijo = config.get("prefijo_clab", "clab-proyecto-grupo1-")
    print("[*] 4. Revisando Conectividad (Matriz de ping y traceroute)...")

    clientes = [n for n in config.get("nodos", {}) if n.startswith("pc-")]
    destinos = list(config.get("servicios", {}).keys())
    if "externo" in config.get("nodos", {}) and "externo" not in destinos:
        destinos.append("externo")

    for c in clientes:
        for d in destinos:
            ip_dest = config["nodos"].get(d) or config["servicios"].get(d, {}).get("ip")
            if not ip_dest:
                continue

            # 1. Prueba de Ping
            _, rc_ping = run_docker_cmd(c, f"ping -c 2 -W 2 {ip_dest}", prefijo)
            if rc_ping != 0:
                capa = "NAT" if d == "externo" else "IP/Gateway"
                fallas.append(f"Fallo ping desde {c} hacia {d} [{ip_dest}] (Capa: {capa})")
                continue

            # 2. Prueba de Traceroute
            out_tr, rc_tr = run_docker_cmd(
                c,
                f"sh -c 'traceroute -I -n -w 1 -m 6 {ip_dest} 2>/dev/null || traceroute -n -w 1 -m 6 {ip_dest}'",
                prefijo
            )
            if rc_tr != 0 or ip_dest not in out_tr:
                fallas.append(f"Fallo traceroute desde {c} hacia {d} [{ip_dest}] (Capa: Rutas/OSPF)")
            else:
                detalles_ok.append(f"Ping y traceroute OK: {c} -> {d} ({ip_dest})")

    return len(fallas) == 0, fallas if fallas else detalles_ok


def obtener_mgmt_ip_y_asegurar_ruta(srv, ip_srv, prefijo):
    """Obtiene la IP de gestion del contenedor y asegura ruta en el host para socket.connect."""
    cmd = f"docker inspect -f '{{{{range .NetworkSettings.Networks}}}}{{{{.IPAddress}}}}{{{{end}}}}' {prefijo}{srv}"
    mgmt_ip, rc = run_host_cmd(cmd)
    if rc == 0 and mgmt_ip:
        run_host_cmd(f"sudo ip route replace {ip_srv}/32 via {mgmt_ip}")
        return mgmt_ip.strip()
    return None


def check_servicios(config):
    """Verificacion 5: Conexion por socket a los puertos y lectura de ss -tulpn."""
    fallas = []
    detalles_ok = []
    prefijo = config.get("prefijo_clab", "clab-proyecto-grupo1-")
    print("[*] 5. Revisando Servicios (socket y ss -tulpn)...")

    for srv, detalles in config.get("servicios", {}).items():
        ip = detalles["ip"]
        puerto = int(detalles["puerto"])
        proto = detalles.get("protocolo", "tcp").lower()

        # 1. Verificar ss -tulpn dentro del contenedor del servidor
        out_ss, rc_ss = run_docker_cmd(srv, "ss -tulpn", prefijo)
        if rc_ss != 0 or f":{puerto}" not in out_ss:
            fallas.append(f"Servicio no esta escuchando en puerto {puerto}/{proto} segun 'ss -tulpn' en {srv} (Capa: Servicios)")
            continue

        # 2. Verificar que el servidor tenga su IP del plan VLSM activa
        out_ip, rc_ip = run_docker_cmd(srv, "sh -c 'ip -br a 2>/dev/null || ip a'", prefijo)
        if rc_ip != 0 or ip not in out_ip:
            fallas.append(f"Servidor {srv} no tiene la IP {ip} configurada (Capa: IP/Gateway)")
            continue

        # 3. Verificar conexion por socket de Python hacia el puerto del servicio
        mgmt_ip = obtener_mgmt_ip_y_asegurar_ruta(srv, ip, prefijo)
        tipo_sock = socket.SOCK_STREAM if proto == "tcp" else socket.SOCK_DGRAM
        conectado = False
        for ip_intento in ([ip, mgmt_ip] if mgmt_ip else [ip]):
            try:
                s = socket.socket(socket.AF_INET, tipo_sock)
                s.settimeout(2)
                s.connect((ip_intento, puerto))
                s.close()
                conectado = True
                break
            except Exception:
                pass

        if not conectado:
            fallas.append(f"No se pudo conectar por socket {proto.upper()} a {srv} ({ip}:{puerto}) (Capa: Servicios)")
        else:
            detalles_ok.append(f"Servicio {srv} ({ip}:{puerto}/{proto}) activo en ss -tulpn y accesible por socket")

    return len(fallas) == 0, fallas if fallas else detalles_ok


def check_ospf(config):
    """Verificacion 6: Vecinos OSPF en estado Full."""
    fallas = []
    detalles_ok = []
    prefijo = config.get("prefijo_clab", "clab-proyecto-grupo1-")
    esperados = int(config.get("vecinos_ospf_esperados", 2))
    print("[*] 6. Revisando OSPF (Vecinos en estado Full)...")

    for router in config.get("ospf_routers", ["r1", "r2", "r3"]):
        out, rc = run_docker_cmd(router, "vtysh -c 'show ip ospf neighbor'", prefijo)
        if rc != 0:
            fallas.append(f"No se pudo consultar OSPF en {router} (Capa: Rutas/OSPF)")
            continue

        vecinos_full = sum(1 for linea in out.splitlines() if "Full" in linea)
        if vecinos_full < esperados:
            fallas.append(
                f"Falla OSPF en {router}: {vecinos_full}/{esperados} vecinos en estado Full (Capa: Rutas/OSPF)"
            )
        else:
            detalles_ok.append(f"Router {router} tiene {vecinos_full}/{esperados} vecinos OSPF en estado Full")

    return len(fallas) == 0, fallas if fallas else detalles_ok


def check_nat(config):
    """Verificacion 7: Reglas, contadores y comprobacion de que externo ve la IP de r1 y no la del cliente."""
    fallas = []
    detalles_ok = []
    prefijo = config.get("prefijo_clab", "clab-proyecto-grupo1-")
    nat_cfg = config.get("nat", {})
    router_nat = nat_cfg.get("router", "r1")
    ip_pub_r1 = nat_cfg.get("ip_publica_r1", "203.0.113.1")
    ip_externo = nat_cfg.get("ip_externo", config.get("nodos", {}).get("externo", "203.0.113.2"))
    print("[*] 7. Revisando NAT (Reglas, contadores e IP vista por externo)...")

    # 1. Generar trafico desde un cliente hacia externo para actualizar contadores y logs en externo
    clientes = [n for n in config.get("nodos", {}) if n.startswith("pc-")]
    cliente_prueba = clientes[0] if clientes else "pc-admin"
    ip_cliente = config.get("nodos", {}).get(cliente_prueba, "172.16.1.2")

    run_docker_cmd("externo", "sh -c 'pgrep nginx >/dev/null || nginx'", prefijo)
    run_docker_cmd(cliente_prueba, f"curl -s --max-time 2 http://{ip_externo} >/dev/null", prefijo)
    run_docker_cmd(cliente_prueba, f"ping -c 1 -W 1 {ip_externo} >/dev/null", prefijo)

    # 2. Revisar regla MASQUERADE y contadores en r1
    out_nat, rc_nat = run_docker_cmd(router_nat, "iptables -t nat -L POSTROUTING -v -n", prefijo)
    if rc_nat != 0 or "MASQUERADE" not in out_nat:
        fallas.append(f"Falta regla MASQUERADE en POSTROUTING de tabla nat en {router_nat} (Capa: NAT)")
        return False, fallas

    paquetes_traducidos = 0
    for linea in out_nat.splitlines():
        if "MASQUERADE" in linea:
            partes = linea.split()
            if partes and partes[0].isdigit():
                paquetes_traducidos += int(partes[0])

    if paquetes_traducidos <= 0:
        fallas.append(f"El contador de paquetes MASQUERADE en {router_nat} es 0 (Capa: NAT)")
    else:
        detalles_ok.append(f"Regla MASQUERADE activa en {router_nat} con contador pkts={paquetes_traducidos}")

    # 3. Comprobar que externo ve la IP de r1 (203.0.113.1) y NO la IP privada del cliente
    out_log, _ = run_docker_cmd("externo", "tail -n 5 /var/log/nginx/access.log", prefijo)
    out_neigh, _ = run_docker_cmd("externo", "ip neigh", prefijo)

    if ip_cliente in out_log:
        fallas.append(f"Nodo externo vio la IP privada del cliente ({ip_cliente}) sin traducir (Capa: NAT)")
    elif ip_pub_r1 in out_log or ip_pub_r1 in out_neigh:
        detalles_ok.append(f"Comprobado: externo ve la IP de {router_nat} ({ip_pub_r1}) y no la del cliente ({ip_cliente})")
    else:
        fallas.append(f"No se pudo confirmar trafico traducido con IP {ip_pub_r1} llegando a externo (Capa: NAT)")

    return len(fallas) == 0, fallas if fallas else detalles_ok


def diagnosticar_capa_raiz(resultados):
    """Determina la capa donde se ubica la falla raiz siguiendo la escalera del curso."""
    capas_con_falla = []
    for _, (estado, detalles) in resultados.items():
        if not estado:
            for d in detalles:
                for capa in ESCALERA_CAPAS:
                    if f"Capa: {capa}" in d and capa not in capas_con_falla:
                        capas_con_falla.append(capa)

    for capa in ESCALERA_CAPAS:
        if capa in capas_con_falla:
            return capa, capas_con_falla
    return "Ninguna (Red Operativa)", []


def generar_reporte(resultados, ruta_txt="reporte_monitor.txt", ruta_json=None):
    """Verificacion 8: Genera el reporte en texto (y opcionalmente JSON) y sale con exit code adecuado."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    todo_ok = all(estado for estado, _ in resultados.values())
    capa_raiz, capas_afectadas = diagnosticar_capa_raiz(resultados)

    lineas = [
        "=== Reporte NetLab Monitor ===",
        f"Fecha: {timestamp}",
        f"Estado Global: {'OK (7/7 verificaciones exitosas)' if todo_ok else 'FAIL (Se detectaron fallas)'}",
        f"Escalera de Diagnostico: {' -> '.join(ESCALERA_CAPAS)}",
        f"Capa de Falla Raiz: {capa_raiz}",
        ""
    ]

    for prueba, (estado, detalles) in resultados.items():
        etiqueta = "OK" if estado else "FAIL"
        lineas.append(f"[{etiqueta}] {prueba}")
        for d in detalles:
            pref = "  + " if estado else "  -> "
            lineas.append(f"{pref}{d}")

    contenido_reporte = "\n".join(lineas) + "\n"
    print("\n" + contenido_reporte)

    try:
        with open(ruta_txt, "w", encoding="utf-8") as f:
            f.write(contenido_reporte)
    except PermissionError:
        run_host_cmd(f"sudo rm -f {ruta_txt}")
        with open(ruta_txt, "w", encoding="utf-8") as f:
            f.write(contenido_reporte)

    print(f"[*] Reporte guardado en: {os.path.abspath(ruta_txt)}")

    if ruta_json:
        reporte_dict = {
            "fecha": timestamp,
            "estado_global": "OK" if todo_ok else "FAIL",
            "capa_falla_raiz": capa_raiz,
            "capas_afectadas": capas_afectadas,
            "verificaciones": {
                prueba: {
                    "estado": "OK" if estado else "FAIL",
                    "detalles": detalles
                }
                for prueba, (estado, detalles) in resultados.items()
            }
        }
        try:
            with open(ruta_json, "w", encoding="utf-8") as fj:
                json.dump(reporte_dict, fj, indent=4, ensure_ascii=False)
        except PermissionError:
            run_host_cmd(f"sudo rm -f {ruta_json}")
            with open(ruta_json, "w", encoding="utf-8") as fj:
                json.dump(reporte_dict, fj, indent=4, ensure_ascii=False)
        print(f"[*] Reporte JSON guardado en: {os.path.abspath(ruta_json)}")

    if not todo_ok:
        raise SystemExit(1)
    raise SystemExit(0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NetLab Monitor - Auditoria automatica por capas")
    parser.add_argument("-c", "--config", default="monitor.json", help="Ruta al archivo de configuracion JSON")
    parser.add_argument("-o", "--output", default="reporte_monitor.txt", help="Ruta del archivo de reporte en texto")
    parser.add_argument("-j", "--json", default="reporte_monitor.json", help="Ruta del reporte en formato JSON")
    args = parser.parse_args()

    config = cargar_config(args.config)
    resultados = {
        "1. Inventario (Capa IP/Gateway)": check_inventario(config),
        "2. Interfaces y VLANs (Capa Enlace/VLAN)": check_vlans(config),
        "3. Rutas (Capa Rutas/OSPF)": check_rutas(config),
        "4. Conectividad (Capa IP/Gateway -> Rutas/OSPF)": check_conectividad(config),
        "5. Servicios (Capa Servicios)": check_servicios(config),
        "6. OSPF (Capa Rutas/OSPF)": check_ospf(config),
        "7. NAT (Capa NAT)": check_nat(config),
    }

    generar_reporte(resultados, ruta_txt=args.output, ruta_json=args.json)
