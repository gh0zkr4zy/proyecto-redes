#!/bin/bash

echo "[*] Destruyendo topología de Containerlab..."
sudo containerlab destroy -t netlab.clab.yml --cleanup

echo "[*] Eliminando bridges de Linux residuales (sw-a y sw-b)..."
sudo ip link delete sw-a type bridge 2>/dev/null
sudo ip link delete sw-b type bridge 2>/dev/null

echo "[+] ¡Laboratorio destruido y limpio!"