#!/bin/bash

echo "[*] Destruyendo topologia de Containerlab..."
sudo containerlab destroy -t netlab.clab.yml --cleanup 2>/dev/null || true

echo "[*] Limpiando rutas de monitoreo en el host..."
sudo ip route del 172.16.1.50/32 2>/dev/null || true
sudo ip route del 172.16.1.51/32 2>/dev/null || true
sudo ip route del 172.16.1.0/24 2>/dev/null || true

echo "[*] Eliminando bridges de Linux (sw-a y sw-b)..."
sudo ip link set dev sw-a down 2>/dev/null || true
sudo ip link set dev sw-b down 2>/dev/null || true
sudo ip link delete sw-a type bridge 2>/dev/null || true
sudo ip link delete sw-b type bridge 2>/dev/null || true

echo "[+] Laboratorio destruido y limpio."
