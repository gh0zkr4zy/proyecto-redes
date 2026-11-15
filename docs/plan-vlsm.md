# Plan de Direccionamiento VLSM — Grupo 1 (`172.16.1.0/24`)

## 1. Reglas de Diseño (Sección 2 de la Pauta)
- **Bloque base asignado al Grupo 1:** `172.16.1.0/24` (256 direcciones: `172.16.1.0` a `172.16.1.255`).
- **Red externa ("Internet" simulado):** `203.0.113.0/29` (rango de documentación RFC 5737).
- **Criterio de ordenamiento:** Subredes asignadas **de mayor a menor** cantidad de hosts requeridos, **sin solapamientos**.
- **Regla de Gateway:** Los hosts requeridos incluyen el gateway; el gateway de cada LAN es la **primera IP utilizable**.

---

## 2. Tabla de Subredes VLSM (Ordenadas de Mayor a Menor)

| Orden | Segmento / Red | Hosts Requeridos (incl. GW) | Prefijo / Máscara | Hosts Utilizables ($2^n - 2$) | Dirección de Red | Primera IP Utilizable (Gateway) | Última IP Utilizable | Dirección de Broadcast |
|:---:|---|:---:|:---:|:---:|---|---|---|---|
| **1** | **VLAN 10 Administración** | 25 | `/27` (`255.255.255.224`) | 30 | `172.16.1.0/27` | `172.16.1.1` (`r2 eth3.10`) | `172.16.1.30` | `172.16.1.31` |
| **2** | **VLAN 20 Ventas** | 12 | `/28` (`255.255.255.240`) | 14 | `172.16.1.32/28` | `172.16.1.33` (`r2 eth3.20`) | `172.16.1.46` | `172.16.1.47` |
| **3** | **Segmento Servidores** | 6 | `/29` (`255.255.255.248`) | 6 | `172.16.1.48/29` | `172.16.1.49` (`r1 eth3`) | `172.16.1.54` | `172.16.1.55` |
| **4** | **Enlace WAN 1 (`r1` – `r2`)** | 2 | `/30` (`255.255.255.252`) | 2 | `172.16.1.56/30` | `172.16.1.57` (`r1 eth1`) | `172.16.1.58` (`r2 eth1`) | `172.16.1.59` |
| **5** | **Enlace WAN 2 (`r1` – `r3`)** | 2 | `/30` (`255.255.255.252`) | 2 | `172.16.1.60/30` | `172.16.1.61` (`r1 eth2`) | `172.16.1.62` (`r3 eth1`) | `172.16.1.63` |
| **6** | **Enlace WAN 3 (`r2` – `r3`)** | 2 | `/30` (`255.255.255.252`) | 2 | `172.16.1.64/30` | `172.16.1.65` (`r2 eth2`) | `172.16.1.66` (`r3 eth2`) | `172.16.1.67` |
| **Ext** | **Red Externa ("Internet")** | 2 | `/29` (`255.255.255.248`) | 6 | `203.0.113.0/29` | `203.0.113.1` (`r1 eth4`) | `203.0.113.6` | `203.0.113.7` |

> **Espacio libre restante en el bloque `172.16.1.0/24`:** `172.16.1.68` – `172.16.1.255` (188 direcciones libres, permitiendo crecimiento futuro como la **VLAN 30 Invitados** en `172.16.1.80/28`).

---

## 3. Tabla de Asignación de IPs por Nodo e Interfaz

| Nodo | Rol | Interfaz | Dirección IP / Prefijo | Gateway por Defecto | VLAN / Observación |
|---|---|---|---|---|---|
| **`r1`** | Router de borde (FRR + NAT) | `eth1` | `172.16.1.57/30` | — (OSPF Área 0) | Enlace punto a punto hacia `r2:eth1` |
| **`r1`** | Router de borde (FRR + NAT) | `eth2` | `172.16.1.61/30` | — (OSPF Área 0) | Enlace punto a punto hacia `r3:eth1` |
| **`r1`** | Router de borde (FRR + NAT) | `eth3` | `172.16.1.49/29` | — (OSPF Área 0) | Gateway del Segmento Servidores (vía `sw-b`) |
| **`r1`** | Router de borde (FRR + NAT) | `eth4` | `203.0.113.1/29` | — (Borde Externo) | Primera IP utilizable de `203.0.113.0/29` (NAT `MASQUERADE`) |
| **`r2`** | Router de sede (FRR) | `eth1` | `172.16.1.58/30` | `172.16.1.57` (OSPF) | Enlace punto a punto hacia `r1:eth1` |
| **`r2`** | Router de sede (FRR) | `eth2` | `172.16.1.65/30` | `172.16.1.57` (OSPF) | Enlace punto a punto hacia `r3:eth2` |
| **`r2`** | Router de sede (Router-on-a-Stick) | `eth3.10` | `172.16.1.1/27` | — | Subinterfaz 802.1Q **VLAN 10** (Gateway Administración) |
| **`r2`** | Router de sede (Router-on-a-Stick) | `eth3.20` | `172.16.1.33/28` | — | Subinterfaz 802.1Q **VLAN 20** (Gateway Ventas) |
| **`r3`** | Router de tránsito (FRR) | `eth1` | `172.16.1.62/30` | `172.16.1.61` (OSPF) | Enlace punto a punto hacia `r1:eth2` |
| **`r3`** | Router de tránsito (FRR) | `eth2` | `172.16.1.66/30` | `172.16.1.61` (OSPF) | Enlace punto a punto hacia `r2:eth2` |
| **`sw-a`** | Switch Clientes | Bridge L2 | Sin IP (Capa 2) | — | Bridge de Linux entre `r2:eth3`, `pc-admin` y `pc-ventas` |
| **`sw-b`** | Switch Servidores | Bridge L2 | Sin IP (Capa 2) | — | Bridge de Linux entre `r1:eth3`, `srv-web` y `srv-datos` |
| **`pc-admin`** | Cliente Administración | `eth1.10` | `172.16.1.2/27` | `172.16.1.1` | Subinterfaz 802.1Q **VLAN 10** |
| **`pc-ventas`** | Cliente Ventas | `eth1.20` | `172.16.1.34/28` | `172.16.1.33` | Subinterfaz 802.1Q **VLAN 20** |
| **`srv-web`** | Servidor HTTP (Nginx) | `eth1` | `172.16.1.50/29` | `172.16.1.49` | Puerto `80/TCP` en segmento Servidores |
| **`srv-datos`** | Servidor Datos (Netcat) | `eth1` | `172.16.1.51/29` | `172.16.1.49` | Puerto `9000/TCP` en segmento Servidores |
| **`externo`** | "Internet" simulado | `eth1` | `203.0.113.2/29` | Sin ruta a RFC1918 | Segunda IP utilizable de `203.0.113.0/29` |
