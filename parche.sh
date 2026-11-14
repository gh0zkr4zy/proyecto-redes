#!/bin/bash

echo "[*] 1. Cargando módulo de VLANs en el host..."
sudo modprobe 8021q
sleep 1

echo "[*] 2. Re-aplicando configuración de IPs y VLANs..."
sudo ./config-ip.sh 2>/dev/null
sudo ./rutas_estaticas.sh

echo "[*] 3. Instalando iptables en R1 y aplicando NAT..."
docker exec clab-proyecto-grupo1-r1 apk update
docker exec clab-proyecto-grupo1-r1 apk add iptables
sudo ./config-nat.sh

echo "[*] 4. Levantando servicios..."
docker exec -d clab-proyecto-grupo1-srv-web nginx
docker exec -d clab-proyecto-grupo1-srv-datos sh -c "while true; do nc -l -p 9000; done"

echo "[*] 5. Configurando OSPF..."
sudo ./config-ospf.sh
sleep 5

echo "[+] Parche de infraestructura aplicado exitosamente."