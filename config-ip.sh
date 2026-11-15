#!/bin/bash
set -e # Detiene el script inmediatamente si un comando falla

echo "[*] Configurando IPs y forwarding..."
PREFIX="clab-proyecto-grupo1"

# 1. Habilitar IP Forwarding en los routers
for r in r1 r2 r3; do
    docker exec $PREFIX-$r sysctl -w net.ipv4.ip_forward=1
done

# 2. Configurar R1 (Borde)
echo "[*] Configurando R1..."
docker exec $PREFIX-r1 ip link set up dev eth1
docker exec $PREFIX-r1 ip link set up dev eth2
docker exec $PREFIX-r1 ip link set up dev eth3
docker exec $PREFIX-r1 ip link set up dev eth4
docker exec $PREFIX-r1 ip addr add 172.16.1.57/30 dev eth1
docker exec $PREFIX-r1 ip addr add 172.16.1.61/30 dev eth2
docker exec $PREFIX-r1 ip addr add 172.16.1.49/29 dev eth3
docker exec $PREFIX-r1 ip addr add 203.0.113.1/29 dev eth4

# 3. Configurar R2 (Gateways directos)
echo "[*] Configurando R2..."
docker exec $PREFIX-r2 ip link set up dev eth1
docker exec $PREFIX-r2 ip link set up dev eth2
docker exec $PREFIX-r2 ip link set up dev eth3
docker exec $PREFIX-r2 ip link set up dev eth4
docker exec $PREFIX-r2 ip addr add 172.16.1.58/30 dev eth1
docker exec $PREFIX-r2 ip addr add 172.16.1.65/30 dev eth2
docker exec $PREFIX-r2 ip addr add 172.16.1.1/27 dev eth3  # Gateway pc-admin
docker exec $PREFIX-r2 ip addr add 172.16.1.33/28 dev eth4 # Gateway pc-ventas

# 4. Configurar R3
echo "[*] Configurando R3..."
docker exec $PREFIX-r3 ip link set up dev eth1
docker exec $PREFIX-r3 ip link set up dev eth2
docker exec $PREFIX-r3 ip addr add 172.16.1.62/30 dev eth1
docker exec $PREFIX-r3 ip addr add 172.16.1.66/30 dev eth2

# 5. Configurar Servidores
echo "[*] Configurando Servidores..."
docker exec $PREFIX-srv-web ip link set up dev eth1
docker exec $PREFIX-srv-web ip addr add 172.16.1.50/29 dev eth1

docker exec $PREFIX-srv-datos ip link set up dev eth1
docker exec $PREFIX-srv-datos ip addr add 172.16.1.51/29 dev eth1

# 6. Configurar Clientes
echo "[*] Configurando Clientes..."
docker exec $PREFIX-pc-admin ip link set up dev eth1
docker exec $PREFIX-pc-admin ip addr add 172.16.1.2/27 dev eth1

docker exec $PREFIX-pc-ventas ip link set up dev eth1
docker exec $PREFIX-pc-ventas ip addr add 172.16.1.34/28 dev eth1

# 7. Red Externa
echo "[*] Configurando Nodo Externo..."
docker exec $PREFIX-externo ip link set up dev eth1
docker exec $PREFIX-externo ip addr add 203.0.113.2/29 dev eth1

echo "[+] IPs y enlaces aplicados correctamente sin errores."