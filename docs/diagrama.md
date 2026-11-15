# Diagrama de Topología L2/L3 — NetLab Monitor (Grupo 1)

## 1. Diagrama de Arquitectura (Mermaid)

```mermaid
flowchart LR
    subgraph CLIENTES["Segmento Clientes (Sede)"]
        PCA["pc-admin\neth1.10: 172.16.1.2/27\nGW: 172.16.1.1 (VLAN 10)"]
        PCV["pc-ventas\neth1.20: 172.16.1.34/28\nGW: 172.16.1.33 (VLAN 20)"]
        SWA["sw-a\n(Linux Bridge)"]
        PCA ---|"802.1Q VLAN 10"| SWA
        PCV ---|"802.1Q VLAN 20"| SWA
    end

    subgraph CORE["Núcleo OSPF Área 0 (FRRouting)"]
        R2["r2 (Router de Sede)\neth3.10: 172.16.1.1/27\neth3.20: 172.16.1.33/28\neth1: 172.16.1.58/30\neth2: 172.16.1.65/30"]
        R3["r3 (Router de Tránsito)\neth1: 172.16.1.62/30\neth2: 172.16.1.66/30"]
        R1["r1 (Router de Borde + NAT)\neth1: 172.16.1.57/30\neth2: 172.16.1.61/30\neth3: 172.16.1.49/29\neth4: 203.0.113.1/29"]

        R2 ---|"172.16.1.56/30\n(eth1 - eth1)"| R1
        R2 ---|"172.16.1.64/30\n(eth2 - eth2)"| R3
        R3 ---|"172.16.1.60/30\n(eth1 - eth2)"| R1
    end

    subgraph SERVIDORES["Segmento Servidores (172.16.1.48/29)"]
        SWB["sw-b\n(Linux Bridge)"]
        WEB["srv-web (HTTP :80)\neth1: 172.16.1.50/29\nGW: 172.16.1.49"]
        DAT["srv-datos (TCP :9000)\neth1: 172.16.1.51/29\nGW: 172.16.1.49"]
        SWB --- WEB
        SWB --- DAT
    end

    subgraph INTERNET["Red Externa (203.0.113.0/29)"]
        EXT["externo\neth1: 203.0.113.2/29"]
    end

    SWA ===|"Trunk 802.1Q\nVLAN 10 y 20"| R2
    R1 ---|"172.16.1.48/29"| SWB
    R1 ===|"NAT MASQUERADE (eth4)\n203.0.113.0/29"| EXT
```

---

## 2. Diagrama ASCII Detallado de Interfaces

```text
                                     +-----------------------------------+
                                     |              externo              |
                                     |       eth1: 203.0.113.2/29        |
                                     +-----------------+-----------------+
                                                       |
                                                       | Red Externa: 203.0.113.0/29
                                                       | (NAT MASQUERADE en r1:eth4)
                                                       |
                                     +-----------------+-----------------+
                      +------------- |             r3 (FRR)              | -------------+
                      |              |  eth2: 172.16.1.66/30 (a r2:eth2) |              |
                      |              |  eth1: 172.16.1.62/30 (a r1:eth2) |              |
                      |              +-----------------------------------+              |
    Enlace /30        |                                                                 | Enlace /30
  172.16.1.64/30      |                         OSPF AREA 0                             | 172.16.1.60/30
                      |                                                                 |
+---------------------+-------------+                                     +-------------+---------------------+
|             r2 (FRR)              |      Enlace /30: 172.16.1.56/30     |          r1 (FRR + NAT)           |
|      eth2: 172.16.1.65/30         |-------------------------------------|      eth1: 172.16.1.57/30         |
|      eth1: 172.16.1.58/30         |           (eth1 <---> eth1)         |      eth2: 172.16.1.61/30         |
|   eth3.10: 172.16.1.1/27 (VLAN10) |                                     |      eth3: 172.16.1.49/29 (Srv)   |
|   eth3.20: 172.16.1.33/28(VLAN20) |                                     |      eth4: 203.0.113.1/29 (Ext)   |
+-----------------+-----------------+                                     +-----------------+-----------------+
                  |                                                                         |
                  | Trunk 802.1Q (eth3)                                                     | LAN Servidores (eth3)
                  |                                                                         | 172.16.1.48/29
        +---------+---------+                                                     +---------+---------+
        |   sw-a (Bridge)   |                                                     |   sw-b (Bridge)   |
        +---+-----------+---+                                                     +---+-----------+---+
            |           |                                                             |           |
   VLAN 10  |           | VLAN 20                                                     |           |
+-----------+---+   +---+-----------+                                     +-----------+---+   +---+-----------+
|   pc-admin    |   |   pc-ventas   |                                     |    srv-web    |   |   srv-datos   |
|   eth1.10:    |   |   eth1.20:    |                                     |     eth1:     |   |     eth1:     |
| 172.16.1.2/27 |   |172.16.1.34/28 |                                     |172.16.1.50/29 |   |172.16.1.51/29 |
| GW:172.16.1.1 |   |GW:172.16.1.33 |                                     |  HTTP (:80)   |   |  TCP (:9000)  |
+---------------+   +---------------+                                     +---------------+   +---------------+
```
