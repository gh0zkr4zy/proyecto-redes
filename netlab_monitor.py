import json
import subprocess
import socket
import argparse
from datetime import datetime
import sys

def cargar_config(ruta_json):
    """Carga la topología esperada."""
    with open(ruta_json, 'r') as f:
        return json.load(f)

def run_docker_cmd(nodo, comando, prefijo="clab-proyecto-"):
    """Ejecuta comandos en los nodos y evita que el script explote si fallan."""
    cmd_completo = f"docker exec {prefijo}{nodo} {comando}"
    try:
        resultado = subprocess.run(cmd_completo, shell=True, capture_output=True, text=True, timeout=5)
        return resultado.stdout.strip(), resultado.returncode
    except Exception as e:
        return str(e), 1

def check_inventario(config):
    """Verificación 1: Nodos e IPs."""
    fallas = []
    print("[*] Revisando Inventario...")
    for nodo, ip_esperada in config["nodos"].items():
        if ip_esperada == "bridge":
            continue
        out, rc = run_docker_cmd(nodo, "ip a")
        if rc != 0 or ip_esperada not in out:
            fallas.append(f"Falta IP {ip_esperada} en nodo {nodo}")
    return len(fallas) == 0, fallas

def check_ospf(config):
    """Verificación 6: OSPF Vecinos Full."""
    fallas = []
    print("[*] Revisando OSPF...")
    for router in config["ospf_routers"]:
        out, rc = run_docker_cmd(router, "vtysh -c 'show ip ospf neighbor'")
        if rc != 0 or "Full" not in out:
            fallas.append(f"Falla OSPF en {router}: Vecinos no están en Full")
    return len(fallas) == 0, fallas

def check_vlans(config):
    """Verificación 2: Interfaces VLANs en r2."""
    fallas = []
    print("[*] Revisando VLANs...")
    out, rc = run_docker_cmd("r2", "ip -d link")
    if "vlan id 10" not in out:
        fallas.append("Falta subinterfaz VLAN 10 en r2 (Capa Enlace/VLAN)")
    if "vlan id 20" not in out:
        fallas.append("Falta subinterfaz VLAN 20 en r2 (Capa Enlace/VLAN)")
    return len(fallas) == 0, fallas

def check_rutas(config):
    """Verificación 3: Rutas esperadas en la tabla."""
    fallas = []
    print("[*] Revisando Rutas...")
    for router, rutas in config.get("rutas_esperadas", {}).items():
        out, rc = run_docker_cmd(router, "ip route")
        for ruta in rutas:
            if ruta not in out:
                fallas.append(f"Ruta {ruta} no está en {router} (Capa Rutas/OSPF)")
    return len(fallas) == 0, fallas

def check_conectividad(config):
    """Verificación 4: Matriz de ping."""
    fallas = []
    print("[*] Revisando Conectividad (Ping)...")
    clientes = ["pc-admin", "pc-ventas"]
    destinos = ["srv-web", "srv-datos", "externo"]
    
    for c in clientes:
        for d in destinos:
            ip_dest = config["nodos"][d]
            out, rc = run_docker_cmd(c, f"ping -c 2 -W 2 {ip_dest}")
            if rc != 0:
                fallas.append(f"Sin ping desde {c} hacia {d} [{ip_dest}] (Capa IP/Gateway)")
    return len(fallas) == 0, fallas

def check_servicios(config):
    """Verificación 5: Conexión por socket y ss -tulpn."""
    fallas = []
    print("[*] Revisando Servicios (Sockets)...")
    for srv, detalles in config["servicios"].items():
        ip = detalles["ip"]
        puerto = detalles["puerto"]
        
        # 1. Check socket
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2)
        try:
            s.connect((ip, puerto))
            s.close()
        except Exception as e:
            fallas.append(f"Puerto {puerto} cerrado en {srv} desde el script (Capa Servicios)")
            
        # 2. Check ss -tulpn dentro del contenedor
        out, rc = run_docker_cmd(srv, "ss -tulpn")
        if str(puerto) not in out:
            fallas.append(f"Servicio no está escuchando en puerto {puerto} dentro de {srv} (Capa Servicios)")
            
    return len(fallas) == 0, fallas

def check_nat(config):
    """Verificación 7: Regla de NAT y contadores."""
    fallas = []
    print("[*] Revisando NAT...")
    out, rc = run_docker_cmd("r1", "iptables -t nat -L -v -n")
    if "MASQUERADE" not in out:
        fallas.append("Falta regla MASQUERADE en tabla nat de r1 (Capa NAT)")
    return len(fallas) == 0, fallas

def generar_reporte(resultados):
    """Genera el txt y retorna exit code 1 si hay fallas."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    todo_ok = True
    
    with open("reporte_monitor.txt", "w") as f:
        f.write(f"=== Reporte NetLab Monitor ===\n")
        f.write(f"Fecha: {timestamp}\n\n")
        
        for prueba, (estado, detalles) in resultados.items():
            f.write(f"[{'OK' if estado else 'FAIL'}] {prueba}\n")
            if not estado:
                todo_ok = False
                for d in detalles:
                    f.write(f"  -> {d}\n")
                    
    print(f"\nReporte generado en reporte_monitor.txt")
    if not todo_ok:
        sys.exit(1) # Código distinto de cero si falla algo
    sys.exit(0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NetLab Monitor Script")
    parser.add_argument("-c", "--config", default="monitor.json", help="Ruta al archivo JSON")
    args = parser.parse_args()

    config = cargar_config(args.config)
    resultados = {}
    
    # Ejecución de todas las verificaciones
    resultados["1. Inventario (Capa IP)"] = check_inventario(config)
    resultados["2. VLANs (Capa Enlace)"] = check_vlans(config)
    resultados["3. Rutas (Capa OSPF)"] = check_rutas(config)
    resultados["4. Conectividad (Capa IP/Rutas)"] = check_conectividad(config)
    resultados["5. Servicios (Capa Aplicación)"] = check_servicios(config)
    resultados["6. OSPF (Capa OSPF)"] = check_ospf(config)
    resultados["7. NAT (Capa NAT)"] = check_nat(config)
    
    generar_reporte(resultados)