#!/bin/bash

echo "[*] Configurando IPs, subinterfaces (VLANs) y forwarding..."
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

# --- R2 (VLANs) ---
docker exec $PREFIX-r2 ip addr add 172.16.1.58/30 dev eth1
docker exec $PREFIX-r2 ip addr add 172.16.1.65/30 dev eth2
docker exec $PREFIX-r2 ip link set up dev eth1
docker exec $PREFIX-r2 ip link set up dev eth2

# Levantar la física primero
docker exec $PREFIX-r2 ip link set up dev eth3

# Subinterfaces VLAN 10 y 20 en r2
docker exec $PREFIX-r2 ip link add link eth3 name eth3.10 type vlan id 10
docker exec $PREFIX-r2 ip link add link eth3 name eth3.20 type vlan id 20
docker exec $PREFIX-r2 ip addr add 172.16.1.1/27 dev eth3.10
docker exec $PREFIX-r2 ip addr add 172.16.1.33/28 dev eth3.20
docker exec $PREFIX-r2 ip link set eth3.10 up
docker exec $PREFIX-r2 ip link set eth3.20 up

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

# --- Clientes ---
# pc-admin (VLAN 10)
docker exec $PREFIX-pc-admin ip link set up dev eth1
docker exec $PREFIX-pc-admin ip link add link eth1 name eth1.10 type vlan id 10
docker exec $PREFIX-pc-admin ip addr add 172.16.1.2/27 dev eth1.10
docker exec $PREFIX-pc-admin ip link set eth1.10 up

# pc-ventas (VLAN 20)
docker exec $PREFIX-pc-ventas ip link set up dev eth1
docker exec $PREFIX-pc-ventas ip link add link eth1 name eth1.20 type vlan id 20
docker exec $PREFIX-pc-ventas ip addr add 172.16.1.34/28 dev eth1.20
docker exec $PREFIX-pc-ventas ip link set eth1.20 up

# --- Red Externa ---
docker exec $PREFIX-externo ip addr add 203.0.113.2/29 dev eth1
docker exec $PREFIX-externo ip link set up dev eth1

echo "[+] IPs, VLANs y forwarding aplicados correctamente."