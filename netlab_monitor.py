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
    
    # Acá iremos agregando el resto de las verificaciones de la pauta
    resultados["1. Inventario (Capa IP)"] = check_inventario(config)
    resultados["6. OSPF (Capa Rutas/OSPF)"] = check_ospf(config)
    
    generar_reporte(resultados)