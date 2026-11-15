#!/bin/bash

echo "[*] Configurando NAT (MASQUERADE) en r1 hacia la red externa (eth4)..."
PREFIX="clab-proyecto-grupo1"

# Verificar que iptables este instalado en r1
docker exec "$PREFIX-r1" sh -c "which iptables >/dev/null 2>&1 || apk add --no-cache iptables >/dev/null 2>&1" || true

# Limpiar reglas previas para evitar duplicados al re-ejecutar
docker exec "$PREFIX-r1" iptables -t nat -F
docker exec "$PREFIX-r1" iptables -F FORWARD
docker exec "$PREFIX-r1" iptables -P FORWARD ACCEPT

# Regla NAT (MASQUERADE) solo hacia la interfaz externa eth4 (203.0.113.0/29)
docker exec "$PREFIX-r1" iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -o eth4 -j MASQUERADE

# Reglas de filtrado FORWARD hacia y desde la red externa
docker exec "$PREFIX-r1" iptables -A FORWARD -i eth1 -o eth4 -j ACCEPT
docker exec "$PREFIX-r1" iptables -A FORWARD -i eth2 -o eth4 -j ACCEPT
docker exec "$PREFIX-r1" iptables -A FORWARD -i eth3 -o eth4 -j ACCEPT
docker exec "$PREFIX-r1" iptables -A FORWARD -i eth4 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
docker exec "$PREFIX-r1" iptables -A FORWARD -i eth4 -o eth2 -m state --state RELATED,ESTABLISHED -j ACCEPT
docker exec "$PREFIX-r1" iptables -A FORWARD -i eth4 -o eth3 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "[+] NAT (MASQUERADE) configurado exitosamente en r1."
