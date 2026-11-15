# Informe Técnico y Guía de Defensa — NetLab Monitor (Grupo 1)

## 1. Resumen de la Arquitectura Implementada

El proyecto implementa una red empresarial virtualizada en **Containerlab** utilizando el bloque de direccionamiento **`172.16.1.0/24`** (Grupo 1) subdividido con **VLSM** sin solapamientos:

1. **Capa de Enlace y VLANs (802.1Q Router-on-a-Stick):**
   - El switch `sw-a` (bridge de Linux) interconecta a los clientes `pc-admin` (VLAN 10 Administración, `/27`) y `pc-ventas` (VLAN 20 Ventas, `/28`) con la interfaz troncal `eth3` del router de sede `r2`.
   - En `r2` se crearon las subinterfaces `eth3.10` (`172.16.1.1/27`) y `eth3.20` (`172.16.1.33/28`) mediante `ip link add link eth3 name eth3.<id> type vlan id <id>`, actuando como puerta de enlace de cada VLAN.
2. **Capa de Red y Enrutamiento Dinámico (OSPF Área 0):**
   - Los tres routers (`r1`, `r2`, `r3`) ejecutan **FRRouting (`ospfd`)** en el **Área 0 (backbone)** formando una topología en triángulo con tres enlaces `/30` (`172.16.1.56/30`, `172.16.1.60/30` y `172.16.1.64/30`).
   - Los enlaces entre routers están configurados como `point-to-point` con `hello-interval 1` y `dead-interval 4`, logrando adyacencia `Full` inmediata y reconvergencia automática por `r3` en 4 segundos ante la caída del enlace principal `r1–r2`.
   - Las interfaces hacia LANs y hacia Internet (`eth3.10`, `eth3.20` en `r2`, `eth3` y `eth4` en `r1`) se declaran como `passive-interface` para no enviar paquetes Hello OSPF innecesarios hacia los hosts.
   - El router de borde `r1` inyecta una ruta por defecto (`0.0.0.0/0`) hacia el dominio OSPF mediante `default-information originate always`.
3. **Traducción de Direcciones de Red (NAT `MASQUERADE` en `r1`):**
   - En `r1`, la tabla `nat` en la cadena `POSTROUTING` aplica `MASQUERADE` únicamente a los paquetes que salen por `eth4` (`-s 172.16.1.0/24 -o eth4 -j MASQUERADE`).
   - De este modo, el tráfico interno entre clientes (`VLAN 10/20`) y servidores (`172.16.1.48/29`) se enruta de forma pura sin NAT, mientras que el tráfico hacia la red externa (`203.0.113.0/29`) sale traducido con la IP pública de `r1` (`203.0.113.1`).
4. **Capa de Servicios y Auditoría (`netlab_monitor.py`):**
   - `srv-web` (`172.16.1.50`) ejecuta un servidor HTTP (`nginx`) en el puerto `80/TCP`.
   - `srv-datos` (`172.16.1.51`) ejecuta un servicio en el puerto `9000/TCP` con `netcat`.
   - El script `netlab_monitor.py` lee toda la topología desde `monitor.json` y audita las 7 verificaciones siguiendo la escalera diagnóstica del curso: **`Enlace/VLAN → IP/Gateway → Rutas/OSPF → NAT → Servicios`**.

---

## 2. Respuestas a las Preguntas de Investigación Autónoma (Sección 8)

### 2.1 Sobre OSPF
- **¿Qué es un vecino y qué estados atraviesa hasta `Full`?**
  Un vecino OSPF es un router conectado a una subred común con el que se intercambian paquetes *Hello*. Los estados que atraviesa son: `Down` → `Init` (recibe Hello sin su propio Router-ID) → `2-Way` (comunicación bidireccional establecida; en redes broadcast aquí se elige DR/BDR) → `ExStart` (acuerdan maestro/esclavo y número de secuencia DD) → `Exchange` (intercambian descriptores de base de datos DBD) → `Loading` (solicitan y reciben LSAs faltantes mediante LSR/LSU) → `Full` (bases de datos LSDB completamente sincronizadas).
- **¿Qué es el área 0 y qué métrica usa OSPF?**
  El **Área 0 (Backbone)** es el área central de OSPF por la cual debe transitar todo el tráfico inter-área. OSPF usa como métrica el **costo**, inversamente proporcional al ancho de banda de la interfaz ($\text{Costo} = \frac{\text{Ancho de banda de referencia (100 Mbps)}}{\text{Ancho de banda de la interfaz}}$).
- **¿Cómo se anuncia una red y cómo se propaga una ruta por defecto?**
  Una red se anuncia dentro de `router ospf` con el comando `network <red>/<prefijo> area 0`, que activa OSPF en las interfaces que caen en ese rango e incluye su prefijo en los Router-LSA (Tipo 1). La ruta por defecto se propaga desde el router de borde (`r1`) con `default-information originate always`, que genera un LSA Externo Tipo 5 para `0.0.0.0/0`.

### 2.2 Sobre NAT
- **¿En qué tabla y cadena se aplica `MASQUERADE`? ¿Qué diferencia hay con `SNAT`?**
  Se aplica en la tabla **`nat`** y en la cadena **`POSTROUTING`** (justo después de la decisión de enrutamiento, antes de que el paquete salga por la interfaz física `eth4`). La diferencia con `SNAT` es que `SNAT` requiere especificar manualmente una IP estática (`--to-source 203.0.113.1`), mientras que `MASQUERADE` toma dinámicamente la IP asignada a la interfaz de salida (`-o eth4`) y limpia las entradas de seguimiento si la interfaz cae.
- **¿Por qué requiere forwarding y cómo se ven las conexiones traducidas?**
  Porque el paquete que llega desde el cliente (`172.16.1.2`) tiene como destino `203.0.113.2` (que no es una IP local de `r1`); si `net.ipv4.ip_forward` está en `0`, el kernel descarta el paquete antes de siquiera llegar a la cadena `FORWARD` y `POSTROUTING`. Las conexiones traducidas se ven en los contadores con `iptables -t nat -L POSTROUTING -v -n` o en la tabla de seguimiento de conexiones (`/proc/net/nf_conntrack` / `conntrack -L`).

---

## 3. Respuestas a las 6 Preguntas Individuales de Defensa (Pregunta 5 de la Pauta)

1. **¿Qué hace la función de su script que revisa las rutas y qué ocurre si `docker exec` falla?**
   - La función `check_rutas(config)` recorre el diccionario `"rutas_esperadas"` de `monitor.json` para cada router (`r1`, `r2`, `r3`), ejecuta `ip route` mediante `run_docker_cmd(router, "ip route")` y comprueba que cada subred esperada (`172.16.1.0/27`, `172.16.1.32/28`, `172.16.1.48/29` y `default`) esté presente en la salida, además de verificar que `net.ipv4.ip_forward` sea `1`.
   - Si `docker exec` falla (por contenedor apagado, error de comando o timeout de 6 segundos), la función auxiliar `run_docker_cmd` captura la excepción en un bloque `try/except` y devuelve el mensaje de error junto con un código de retorno distinto de cero (`rc != 0`), evitando que el script aborte abruptamente y registrando la falla en la lista `fallas` bajo la capa `Rutas/OSPF`.

2. **¿Por qué `externo` ve la IP de `r1` y no la del cliente?**
   - Porque cuando el paquete de `pc-admin` (`172.16.1.2`) o `pc-ventas` (`172.16.1.34`) atraviesa `r1` rumbo a `externo` (`203.0.113.2`) y va a salir por la interfaz `eth4`, la regla `iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -o eth4 -j MASQUERADE` reescribe en la cabecera IP la dirección de origen privada del cliente por la dirección IP de `r1` en `eth4` (`203.0.113.1`), guardando la relación en la tabla `conntrack` para destraducir la respuesta al volver.

3. **Si cae el enlace `r1–r2`, ¿qué pasa con las rutas y cómo se ve en su reporte?**
   - Al caer el enlace directo `r1:eth1 <-> r2:eth1` (`172.16.1.56/30`), expira el `dead-interval` (4 segundos) de esa adyacencia OSPF. El algoritmo SPF recalcula el árbol de caminos más cortos y tanto `r1` como `r2` actualizan sus tablas `ip route` para enrutar hacia las subredes del otro **a través del router de tránsito `r3`** (`r2 → r3 → r1`).
   - En el reporte de `netlab_monitor.py`: las pruebas **3 (Rutas)**, **4 (Conectividad: ping y traceroute)**, **5 (Servicios)** y **7 (NAT)** **siguen dando `[OK]`** gracias a la reconvergencia por `r3` (el traceroute ahora muestra un salto adicional pasando por `172.16.1.65`/`172.16.1.66`), mientras que la prueba **6 (OSPF)** alerta `[FAIL]` en `r1` y `r2` indicando que tienen `1/2` vecinos en estado `Full` debido al enlace caído.

4. **¿Qué diferencia hay entre una ruta estática y una aprendida por OSPF en `ip route`?**
   - Una **ruta estática** (o configurada manualmente con `ip route add/replace`) aparece sin el atributo `proto ospf` y no tiene métrica dinámica ni se adapta si cae el enlace. En cambio, una **ruta aprendida por OSPF** es inyectada por el demonio `ospfd`/`zebra` de FRRouting y se distingue explícitamente en la salida de `ip route` porque incluye `proto ospf` y su costo/métrica (por ejemplo: `172.16.1.0/27 nhid 15 via 172.16.1.58 dev eth1 proto ospf metric 20`).

5. **¿Por qué la falla asignada pertenece a esa capa y no a otra?**
   - *(Para Grupo 1 — Falla A: Detener OSPF en `r3`)*: Pertenece a la capa **`Rutas/OSPF`** porque las interfaces físicas y VLANs están `UP` (`Capa Enlace/VLAN` OK), todas las direcciones IP y gateways están correctamente asignados (`Capa IP/Gateway` OK), el NAT en `r1` funciona (`Capa NAT` OK) y los demonios en los servidores escuchan en sus puertos (`Capa Servicios` OK). Lo único que falla es el plano de control de enrutamiento dinámico en `r3` (`ospfd`), provocando que `r3` pierda sus adyacencias `Full` y las rutas aprendidas dinámicamente.

6. **¿Qué propuso la IA que ustedes corrigieron o rechazaron, y por qué?**
   - La IA propuso inicialmente: (a) eliminar el switch `sw-a` y las subinterfaces VLAN 802.1Q cuando los pings fallaban (lo rechazamos y corregimos deshabilitando `br_netfilter` de Docker en el host, ya que el firewall del host estaba descartando las tramas 802.1Q en los bridges de Linux), (b) no borrar la ruta `default dev eth0` de Docker en `r2` y `r3` (lo corregimos porque esa ruta de distancia 0 impedía que Zebra instalara la ruta por defecto de OSPF), y (c) dejar IPs de VLANs y nombres de clientes hardcodeados en `netlab_monitor.py` (lo corregimos para que todo se lea dinámicamente desde `monitor.json`).
