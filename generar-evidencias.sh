#!/bin/bash

echo "[*] Generando archivos de evidencia reales en la carpeta evidencias/..."
PREFIX="clab-proyecto-grupo1"
mkdir -p evidencias

# 1. Inventario e Interfaces / VLANs (ip -br a e ip -d link)
echo "=== EVIDENCIA 1 y 2: INTERFACES Y VLANS (ip -br a / ip -d link) ===" > evidencias/01_interfaces_vlans.txt
date >> evidencias/01_interfaces_vlans.txt
echo -e "\n--- Bridges en el Host ---" >> evidencias/01_interfaces_vlans.txt
ip -br link show sw-a sw-b >> evidencias/01_interfaces_vlans.txt 2>&1

for nodo in r1 r2 r3 pc-admin pc-ventas srv-web srv-datos externo; do
    echo -e "\n==========================================" >> evidencias/01_interfaces_vlans.txt
    echo "NODO: $nodo (ip -br a)" >> evidencias/01_interfaces_vlans.txt
    echo "==========================================" >> evidencias/01_interfaces_vlans.txt
    docker exec "$PREFIX-$nodo" ip -br a >> evidencias/01_interfaces_vlans.txt 2>&1
    echo -e "\n--- NODO: $nodo (ip -d link) ---" >> evidencias/01_interfaces_vlans.txt
    docker exec "$PREFIX-$nodo" ip -d link >> evidencias/01_interfaces_vlans.txt 2>&1
done

# 2. Tablas de Enrutamiento y OSPF
echo "=== EVIDENCIA 3 y 6: TABLAS DE RUTAS (ip route) Y VECINOS OSPF ===" > evidencias/02_rutas_ospf.txt
date >> evidencias/02_rutas_ospf.txt
for router in r1 r2 r3; do
    echo -e "\n==========================================" >> evidencias/02_rutas_ospf.txt
    echo "ROUTER: $router (ip route)" >> evidencias/02_rutas_ospf.txt
    echo "==========================================" >> evidencias/02_rutas_ospf.txt
    docker exec "$PREFIX-$router" ip route >> evidencias/02_rutas_ospf.txt 2>&1
    echo -e "\n--- ROUTER: $router (show ip ospf neighbor) ---" >> evidencias/02_rutas_ospf.txt
    docker exec "$PREFIX-$router" vtysh -c "show ip ospf neighbor" >> evidencias/02_rutas_ospf.txt 2>&1
    echo -e "\n--- ROUTER: $router (show ip ospf route) ---" >> evidencias/02_rutas_ospf.txt
    docker exec "$PREFIX-$router" vtysh -c "show ip ospf route" >> evidencias/02_rutas_ospf.txt 2>&1
done

# 3. Conectividad (Matriz de Ping y Traceroute)
echo "=== EVIDENCIA 4: MATRIZ DE CONECTIVIDAD (PING Y TRACEROUTE) ===" > evidencias/03_conectividad.txt
date >> evidencias/03_conectividad.txt
for cli in pc-admin pc-ventas; do
    for dest in 172.16.1.50 172.16.1.51 203.0.113.2; do
        echo -e "\n--- Ping desde $cli hacia $dest ---" >> evidencias/03_conectividad.txt
        docker exec "$PREFIX-$cli" ping -c 2 -W 2 "$dest" >> evidencias/03_conectividad.txt 2>&1
        echo -e "\n--- Traceroute desde $cli hacia $dest ---" >> evidencias/03_conectividad.txt
        docker exec "$PREFIX-$cli" traceroute -n -w 1 -m 6 "$dest" >> evidencias/03_conectividad.txt 2>&1
    done
done

# 4. Servicios y NAT
echo "=== EVIDENCIA 5 y 7: SERVICIOS (ss -tulpn) Y NAT (iptables) ===" > evidencias/04_servicios_nat.txt
date >> evidencias/04_servicios_nat.txt
echo -e "\n--- srv-web (ss -tulpn) ---" >> evidencias/04_servicios_nat.txt
docker exec "$PREFIX-srv-web" ss -tulpn >> evidencias/04_servicios_nat.txt 2>&1
echo -e "\n--- srv-datos (ss -tulpn) ---" >> evidencias/04_servicios_nat.txt
docker exec "$PREFIX-srv-datos" ss -tulpn >> evidencias/04_servicios_nat.txt 2>&1
echo -e "\n--- r1 NAT (iptables -t nat -L -v -n) ---" >> evidencias/04_servicios_nat.txt
docker exec "$PREFIX-r1" iptables -t nat -L -v -n >> evidencias/04_servicios_nat.txt 2>&1
echo -e "\n--- r1 FORWARD (iptables -L FORWARD -v -n) ---" >> evidencias/04_servicios_nat.txt
docker exec "$PREFIX-r1" iptables -L FORWARD -v -n >> evidencias/04_servicios_nat.txt 2>&1
echo -e "\n--- Comprobacion en externo (/var/log/nginx/access.log) ---" >> evidencias/04_servicios_nat.txt
docker exec "$PREFIX-externo" tail -n 5 /var/log/nginx/access.log >> evidencias/04_servicios_nat.txt 2>&1

# 5. Salida del Monitor
echo "=== EVIDENCIA 8: EJECUCION DE netlab_monitor.py ===" > evidencias/05_salida_monitor.txt
python3 netlab_monitor.py >> evidencias/05_salida_monitor.txt 2>&1

echo "[+] Evidencias guardadas en evidencias/. Recuerda ejecutar tambien: history > evidencias/historial.txt"
