#!/bin/bash

echo "[*] Configurando rutas estáticas (Gateways de Hosts)..."
PREFIX="clab-proyecto-grupo1"

# Forzar el reemplazo de la ruta por defecto
docker exec $PREFIX-srv-web ip route replace default via 172.16.1.49
docker exec $PREFIX-srv-datos ip route replace default via 172.16.1.49
docker exec $PREFIX-pc-admin ip route replace default via 172.16.1.1
docker exec $PREFIX-pc-ventas ip route replace default via 172.16.1.33
docker exec $PREFIX-externo ip route replace default via 203.0.113.1 

echo "[+] Rutas estáticas forzadas correctamente."