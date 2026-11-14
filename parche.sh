#!/bin/bash

echo "[*] 1. Cargando módulo de VLANs en el kernel de tu Linux..."
sudo modprobe 8021q

echo "[*] 2. Re-aplicando configuración de IPs y VLANs..."
sudo ./config-ip.sh 2>/dev/null

echo "[*] 3. Instalando iptables en R1 y aplicando NAT..."
docker exec clab-proyecto-grupo1-r1 apk update
docker exec clab-proyecto-grupo1-r1 apk add iptables
sudo ./config-nat.sh

echo "[*] 4. Levantando servicios en los servidores..."
docker exec -d clab-proyecto-grupo1-srv-web nginx
docker exec -d clab-proyecto-grupo1-srv-datos sh -c "while true; do nc -l -p 9000; done"

echo "[*] 5. Reiniciando adyacencias OSPF..."
sudo ./config-ospf.sh
sleep 5

echo "[+] Parche de infraestructura aplicado exitosamente."s