#!/bin/bash
set -e

PREFIX="clab-proyecto-grupo1"

# Normalizar saltos de linea por si se edito en Windows
sed -i 's/\r$//' *.sh *.py *.yml *.json 2>/dev/null || true
chmod +x *.sh 2>/dev/null || true

echo "[*] 1. Limpiando restos anteriores de laboratorio y bridges..."
sudo containerlab destroy -t netlab.clab.yml --cleanup 2>/dev/null || true
sudo ip link set dev sw-a down 2>/dev/null || true
sudo ip link set dev sw-b down 2>/dev/null || true
sudo ip link delete sw-a type bridge 2>/dev/null || true
sudo ip link delete sw-b type bridge 2>/dev/null || true

echo "[*] 2. Cargando modulo 8021q y preparando Bridges de Linux (sw-a y sw-b)..."
sudo modprobe 8021q 2>/dev/null || true
sudo ip link add name sw-a type bridge vlan_filtering 0 2>/dev/null || sudo ip link add name sw-a type bridge
sudo ip link set dev sw-a up
sudo ip link add name sw-b type bridge vlan_filtering 0 2>/dev/null || sudo ip link add name sw-b type bridge
sudo ip link set dev sw-b up

# Evitar que Docker (br_netfilter / iptables FORWARD DROP en el host) bloquee el trafico L2/VLAN en sw-a y sw-b
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0 >/dev/null 2>&1 || true
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=0 >/dev/null 2>&1 || true
sudo sysctl -w net.bridge.bridge-nf-call-arptables=0 >/dev/null 2>&1 || true
sudo sysctl -w net.bridge.bridge-nf-filter-vlan-tagged=0 >/dev/null 2>&1 || true
sudo iptables -I FORWARD -i sw-a -j ACCEPT 2>/dev/null || true
sudo iptables -I FORWARD -o sw-a -j ACCEPT 2>/dev/null || true
sudo iptables -I FORWARD -i sw-b -j ACCEPT 2>/dev/null || true
sudo iptables -I FORWARD -o sw-b -j ACCEPT 2>/dev/null || true

echo "[*] 3. Desplegando topologia en Containerlab..."
sudo containerlab deploy -t netlab.clab.yml --reconfigure

# Asegurar que todos los puertos de sw-a y sw-b en el host esten UP
for port in r2-cli adm-cli ven-cli r1-srv web-srv dat-srv; do
    sudo ip link set dev "$port" up 2>/dev/null || true
done

echo "[*] 4. Ejecutando configuracion de IPs (Capa 3)..."
sudo ./config-ip.sh

echo "[*] 5. Ejecutando configuracion de VLANs 802.1Q (Capa 2 / Router-on-a-Stick)..."
sudo ./config-vlans.sh

echo "[*] 6. Aplicando rutas estaticas en hosts y preparando tablas de routers..."
sudo ./rutas-estaticas.sh

echo "[*] 7. Configurando enrutamiento dinamico OSPF Area 0..."
sudo ./config-ospf.sh

echo "[*] 8. Aplicando NAT (MASQUERADE) en r1..."
sudo ./config-nat.sh

echo "[*] 9. Levantando servicios en servidores (HTTP en srv-web y TCP/9000 en srv-datos)..."
docker exec "$PREFIX-srv-web" sh -c "pgrep nginx >/dev/null || nginx"
docker exec "$PREFIX-externo" sh -c "pgrep nginx >/dev/null || nginx" 2>/dev/null || true
docker exec -d "$PREFIX-srv-datos" sh -c "pkill -f 'nc.*9000' 2>/dev/null; while true; do nc -lk -p 9000 -e /bin/cat 2>/dev/null || nc -l -p 9000 -e /bin/cat 2>/dev/null || nc -lk 9000 2>/dev/null || nc -l -p 9000 </dev/null; done"

echo "[*] 10. Esperando convergencia de OSPF y validando trafico inicial..."
sleep 6

# Generar trafico inicial para poblar ARP y contadores NAT
docker exec "$PREFIX-pc-admin" ping -c 1 -W 2 172.16.1.50 >/dev/null 2>&1 || true
docker exec "$PREFIX-pc-admin" ping -c 1 -W 2 203.0.113.2 >/dev/null 2>&1 || true
docker exec "$PREFIX-pc-ventas" ping -c 1 -W 2 203.0.113.2 >/dev/null 2>&1 || true

echo "[+] Despliegue completado con exito. Ejecuta: python3 netlab_monitor.py"
