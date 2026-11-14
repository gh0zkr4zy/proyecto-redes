#!/bin/bash

echo "Configurando OSPF area 0..."

for router in r1 r2 r3; do
    docker exec clab-proyecto-grupo1-$router sed -i 's/ospfd=no/ospfd=yes/g' /etc/frr/daemons
    docker exec clab-proyecto-grupo1-$router /etc/init.d/frr reload || docker exec -d clab-proyecto-grupo1-$router /usr/lib/frr/ospfd -d
    sleep 2
done

# R2 y R3 anuncian todo
for router in r2 r3; do
    docker exec -i clab-proyecto-grupo1-$router vtysh <<EOF
configure terminal
router ospf
    network 172.16.1.0/24 area 0
    redistribute connected
exit
do write
EOF
done

# R1 anuncia todo + salida a internet
docker exec -i clab-proyecto-grupo1-r1 vtysh <<EOF
configure terminal
router ospf
    network 172.16.1.0/24 area 0
    redistribute connected
    default-information originate always
exit
do write
EOF
echo "OSPF configurado correctamente."