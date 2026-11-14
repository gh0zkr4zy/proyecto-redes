#!/bin/bash

echo "Configurando ips,enlaces y vlans"

docker exec clab-proyecto-grupo1-r1 sysctl -w net.ipv4.ip_forward=1
docker exec clab-proyecto-grupo1-r2 sysctl -w net.ipv4.ip_forward=1
docker exec clab-proyecto-grupo1-r3 sysctl -w net.ipv4.ip_forward=1

#R1
docker exec clab-proyecto-grupo1-r1 ip addr add 172.16.1.57/30 dev eth1
docker exec clab-proyecto-grupo1-r1 ip addr add 172.16.1.65/30 dev eth2
docker exec clab-proyecto-grupo1-r1 ip addr add 172.16.1.49/29 dev eth3
docker exec clab-proyecto-grupo1-r1 ip addr add 203.0.113.1/29 dev eth4
docker exec clab-proyecto-grupo1-r1 ip link set up dev eth1
docker exec clab-proyecto-grupo1-r1 ip link set up dev eth2
docker exec clab-proyecto-grupo1-r1 ip link set up dev eth3
docker exec clab-proyecto-grupo1-r1 ip link set up dev eth4

#R2
docker exec clab-proyecto-grupo1-r2 ip addr add 172.16.1.58/30 dev eth1
docker exec clab-proyecto-grupo1-r2 ip addr add 172.16.1.61/30 dev eth2
docker exec clab-proyecto-grupo1-r2 ip link set up dev eth1
docker exec clab-proyecto-grupo1-r2 ip link set up dev eth2
docker exec clab-proyecto-grupo1-r2 ip link set up dev eth3

#Subinterfaces r2 para vlan 10 y 20
docker exec clab-proyecto-grupo1-r2 ip link add link eth3 name eth3.10 type vlan id 10
docker exec clab-proyecto-grupo1-r2 ip link add link eth3 name eth3.20 type vlan id 20
docker exec clab-proyecto-grupo1-r2 ip link set up dev eth3.10
docker exec clab-proyecto-grupo1-r2 ip link set up dev eth3.20
docker exec clab-proyecto-grupo1-r2 ip addr add 172.16.1.1/27 dev eth3.10
docker exec clab-proyecto-grupo1-r2 ip addr add 172.16.1.33/28 dev eth3.20

#R3
docker exec clab-proyecto-grupo1-r3 ip addr add 172.16.1.66/30 dev eth1
docker exec clab-proyecto-grupo1-r3 ip addr add 172.16.1.62/30 dev eth2
docker exec clab-proyecto-grupo1-r3 ip link set up dev eth1
docker exec clab-proyecto-grupo1-r3 ip link set up dev eth2

#Servidores
docker exec clab-proyecto-grupo1-srv-web ip addr add 172.16.1.50/29 dev eth1
docker exec clab-proyecto-grupo1-srv-web ip link set up dev eth1
docker exec clab-proyecto-grupo1-srv-web ip route add default via 172.16.1.49

docker exec clab-proyecto-grupo1-srv-datos ip addr add 172.16.1.51/29 dev eth1
docker exec clab-proyecto-grupo1-srv-datos ip link set up dev eth1
docker exec clab-proyecto-grupo1-srv-datos ip route add default via 172.16.1.49

#clientes
docker exec clab-proyecto-grupo1-pc-admin ip link add link eth1 name eth1.10 type vlan id 10
docker exec clab-proyecto-grupo1-pc-admin ip link set up dev eth1
docker exec clab-proyecto-grupo1-pc-admin ip link set up dev eth1.10
docker exec clab-proyecto-grupo1-pc-admin ip addr add 172.16.1.2/27 dev eth1.10
docker exec clab-proyecto-grupo1-pc-admin ip route add default via 172.16.1.1

docker exec clab-proyecto-grupo1-pc-ventas ip link add link eth1 name eth1.20 type vlan id 20
docker exec clab-proyecto-grupo1-pc-ventas ip link set up dev eth1
docker exec clab-proyecto-grupo1-pc-ventas ip link set up dev eth1.20
docker exec clab-proyecto-grupo1-pc-ventas ip addr add 172.16.1.34/28 dev eth1.20
docker exec clab-proyecto-grupo1-pc-ventas ip route add default via 172.16.1.33

#Externo
docker exec clab-proyecto-grupo1-externo ip addr add 203.0.113.2/29 dev eth1
docker exec clab-proyecto-grupo1-externo ip link set up dev eth1
docker exec clab-proyecto-grupo1-externo ip route add default via 203.0.113.1

echo "Configuracion de redes y vlans completada"