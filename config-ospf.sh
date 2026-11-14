#!/bin/bash

echo "Configurando OSPF area 0."

# R2 y R3 anuncian las redes internas normales
for router in r2 r3; do
    docker exec -i clab-proyecto-grupo1-$router vtysh <<EOF
configure terminal
router ospf
    network 172.16.1.0/24 area 0
exit
write
EOF
done

# R1 (Borde) anuncia las internas y además propaga la ruta por defecto hacia afuera
docker exec -i clab-proyecto-grupo1-r1 vtysh <<EOF
configure terminal
router ospf
    network 172.16.1.0/24 area 0
    default-information originate always
exit
write
EOF

echo "OSPF configurado correctamente en r1, r2 y r3."