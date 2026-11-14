#!/bin/bash

echo "[*] Configurando IPs y forwarding (Modo Conexión Directa sin VLANs)..."
PREFIX="clab-proyecto-grupo1"

# Habilitar forwarding en los routers
docker exec $PREFIX-r1 sysctl -w net.ipv4.ip_forward=1
docker exec $PREFIX-r2 sysctl -w net.ipv4.ip_forward=1
docker exec $PREFIX-r3 sysctl -w net.ipv4.ip_forward=1

# --- R1 (Borde) ---
docker exec $PREFIX-r1 ip addr add 172.16.1.57/30 dev eth1
docker exec $PREFIX-r1 ip addr add 172.16.1.61/30 dev eth2
docker exec $PREFIX-r1 ip addr add 172.16.1.49/29 dev eth3
docker exec $PREFIX-r1 ip addr add 203.0.113.1/29 dev eth4
docker exec $PREFIX-r1 ip link set up dev eth1
docker exec $PREFIX-r1 ip link set up dev eth2
docker exec $PREFIX-r1 ip link set up dev eth3
docker exec $PREFIX-r1 ip link set up dev eth4

# --- R2 (Gateways directos en eth3 y eth4) ---
docker exec $PREFIX-r2 ip addr add 172.16.1.58/30 dev eth1
docker exec $PREFIX-r2 ip addr add 172.16.1.65/30 dev eth2
docker exec $PREFIX-r2 ip addr add 172.16.1.1/27 dev eth3  # Gateway pc-admin
docker exec $PREFIX-r2 ip addr add 172.16.1.33/28 dev eth4 # Gateway pc-ventas
docker exec $PREFIX-r2 ip link set up dev eth1
docker exec $PREFIX-r2 ip link set up dev eth2
docker exec $PREFIX-r2 ip link set up dev eth3
docker exec $PREFIX-r2 ip link set up dev eth4

# --- R3 ---
docker exec $PREFIX-r3 ip addr add 172.16.1.62/30 dev eth1
docker exec $PREFIX-r3 ip addr add 172.16.1.66/30 dev eth2
docker exec $PREFIX-r3 ip link set up dev eth1
docker exec $PREFIX-r3 ip link set up dev eth2

# --- Servidores ---
docker exec $PREFIX-srv-web ip addr add 172.16.1.50/29 dev eth1
docker exec $PREFIX-srv-web ip link set up dev eth1
docker exec $PREFIX-srv-datos ip addr add 172.16.1.51/29 dev eth1
docker exec $PREFIX-srv-datos ip link set up dev eth1

# --- Clientes (Conexión directa) ---
# pc-admin (Conectado a eth3 de r2)
docker exec $PREFIX-pc-admin ip link set up dev eth1
docker exec $PREFIX-pc-admin ip addr add 172.16.1.2/27 dev eth1

# pc-ventas (Conectado a eth4 de r2)
docker exec $PREFIX-pc-ventas ip link set up dev eth1
docker exec $PREFIX-pc-ventas ip addr add 172.16.1.34/28 dev eth1

# --- Red Externa ---
docker exec $PREFIX-externo ip addr add 203.0.113.2/29 dev eth1
docker exec $PREFIX-externo ip link set up dev eth1

echo "[+] IPs aplicadas correctamente."