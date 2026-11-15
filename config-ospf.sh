#!/bin/bash

echo "[*] Configurando OSPF Area 0 en r1, r2 y r3..."
PREFIX="clab-proyecto-grupo1"

aplicar_ospf() {
    for router in r1 r2 r3; do
        docker exec "$PREFIX-$router" sed -i 's/ospfd=no/ospfd=yes/g' /etc/frr/daemons
        docker exec "$PREFIX-$router" touch /etc/frr/vtysh.conf
        docker exec "$PREFIX-$router" sh -c "pgrep ospfd >/dev/null || /usr/lib/frr/ospfd -d"
    done

    # Asegurar que r2 y r3 no tengan la ruta default de Docker en eth0 para que Zebra instale la de OSPF
    docker exec "$PREFIX-r2" ip route del default dev eth0 2>/dev/null || true
    docker exec "$PREFIX-r3" ip route del default dev eth0 2>/dev/null || true

    # R1: Router de borde
    docker exec "$PREFIX-r1" vtysh \
        -c "configure terminal" \
        -c "interface eth1" -c "ip ospf network point-to-point" -c "ip ospf hello-interval 1" -c "ip ospf dead-interval 4" -c "exit" \
        -c "interface eth2" -c "ip ospf network point-to-point" -c "ip ospf hello-interval 1" -c "ip ospf dead-interval 4" -c "exit" \
        -c "router ospf" \
        -c "ospf router-id 1.1.1.1" \
        -c "network 172.16.1.48/29 area 0" \
        -c "network 172.16.1.56/30 area 0" \
        -c "network 172.16.1.60/30 area 0" \
        -c "default-information originate always" \
        -c "end" -c "write memory" >/dev/null 2>&1 || true

    # R2: Router de sede
    docker exec "$PREFIX-r2" vtysh \
        -c "configure terminal" \
        -c "interface eth1" -c "ip ospf network point-to-point" -c "ip ospf hello-interval 1" -c "ip ospf dead-interval 4" -c "exit" \
        -c "interface eth2" -c "ip ospf network point-to-point" -c "ip ospf hello-interval 1" -c "ip ospf dead-interval 4" -c "exit" \
        -c "router ospf" \
        -c "ospf router-id 2.2.2.2" \
        -c "network 172.16.1.0/27 area 0" \
        -c "network 172.16.1.32/28 area 0" \
        -c "network 172.16.1.56/30 area 0" \
        -c "network 172.16.1.64/30 area 0" \
        -c "network 172.16.1.0/24 area 0" \
        -c "redistribute connected" \
        -c "end" -c "write memory" >/dev/null 2>&1 || true

    # R3: Router de transito
    docker exec "$PREFIX-r3" vtysh \
        -c "configure terminal" \
        -c "interface eth1" -c "ip ospf network point-to-point" -c "ip ospf hello-interval 1" -c "ip ospf dead-interval 4" -c "exit" \
        -c "interface eth2" -c "ip ospf network point-to-point" -c "ip ospf hello-interval 1" -c "ip ospf dead-interval 4" -c "exit" \
        -c "router ospf" \
        -c "ospf router-id 3.3.3.3" \
        -c "network 172.16.1.60/30 area 0" \
        -c "network 172.16.1.64/30 area 0" \
        -c "end" -c "write memory" >/dev/null 2>&1 || true
}

aplicar_ospf

echo "[*] Esperando adyacencia Full en r1, r2 y r3..."
for i in {1..15}; do
    f1=$(docker exec "$PREFIX-r1" vtysh -c "show ip ospf neighbor" 2>/dev/null | grep -c "Full" || true)
    f2=$(docker exec "$PREFIX-r2" vtysh -c "show ip ospf neighbor" 2>/dev/null | grep -c "Full" || true)
    f3=$(docker exec "$PREFIX-r3" vtysh -c "show ip ospf neighbor" 2>/dev/null | grep -c "Full" || true)
    if [ "${f1:-0}" -ge 2 ] && [ "${f2:-0}" -ge 2 ] && [ "${f3:-0}" -ge 2 ]; then
        break
    fi
    if [ "$i" -eq 4 ] || [ "$i" -eq 8 ]; then
        aplicar_ospf
    fi
    sleep 1
done

echo "[+] OSPF Area 0 configurado correctamente en r1, r2 y r3."
