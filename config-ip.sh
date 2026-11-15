#!/bin/bash

echo "[*] Configurando IPs y IP Forwarding..."
PREFIX="clab-proyecto-grupo1"

esperar_nodo() {
    local nodo=$1
    for i in {1..15}; do
        if docker exec "$PREFIX-$nodo" ip link show >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# 1. Habilitar IP Forwarding y desactivar rp_filter en los routers
for r in r1 r2 r3; do
    esperar_nodo "$r"
    docker exec "$PREFIX-$r" sysctl -w net.ipv4.ip_forward=1 >/dev/null
    docker exec "$PREFIX-$r" sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
    docker exec "$PREFIX-$r" sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1 || true
done

# 2. Configurar R1 (Router de Borde)
esperar_nodo r1
for iface in eth1 eth2 eth3 eth4; do
    docker exec "$PREFIX-r1" ip link set up dev "$iface"
done
docker exec "$PREFIX-r1" ip addr replace 172.16.1.57/30 dev eth1
docker exec "$PREFIX-r1" ip addr replace 172.16.1.61/30 dev eth2
docker exec "$PREFIX-r1" ip addr replace 172.16.1.49/29 dev eth3
docker exec "$PREFIX-r1" ip addr replace 203.0.113.1/29 dev eth4

# 3. Configurar R2 (Router de Sede - enlaces entre routers)
esperar_nodo r2
for iface in eth1 eth2 eth3; do
    docker exec "$PREFIX-r2" ip link set up dev "$iface"
done
docker exec "$PREFIX-r2" ip addr replace 172.16.1.58/30 dev eth1
docker exec "$PREFIX-r2" ip addr replace 172.16.1.65/30 dev eth2

# 4. Configurar R3 (Router de Transito)
esperar_nodo r3
for iface in eth1 eth2; do
    docker exec "$PREFIX-r3" ip link set up dev "$iface"
done
docker exec "$PREFIX-r3" ip addr replace 172.16.1.62/30 dev eth1
docker exec "$PREFIX-r3" ip addr replace 172.16.1.66/30 dev eth2

# 5. Configurar Segmento Servidores (172.16.1.48/29 detras de sw-b)
esperar_nodo srv-web
docker exec "$PREFIX-srv-web" ip link set up dev eth1
docker exec "$PREFIX-srv-web" ip addr replace 172.16.1.50/29 dev eth1

esperar_nodo srv-datos
docker exec "$PREFIX-srv-datos" ip link set up dev eth1
docker exec "$PREFIX-srv-datos" ip addr replace 172.16.1.51/29 dev eth1

# 6. Levantar interfaces base de Clientes (VLANs se asignan en config-vlans.sh)
esperar_nodo pc-admin
docker exec "$PREFIX-pc-admin" ip link set up dev eth1

esperar_nodo pc-ventas
docker exec "$PREFIX-pc-ventas" ip link set up dev eth1

# 7. Configurar Red Externa (203.0.113.0/29)
esperar_nodo externo
docker exec "$PREFIX-externo" ip link set up dev eth1
docker exec "$PREFIX-externo" ip addr replace 203.0.113.2/29 dev eth1

echo "[+] Direccionamiento IP base aplicado correctamente."
