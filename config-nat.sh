#!/bin/bash

echo "Configurando nat"

docker exec clab-proyecto-grupo1-r1 iptables -t nat -A POSTROUTING -o eth4 -j MASQUERADE
docker exec clab-proyecto-grupo1-r1 iptables -A FORWARD -i eth1 -o eth4 -j ACCEPT
docker exec clab-proyecto-grupo1-r1 iptables -A FORWARD -i eth2 -o eth4 -j ACCEPT
docker exec clab-proyecto-grupo1-r1 iptables -A FORWARD -i eth3 -o eth4 -j ACCEPT
docker exec clab-proyecto-grupo1-r1 iptables -A FORWARD -i eth4 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
docker exec clab-proyecto-grupo1-r1 iptables -A FORWARD -i eth4 -o eth2 -m state --state RELATED,ESTABLISHED -j ACCEPT
docker exec clab-proyecto-grupo1-r1 iptables -A FORWARD -i eth4 -o eth3 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "nat configurado exitosamente en r1"