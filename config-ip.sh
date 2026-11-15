#!/bin/bash

echo "[*] Configurando IPs y forwarding con reintentos de seguridad..."
PREFIX="clab-proyecto-grupo1"

# Función para esperar que el contenedor responda antes de configurar
esperar_nodo() {
    local nodo=$1
    for i in {1..10}; do
        if docker exec $PREFIX-$nodo ip link show >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# 1. Habilitar IP Forwarding en los routers
for r in r1 r2 r3; do
    esperar_nodo $r
    docker exec $PREFIX-$r sysctl -w net.ipv4.ip_forward=1
done

# 2. Configurar R1 (Borde)
esperar_nodo r1
docker exec $PREFIX-r1 ip link set up dev eth1
docker exec $PREFIX-r1 ip link set up dev eth2
docker exec $PREFIX-r1 ip link set up dev eth3
docker exec $PREFIX-r1 ip link set up dev eth4
docker exec $PREFIX-r1 ip addr add 172.16.1.57/30 dev eth1 2>/dev/null || true
docker exec $PREFIX-r1 ip addr add 172.16.1.61/30 dev eth2 2>/dev/null || true
docker exec $PREFIX-r1 ip addr add 172.16.1.49/29 dev eth3 2>/dev/null || true
docker exec $PREFIX-r1 ip addr add 203.0.113.1/29 dev eth4 2>/dev/null || true

# 3. Configurar R2 (Gateways directos)
esperar_nodo r2
docker exec $PREFIX-r2 ip link set up dev eth1
docker exec $PREFIX-r2 ip link set up dev eth2
docker exec $PREFIX-r2 ip link set up dev eth3
docker exec $PREFIX-r2 ip link set up dev eth4
docker exec $PREFIX-r2 ip addr add 172.16.1.58/30 dev eth1 2>/dev/null || true
docker exec $PREFIX-r2 ip addr add 172.16.1.65/30 dev eth2 2>/dev/null || true
docker exec $PREFIX-r2 ip addr add 172.16.1.1/27 dev eth3 2>/dev/null || true
docker exec $PREFIX-r2 ip addr add 172.16.1.33/28 dev eth4 2>/dev/null || true

# 4. Configurar R3
esperar_nodo r3
docker exec $PREFIX-r3 ip link set up dev eth1
docker exec $PREFIX-r3 ip link set up dev eth2
docker exec $PREFIX-r3 ip addr add 172.16.1.62/30 dev eth1 2>/dev/null || true
docker exec $PREFIX-r3 ip addr add 172.16.1.66/30 dev eth2 2>/dev/null || true

# 5. Configurar Servidores
esperar_nodo srv-web
docker exec $PREFIX-srv-web ip link set up dev eth1
docker exec $PREFIX-srv-web ip addr add 172.16.1.50/29 dev eth1 2>/dev/null || true

esperar_nodo srv-datos
docker exec $PREFIX-srv-datos ip link set up dev eth1
docker exec $PREFIX-srv-datos ip addr add 172.16.1.51/29 dev eth1 2>/dev/null || true

# 6. Configurar Clientes
esperar_nodo pc-admin
docker exec $PREFIX-pc-admin ip link set up dev eth1
docker exec $PREFIX-pc-admin ip addr add 172.16.1.2/27 dev eth1 2>/dev/null || true

esperar_nodo pc-ventas
docker exec $PREFIX-pc-ventas ip link set up dev eth1
docker exec $PREFIX-pc-ventas ip addr add 172.16.1.34/28 dev eth1 2>/dev/null || true

# 7. Red Externa
esperar_nodo externo
docker exec $PREFIX-externo ip link set up dev eth1
docker exec $PREFIX-externo ip addr add 203.0.113.2/29 dev eth1 2>/dev/null || true

echo "[+] IPs y enlaces aplicados correctamente con reintentos."