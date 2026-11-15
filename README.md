# Proyecto Final: NetLab Monitor (Grupo 1)

Infraestructura de red virtual en **Containerlab** con segmentación por **VLANs (802.1Q Router-on-a-Stick)**, enrutamiento dinámico **OSPF Área 0** con camino redundante (`r3`), salida controlada hacia Internet simulado con **NAT (`MASQUERADE`)** en `r1`, servicios en segmento de servidores (`HTTP` y `TCP/9000` con Netcat) y auditoría automatizada por capas mediante `netlab_monitor.py`.

---

## 1. Estructura del Proyecto

```text
~/containerlab/proyecto/
├── README.md                # Instrucciones de despliegue, monitoreo y defensa
├── netlab.clab.yml          # Topología declarativa de Containerlab
├── desplegar.sh             # Script maestro de despliegue reproducible
├── destruir.sh              # Script de limpieza total (incluye bridges sw-a y sw-b)
├── config-ip.sh             # Configuración de IP forwarding e IPs de enlaces/servidores
├── config-vlans.sh          # Subinterfaces 802.1Q (VLAN 10 y VLAN 20) en r2 y clientes
├── rutas-estaticas.sh       # Gateways por defecto en clientes y servidores
├── config-ospf.sh           # Configuración de OSPF Área 0 en r1, r2 y r3 (FRRouting)
├── config-nat.sh            # Regla NAT (MASQUERADE) y filtrado FORWARD en r1
├── netlab_monitor.py        # Herramienta de monitoreo y diagnóstico por capas
├── monitor.json             # Archivo de configuración externo del monitor
├── generar-evidencias.sh    # Script para recolectar salidas reales en evidencias/
├── evidencias/              # Salidas reales de comandos (> y >>) e historial.txt
├── docs/                    # Diagrama de red, plan VLSM (.md/.csv) e informe técnico
└── bitacora-ia.md           # Registro de uso, correcciones y rechazos a propuestas de IA
```

---

## 2. Pasos para Desplegar y Ejecutar el Monitor

### 2.1 Dar permisos de ejecución y desplegar desde cero
```bash
chmod +x *.sh
./desplegar.sh
```

> **Orden de ejecución dentro de `desplegar.sh`:**
> 1. Limpia restos previos y crea los bridges de Linux `sw-a` y `sw-b` (deshabilitando `br_netfilter` en el host para que el firewall de Docker no bloquee tramas 802.1Q ni tráfico L2 en los switches).
> 2. Despliega los contenedores y enlaces con `sudo containerlab deploy -t netlab.clab.yml --reconfigure`.
> 3. Ejecuta `./config-ip.sh` (habilita `net.ipv4.ip_forward=1` en `r1`, `r2`, `r3` y asigna IPs base).
> 4. Ejecuta `./config-vlans.sh` (crea subinterfaces `eth3.10` y `eth3.20` en `r2`, `eth1.10` en `pc-admin` y `eth1.20` en `pc-ventas`).
> 5. Ejecuta `./rutas-estaticas.sh` (define el default gateway en clientes y servidores, y libera la ruta por defecto en `r2` y `r3` para que instalen la ruta default de OSPF).
> 6. Ejecuta `./config-ospf.sh` (activa `ospfd` en FRRouting, configura enlaces punto a punto en Área 0 e inyecta la ruta por defecto desde `r1`).
> 7. Ejecuta `./config-nat.sh` (configura `MASQUERADE` en la cadena `POSTROUTING` de la tabla `nat` hacia `eth4` en `r1`).
> 8. Levanta los servicios (`nginx` en `srv-web:80` y `nc` en `srv-datos:9000`).

### 2.2 Ejecutar el Monitor (`netlab_monitor.py`)
```bash
python3 netlab_monitor.py
```
Opciones adicionales (Nivel 3 Avanzado):
```bash
python3 netlab_monitor.py -c monitor.json -o reporte_monitor.txt -j reporte_monitor.json
echo "Código de salida: $?"
```
- Si las **7 verificaciones** están en **`[OK]`**, imprime el reporte en consola, guarda `reporte_monitor.txt` (y `reporte_monitor.json`) y retorna código de salida **`0`**.
- Si alguna prueba falla, clasifica la falla según la escalera del curso (`Enlace/VLAN → IP/Gateway → Rutas/OSPF → NAT → Servicios`) y retorna código de salida **`1`**.

### 2.3 Generar Evidencias Reales (`evidencias/`)
Con el laboratorio desplegado y en verde:
```bash
./generar-evidencias.sh
history > evidencias/historial.txt
```

### 2.4 Destruir el Laboratorio
```bash
./destruir.sh
```

---

## 3. Guía Rápida para la Defensa en Video (Preguntas 3 y 4)

Según la tabla de asignación por grupo (**Grupo 1 → Letra A**):

### Pregunta 3 (Falla Asignada Letra A: Detener OSPF en `r3`)
1. **Aplicar la falla:**
   ```bash
   docker exec clab-proyecto-grupo1-r3 vtysh -c "configure terminal" -c "no router ospf"
   ```
2. **Ejecutar el monitor:**
   ```bash
   python3 netlab_monitor.py
   ```
   - **Qué pasa a `FAIL`:** `3. Rutas (Capa Rutas/OSPF)` (porque `r3` pierde las rutas aprendidas por OSPF) y `6. OSPF (Capa Rutas/OSPF)` (porque `r3` tiene 0 vecinos `Full` y `r1`/`r2` bajan de 2 a 1 vecino `Full`).
   - **Qué sigue en `OK`:** `1. Inventario`, `2. Interfaces y VLANs`, `4. Conectividad`, `5. Servicios` y `7. NAT` siguen en `OK` porque el tráfico entre clientes (`r2`) y servidores/externo (`r1`) sigue fluyendo por el enlace directo principal `r1–r2` (`172.16.1.56/30`).
   - **Capa de la falla:** `Rutas/OSPF`.
3. **Corregir la falla y volver a verde:**
   ```bash
   sudo ./config-ospf.sh
   sleep 4
   python3 netlab_monitor.py
   ```

### Pregunta 4 (Cambio Asignado Letra A: Agregar VLAN 30 "Invitados" con 10 hosts requeridos y un cliente)
- **Subred VLSM para 10 hosts requeridos:** `/28` (14 hosts utilizables) → siguiente bloque `/28` libre sin solapamientos: **`172.16.1.80/28`** (Gateway en `r2` `eth3.30`: `172.16.1.81/28`, cliente `pc-invitados`: `172.16.1.82/28`).
- En `monitor.json`, basta con agregar la entrada en `"vlans"` (`{"id": 30, "nombre": "Invitados", "red": "172.16.1.80/28", "gateway": "172.16.1.81", "cliente": "pc-invitados"}`), el nodo en `"nodos"` y la red `"172.16.1.80/28"` en `"rutas_esperadas"`, **sin tocar una sola línea de `netlab_monitor.py`**.
