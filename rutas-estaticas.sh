#!/bin/bash

echo "[*] Configurando rutas por defecto en hosts y preparando tablas de enrutamiento..."
PREFIX="clab-proyecto-grupo1"

# 1. Gateways por defecto en Clientes (apuntando a las subinterfaces de R2)
docker exec "$PREFIX-pc-admin" ip route replace default via 172.16.1.1 dev eth1.10
docker exec "$PREFIX-pc-ventas" ip route replace default via 172.16.1.33 dev eth1.20

# 2. Gateways por defecto en Servidores (apuntando a R1 eth3)
docker exec "$PREFIX-srv-web" ip route replace default via 172.16.1.49 dev eth1
docker exec "$PREFIX-srv-datos" ip route replace default via 172.16.1.49 dev eth1

# 3. Eliminar la ruta por defecto de gestion de Docker (eth0) en r2, r3 y externo
# Esto permite que r2 y r3 instalen la ruta default aprendida por OSPF desde r1,
# y que externo solo responda a la IP publica 203.0.113.1 traducida por NAT en r1.
docker exec "$PREFIX-r2" ip route del default dev eth0 2>/dev/null || true
docker exec "$PREFIX-r3" ip route del default dev eth0 2>/dev/null || true
docker exec "$PREFIX-externo" ip route del default dev eth0 2>/dev/null || true

# 4. Rutas en el host hacia los servidores para que socket.connect() de netlab_monitor.py
# alcance directamente las IPs del plan VLSM (172.16.1.50 y 172.16.1.51)
WEB_MGMT=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$PREFIX-srv-web" 2>/dev/null)
DAT_MGMT=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$PREFIX-srv-datos" 2>/dev/null)
R1_MGMT=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$PREFIX-r1" 2>/dev/null)

if [ -n "$R1_MGMT" ]; then
    sudo ip route replace 172.16.1.0/24 via "$R1_MGMT" 2>/dev/null || true
fi
if [ -n "$WEB_MGMT" ]; then
    sudo ip route replace 172.16.1.50/32 via "$WEB_MGMT" 2>/dev/null || true
fi
if [ -n "$DAT_MGMT" ]; then
    sudo ip route replace 172.16.1.51/32 via "$DAT_MGMT" 2>/dev/null || true
fi

echo "[+] Rutas estaticas de gateways configuradas correctamente."
