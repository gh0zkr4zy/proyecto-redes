#!/bin/bash

echo "[*] Creando Bridges de Linux (sw-a y sw-b)..."
sudo ip link add name sw-a type bridge
sudo ip link set dev sw-a up
sudo ip link add name sw-b type bridge
sudo ip link set dev sw-b up

echo "[*] Desplegando topología en Containerlab..."
sudo containerlab deploy -t netlab.clab.yml --reconfigure

echo "[*] Esperando 5 segundos para que los contenedores inicien bien..."
sleep 5

echo "[*] Ejecutando scripts de configuración..."
sudo ./config-ip.sh
sudo ./config-vlans.sh 2>/dev/null
sudo ./config-ospf.sh
sudo ./config-nat.sh

echo "[+] ¡Despliegue completado! La red debería estar operativa."