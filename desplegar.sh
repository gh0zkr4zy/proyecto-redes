#!/bin/bash

echo "[*] Destruyendo restos anteriores por si acaso..."
sudo ip link delete sw-a type bridge 2>/dev/null
sudo ip link delete sw-b type bridge 2>/dev/null

echo "[*] Creando Bridges de Linux (sw-a y sw-b)..."
sudo ip link add name sw-a type bridge
sudo ip link set dev sw-a up
sudo ip link add name sw-b type bridge
sudo ip link set dev sw-b up

echo "[*] Desplegando topología en Containerlab..."
sudo containerlab deploy -t netlab.clab.yml --reconfigure

echo "[*] Esperando 5 segundos para que los contenedores inicien bien..."
sleep 5

echo "[*] Ejecutando scripts de configuración secuencial..."
sudo ./config-ip.sh
sudo ./config-ospf.sh
sudo ./config-nat.sh

echo "[*] Levantando servicios en servidores (Nginx y Netcat)..."
docker exec -d clab-proyecto-grupo1-srv-web nginx
docker exec -d clab-proyecto-grupo1-srv-datos sh -c "while true; do nc -l -p 9000; done"

echo "[*] Aplicando rutas estáticas (Gateways de Hosts)..."
PREFIX="clab-proyecto-grupo1"
docker exec $PREFIX-srv-web ip route replace default via 172.16.1.49
docker exec $PREFIX-srv-datos ip route replace default via 172.16.1.49
docker exec $PREFIX-pc-admin ip route replace default via 172.16.1.1
docker exec $PREFIX-pc-ventas ip route replace default via 172.16.1.33
docker exec $PREFIX-externo ip route replace default via 203.0.113.1

echo "[*] Esperando 8 segundos para convergencia total de OSPF..."
sleep 8

echo "[+] ¡Despliegue atómico completado! La red debería estar operativa."