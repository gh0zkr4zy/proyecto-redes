#!/bin/bash

echo "[*] Desplegando topología en Containerlab..."
sudo containerlab deploy -t netlab.clab.yml --reconfigure

echo "[*] Esperando 5 segundos para que los contenedores inicien bien..."
sleep 5

echo "[*] Ejecutando scripts de configuración..."
# Se ejecutan con sudo por si acaso, aunque los comandos internos ya usan docker exec
sudo ./config-ip.sh
sudo ./config-vlans.sh 2>/dev/null # Por si el Pablito metió todo en el config-ip.sh
sudo ./config-ospf.sh
sudo ./config-nat.sh

echo "[+] ¡Despliegue completado! La red debería estar operativa."