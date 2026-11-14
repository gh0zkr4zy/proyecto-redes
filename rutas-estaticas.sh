#!/bin/bash

echo "[*] Configurando rutas estáticas (Gateways de Hosts)..."
PREFIX="clab-proyecto-grupo1"

# Servidores hacia R1
docker exec $PREFIX-srv-web ip route add default via 172.16.1.49
docker exec $PREFIX-srv-datos ip route add default via 172.16.1.49

# Clientes hacia las subinterfaces de R2
docker exec $PREFIX-pc-admin ip route add default via 172.16.1.1
docker exec $PREFIX-pc-ventas ip route add default via 172.16.1.33

# Externo hacia R1
docker exec $PREFIX-externo ip route add default via 203.0.113.1

echo "[+] Rutas estáticas configuradas."