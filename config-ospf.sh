#!/bin/bash

echo "[*] Configurando OSPF Area 0 en r1, r2 y r3..."
PREFIX="clab-proyecto-grupo1"

for router in r1 r2 r3; do
    docker exec "$PREFIX-$router" sed -i 's/ospfd=no/ospfd=yes/g' /etc/frr/daemons
    docker exec "$PREFIX-$router" /etc/init.d/frr restart >/dev/null 2>&1 || true
done

sleep 2

# Asegurar que r2 y r3 no tengan la ruta default de Docker en eth0 para que Zebra instale la de OSPF
docker exec "$PREFIX-r2" ip route del default dev eth0 2>/dev/null || true
docker exec "$PREFIX-r3" ip route del default dev eth0 2>/dev/null || true

# R1: Router de borde (anuncia Servidores y enlaces /30 en area 0, y propaga ruta por defecto)
docker exec -i "$PREFIX-r1" vtysh << 'EOF' >/dev/null
configure terminal
interface eth1
 ip ospf network point-to-point
 ip ospf hello-interval 1
 ip ospf dead-interval 4
exit
interface eth2
 ip ospf network point-to-point
 ip ospf hello-interval 1
 ip ospf dead-interval 4
exit
router ospf
 ospf router-id 1.1.1.1
 passive-interface eth3
 passive-interface eth4
 network 172.16.1.48/29 area 0
 network 172.16.1.56/30 area 0
 network 172.16.1.60/30 area 0
 default-information originate always
exit
do write
EOF

# R2: Router de sede (anuncia VLAN 10, VLAN 20, futuras VLANs del bloque y enlaces /30 en area 0)
docker exec -i "$PREFIX-r2" vtysh << 'EOF' >/dev/null
configure terminal
interface eth1
 ip ospf network point-to-point
 ip ospf hello-interval 1
 ip ospf dead-interval 4
exit
interface eth2
 ip ospf network point-to-point
 ip ospf hello-interval 1
 ip ospf dead-interval 4
exit
router ospf
 ospf router-id 2.2.2.2
 passive-interface eth3
 passive-interface eth3.10
 passive-interface eth3.20
 network 172.16.1.0/24 area 0
exit
do write
EOF

# R3: Router de transito (anuncia enlaces /30 en area 0; ofrece el camino alterno)
docker exec -i "$PREFIX-r3" vtysh << 'EOF' >/dev/null
configure terminal
interface eth1
 ip ospf network point-to-point
 ip ospf hello-interval 1
 ip ospf dead-interval 4
exit
interface eth2
 ip ospf network point-to-point
 ip ospf hello-interval 1
 ip ospf dead-interval 4
exit
router ospf
 ospf router-id 3.3.3.3
 network 172.16.1.60/30 area 0
 network 172.16.1.64/30 area 0
exit
do write
EOF

echo "[+] OSPF Area 0 configurado correctamente en r1, r2 y r3."
