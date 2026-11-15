#!/bin/bash

echo "[*] Configurando VLANs 10 y 20 (802.1Q Router-on-a-Stick en r2 y clientes)..."
PREFIX="clab-proyecto-grupo1"

# Asegurar que el modulo 8021q este cargado y el bridge sw-a permita tramas 802.1Q
sudo modprobe 8021q 2>/dev/null || true
sudo ip link set dev sw-a up 2>/dev/null || true
sudo ip link set dev sw-b up 2>/dev/null || true
for port in r2-cli adm-cli ven-cli r1-srv web-srv dat-srv; do
    sudo ip link set dev "$port" up 2>/dev/null || true
done

# 1. Subinterfaces 802.1Q en R2 (Router-on-a-Stick)
docker exec "$PREFIX-r2" ip addr flush dev eth3 2>/dev/null || true
docker exec "$PREFIX-r2" ip link set dev eth3 up

# VLAN 10 Administracion (25 hosts -> /27: 172.16.1.0/27, Gateway: 172.16.1.1)
docker exec "$PREFIX-r2" ip link del eth3.10 2>/dev/null || true
docker exec "$PREFIX-r2" ip link add link eth3 name eth3.10 type vlan id 10
docker exec "$PREFIX-r2" ip link set dev eth3.10 up
docker exec "$PREFIX-r2" ip addr replace 172.16.1.1/27 dev eth3.10 2>/dev/null || docker exec "$PREFIX-r2" ip addr add 172.16.1.1/27 dev eth3.10 2>/dev/null || true

# VLAN 20 Ventas (12 hosts -> /28: 172.16.1.32/28, Gateway: 172.16.1.33)
docker exec "$PREFIX-r2" ip link del eth3.20 2>/dev/null || true
docker exec "$PREFIX-r2" ip link add link eth3 name eth3.20 type vlan id 20
docker exec "$PREFIX-r2" ip link set dev eth3.20 up
docker exec "$PREFIX-r2" ip addr replace 172.16.1.33/28 dev eth3.20 2>/dev/null || docker exec "$PREFIX-r2" ip addr add 172.16.1.33/28 dev eth3.20 2>/dev/null || true

# 2. Cliente pc-admin en VLAN 10 (172.16.1.2/27)
docker exec "$PREFIX-pc-admin" ip addr flush dev eth1 2>/dev/null || true
docker exec "$PREFIX-pc-admin" ip link set dev eth1 up
docker exec "$PREFIX-pc-admin" ip link del eth1.10 2>/dev/null || true
docker exec "$PREFIX-pc-admin" ip link add link eth1 name eth1.10 type vlan id 10
docker exec "$PREFIX-pc-admin" ip link set dev eth1.10 up
docker exec "$PREFIX-pc-admin" ip addr replace 172.16.1.2/27 dev eth1.10 2>/dev/null || docker exec "$PREFIX-pc-admin" ip addr add 172.16.1.2/27 dev eth1.10 2>/dev/null || true

# 3. Cliente pc-ventas en VLAN 20 (172.16.1.34/28)
docker exec "$PREFIX-pc-ventas" ip addr flush dev eth1 2>/dev/null || true
docker exec "$PREFIX-pc-ventas" ip link set dev eth1 up
docker exec "$PREFIX-pc-ventas" ip link del eth1.20 2>/dev/null || true
docker exec "$PREFIX-pc-ventas" ip link add link eth1 name eth1.20 type vlan id 20
docker exec "$PREFIX-pc-ventas" ip link set dev eth1.20 up
docker exec "$PREFIX-pc-ventas" ip addr replace 172.16.1.34/28 dev eth1.20 2>/dev/null || docker exec "$PREFIX-pc-ventas" ip addr add 172.16.1.34/28 dev eth1.20 2>/dev/null || true

echo "[+] Subinterfaces 802.1Q (VLAN 10 y VLAN 20) configuradas en r2 y clientes."
