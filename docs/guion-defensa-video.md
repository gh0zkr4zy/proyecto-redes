# Guion Completo de Defensa en Video (15–20 min)
**Integrantes:** Dylan (comparte pantalla y opera la terminal), Pablito y Sebita.

---

## Reglas Obligatorias de la Pauta (Checklist antes de grabar)
- [ ] **Cámara encendida de los 3 integrantes** durante el video y cada uno habla con su propia voz.
- [ ] **Terminal visible en pantalla** (con letra grande, `Ctrl + +` un par de veces para que se lea claro).
- [ ] **PROHIBIDO hacer cortes de edición en las Preguntas 3 y 4** (háganlo de corrido).
- [ ] Antes de empezar a grabar, ten la terminal abierta dentro de la carpeta del proyecto con el laboratorio ya corriendo.

---

## INICIO DEL VIDEO: Verificación Obligatoria (00:00 – 01:00)

### 🖥️ Qué mostrar en pantalla (Dylan):
Tener la terminal abierta en la carpeta del proyecto y pegar este comando:
```bash
date && hostname && ls -la
```

### 🗣️ Qué decir:
- **Dylan:** *"Buenas profesor, somos el Grupo 1 integrado por Dylan, Pablo y Sebastián, y esta es nuestra defensa técnica del proyecto final NetLab Monitor. Para comenzar con las reglas de validación, ejecutamos en la terminal los comandos `date`, `hostname` y `ls -la` mostrando la fecha actual, el nombre del host y todos los scripts y entregables de nuestro directorio de trabajo."*

---

## PREGUNTA 1: Despliegue desde cero (01:00 – 05:00)

### 🖥️ Qué mostrar en pantalla (Dylan):
1. Primero ejecutar la destrucción del laboratorio:
```bash
./destruir.sh
```
2. Mostrar brevemente que no hay bridges ni contenedores:
```bash
ip -br link show sw-a sw-b
```
3. Ejecutar el despliegue completo desde cero:
```bash
./desplegar.sh
```

### 🗣️ Qué decir (mientras corre `./destruir.sh` y `./desplegar.sh`):

- **Dylan (Explica `destruir.sh`, `desplegar.sh` y Capa 1/2):**
  *"Para la Pregunta 1, primero destruimos el laboratorio con `./destruir.sh`. Este script ejecuta `containerlab destroy --cleanup`, limpia las rutas auxiliares del host y elimina explícitamente con `ip link delete` los bridges de Linux `sw-a` y `sw-b`, ya que Containerlab no elimina los bridges del sistema anfitrión por sí solo.*
  *Ahora ejecutamos `./desplegar.sh`, que orquesta el despliegue en un orden estrictamente ascendente según el modelo OSI, porque cada capa depende de que la capa inferior ya exista:*
  *Primero, en Capa 1 y 2, `desplegar.sh` carga el módulo del kernel `8021q`, crea y levanta los switches `sw-a` y `sw-b` antes de llamar a `containerlab deploy -t netlab.clab.yml`, porque Containerlab necesita que los bridges ya existan en el host para conectar los enlaces veth de los contenedores. Además, desactivamos `br_netfilter` en los bridges para que el firewall de Docker del host no descarte tramas etiquetadas 802.1Q."*

- **Pablito (Explica `config-ip.sh`, `config-vlans.sh` y `rutas-estaticas.sh`):**
  *"Una vez creados los contenedores, `desplegar.sh` llama en segundo lugar a `./config-ip.sh`. Este script va primero en la configuración lógica porque habilita el reenvío de paquetes (`net.ipv4.ip_forward=1`) en `r1`, `r2` y `r3`, levanta las interfaces físicas `eth1` a `eth4` y asigna las IPs de nuestro plan VLSM `172.16.1.0/24` en los enlaces `/30` entre routers, el segmento de servidores `/29` (`172.16.1.48/29`) y la red externa `203.0.113.0/29`.*
  *En tercer lugar se ejecuta `./config-vlans.sh`, que requiere que `eth3` en `r2` y `eth1` en los clientes ya estén arriba. Configura el esquema Router-on-a-Stick en `r2` creando las subinterfaces 802.1Q `eth3.10` con el gateway `172.16.1.1/27` para la VLAN 10 Administración y `eth3.20` con `172.16.1.33/28` para la VLAN 20 Ventas, además de las subinterfaces `eth1.10` en `pc-admin` y `eth1.20` en `pc-ventas`.*
  *En cuarto lugar corre `./rutas-estaticas.sh`, que debe ejecutarse después de tener las IPs y subinterfaces activas, porque el kernel de Linux rechaza una ruta `default via <gateway>` si la IP del gateway aún no es alcanzable en una subred local. Aquí configuramos la puerta de enlace por defecto en clientes y servidores, y eliminamos la ruta por defecto de gestión `eth0` de Docker en `r2` y `r3` para que puedan instalar la ruta por defecto de OSPF."*

- **Sebita (Explica `config-ospf.sh`, `config-nat.sh` y servicios):**
  *"En quinto lugar se ejecuta `./config-ospf.sh`. Debe ir después de configurar las IPs y VLANs para que el demonio `ospfd` de FRRouting detecte todas las interfaces activas dentro del área 0. Configuramos los enlaces `/30` como `point-to-point` con intervalos Hello de 1 segundo y Dead de 4 segundos para que los vecinos converjan al estado `Full` casi al instante sin esperar los 40 segundos de elección DR/BDR, declaramos pasivas las interfaces LAN, anunciamos las redes internas en el Área 0 y propagamos la ruta por defecto desde `r1` con `default-information originate always`.*
  *En sexto lugar corre `./config-nat.sh`, que aplica la regla `MASQUERADE` en la cadena `POSTROUTING` de la tabla `nat` de `r1` hacia la interfaz externa `eth4` y las reglas `FORWARD` con seguimiento de estado `RELATED,ESTABLISHED`.*
  *Finalmente, con toda la conectividad de red lista, `desplegar.sh` levanta los servicios de capa de aplicación: el servidor HTTP Nginx en `srv-web` (puerto 80) y el segundo servicio TCP con Netcat en `srv-datos` (puerto 9000)."*

---

## PREGUNTA 2: Monitor en verde (05:00 – 09:00)

### 🖥️ Qué mostrar en pantalla (Dylan):
Ejecutar el monitor y mostrar el código de salida (`0`):
```bash
python3 netlab_monitor.py
echo "Codigo de salida: $?"
```
*(Deja visible en pantalla el reporte completo con los 7 `[OK]`).*

### 🗣️ Qué decir:

- **Dylan (Explica Verificaciones 1, 2 y 3):**
  *"En la Pregunta 2 ejecutamos `python3 netlab_monitor.py` y obtenemos las 7 verificaciones en `[OK]` con código de salida 0. Toda la configuración esperada se lee desde `monitor.json`.*
  *En la **Sección 1 (Inventario)**, el script ejecuta `ip -br link show` en el host para verificar que los bridges `sw-a` y `sw-b` existan, y `docker exec <nodo> ip -br a` en cada contenedor comprobando que tenga asignada la IP esperada de `monitor.json`. Si faltara una IP o un contenedor estuviera caído, reportaría `[FAIL]` ubicando la falla en la capa `IP/Gateway` o `Enlace/VLAN`.*
  *En la **Sección 2 (Interfaces y VLANs)**, ejecuta `ip -br a` e `ip -d link` por cada nodo. Espera encontrar en `r2` las subinterfaces 802.1Q con `vlan id 10` (`172.16.1.1/27`) y `vlan id 20` (`172.16.1.33/28`), y en `pc-admin` y `pc-ventas` sus subinterfaces con el VLAN ID correspondiente. Si una subinterfaz no existiera o tuviera un VLAN ID distinto, reportaría `[FAIL]` en la capa `Enlace/VLAN`.*
  *En la **Sección 3 (Rutas)**, consulta `sysctl -n net.ipv4.ip_forward` (esperando `1`) y ejecuta `ip route` en `r1`, `r2` y `r3`, comparando la salida contra las subredes de `rutas_esperadas` en `monitor.json` (`172.16.1.0/27`, `172.16.1.32/28`, `172.16.1.48/29` y `default`). Si faltara alguna ruta, reportaría `[FAIL]` en la capa `Rutas/OSPF`."*

- **Pablito (Explica Verificaciones 4 y 5):**
  *"En la **Sección 4 (Conectividad)**, el script construye dinámicamente una matriz entre todos los clientes (`pc-admin`, `pc-ventas`) y todos los destinos (`srv-web`, `srv-datos` y `externo`). Por cada par ejecuta `ping -c 2 -W 2` y `traceroute -n -w 1 -m 6`. Espera código de retorno 0 en el ping y que la IP de destino aparezca en el último salto del traceroute. Si fallara hacia servidores lo clasificaría en `IP/Gateway` o `Rutas/OSPF`, y si fallara solo hacia `externo` en `NAT`.*
  *En la **Sección 5 (Servicios)**, para cada servicio declarado en `monitor.json` (`srv-web` en el puerto 80/TCP y `srv-datos` en el puerto 9000/TCP), primero ejecuta `ss -tulpn` dentro del contenedor esperando ver `:80` y `:9000` en estado LISTEN, y luego abre un socket nativo de Python con `socket.socket(AF_INET, SOCK_STREAM)` ejecutando `s.connect((ip, puerto))`. Si el demonio estuviera caído o el puerto cerrado, reportaría `[FAIL]` en la capa `Servicios`."*

- **Sebita (Explica Verificaciones 6, 7 y 8 - Reporte):**
  *"En la **Sección 6 (OSPF)**, ejecuta `vtysh -c 'show ip ospf neighbor'` en `r1`, `r2` y `r3`. Como nuestra topología entre routers es un triángulo en el Área 0, espera contar exactamente 2 vecinos en estado `Full` en cada router. Si algún vecino tuviera menos de 2 adyacencias en `Full`, reportaría `[FAIL]` en la capa `Rutas/OSPF`.*
  *En la **Sección 7 (NAT)**, genera tráfico desde `pc-admin` hacia `externo`, ejecuta `iptables -t nat -L POSTROUTING -v -n` en `r1` esperando encontrar la regla `MASQUERADE` con contador de paquetes mayor a cero (`pkts > 0`), y además revisa el log de conexiones en `externo` (`/var/log/nginx/access.log` e `ip neigh`) comprobando que `externo` ve la IP pública de `r1` (`203.0.113.1`) y nunca la IP privada del cliente (`172.16.1.2`). Si no existiera la regla, el contador fuera 0 o se viera la IP privada del cliente, reportaría `[FAIL]` en la capa `NAT`.*
  *Finalmente, la **Sección 8 (Reporte)** genera `reporte_monitor.txt` y `reporte_monitor.json` con fecha y hora, determina la capa de falla raíz siguiendo la escalera del curso (`Enlace/VLAN -> IP/Gateway -> Rutas/OSPF -> NAT -> Servicios`) y devuelve código de salida distinto de cero (`1`) si algo falla."*

---

## PREGUNTA 3: Falla asignada — Grupo 1 Letra A: Detener OSPF en `r3` (09:00 – 12:00)
*(⚠️ RECUERDA: SIN CORTES DE EDICIÓN EN ESTA PREGUNTA)*

### 🖥️ Qué mostrar en pantalla (Dylan):
1. Aplicar la falla asignada al Grupo 1 (Letra A: Detener OSPF en `r3`):
```bash
docker exec clab-proyecto-grupo1-r3 vtysh -c "configure terminal" -c "no router ospf"
```
2. Ejecutar el monitor para mostrar el fallo y el código de salida `1`:
```bash
python3 netlab_monitor.py
echo "Codigo de salida: $?"
```
3. *(Cuando terminen de explicar la falla)* Corregir la falla restaurando OSPF y volver a ejecutar el monitor hasta que quede todo en verde:
```bash
sudo ./config-ospf.sh
sleep 4
python3 netlab_monitor.py
echo "Codigo de salida: $?"
```

### 🗣️ Qué decir:

- **Dylan (Aplica la falla y muestra qué pasó a FAIL y qué siguió en OK):**
  *"Para la Pregunta 3, como somos el Grupo 1 nos corresponde la **Letra A: Detener OSPF en `r3`**. Ejecutamos `no router ospf` en `r3` mediante `vtysh` y corremos `python3 netlab_monitor.py`.*
  *Como se observa en el reporte, el script devuelve código de salida `1` (`FAIL`). Las pruebas que pasaron a **`[FAIL]`** son únicamente la **3 (Rutas)** —porque `r3` perdió las rutas aprendidas por OSPF (`172.16.1.0/27`, `172.16.1.32/28`, `172.16.1.48/29` y `default`)— y la **6 (OSPF)** —porque `r3` ahora tiene `0/2` vecinos en estado `Full`, mientras que `r1` y `r2` bajaron a `1/2` vecinos en `Full` al perder su adyacencia con `r3`."*

- **Pablito (Ubica la falla en una capa y justifica por qué las demás siguen en OK):**
  *"Por otro lado, las pruebas **1 (Inventario)**, **2 (Interfaces y VLANs)**, **4 (Conectividad)**, **5 (Servicios)** y **7 (NAT)** **siguieron en `[OK]`**. ¿Por qué? Porque `r3` es el router de tránsito sin LAN que ofrece el camino alterno; los clientes en `r2` y los servidores/salida externa en `r1` siguen comunicándose directamente por el enlace primario `r1–r2` (`172.16.1.56/30`).*
  *El monitor ubica correctamente la falla raíz en la capa **`Rutas/OSPF`** de la escalera del curso, porque todas las interfaces y VLANs están arriba (`Enlace/VLAN` OK) y las IPs y gateways están bien configurados (`IP/Gateway` OK); el problema está exclusivamente en el protocolo de enrutamiento dinámico OSPF en `r3`.*
  *Ahora corregimos la falla ejecutando `sudo ./config-ospf.sh`, esperamos 4 segundos a que converjan las adyacencias punto a punto, volvemos a ejecutar `python3 netlab_monitor.py` y comprobamos que las 7 pruebas vuelven a estar en **`[OK]`** con código de salida `0`."*

---

## PREGUNTA 4: Cambio asignado — Grupo 1 Letra A: Agregar VLAN 30 "Invitados" (10 hosts) y un cliente, editando solo `monitor.json` (12:00 – 15:00)
*(⚠️ RECUERDA: SIN CORTES DE EDICIÓN EN ESTA PREGUNTA)*

### 🖥️ Qué mostrar en pantalla (Dylan):
1. Pegar este bloque en la terminal para crear en caliente la subinterfaz `eth3.30` en `r2` (`172.16.1.81/28`), el contenedor cliente `pc-invitados` (`172.16.1.82/28`) conectado al bridge `sw-a` en la VLAN 30, y actualizar `monitor.json` (sin tocar `netlab_monitor.py`):
```bash
# 1. Crear subinterfaz 802.1Q VLAN 30 en r2 (Subred VLSM /28: 172.16.1.80/28, Gateway: 172.16.1.81)
docker exec clab-proyecto-grupo1-r2 ip link del eth3.30 2>/dev/null || true
docker exec clab-proyecto-grupo1-r2 ip link add link eth3 name eth3.30 type vlan id 30
docker exec clab-proyecto-grupo1-r2 ip link set dev eth3.30 up
docker exec clab-proyecto-grupo1-r2 ip addr add 172.16.1.81/28 dev eth3.30

# 2. Crear cliente pc-invitados conectado a sw-a en VLAN 30 (IP: 172.16.1.82/28)
docker rm -f clab-proyecto-grupo1-pc-invitados 2>/dev/null || true
sudo ip link del inv-cli 2>/dev/null || true
docker run -d --name clab-proyecto-grupo1-pc-invitados --privileged ghcr.io/hellt/network-multitool >/dev/null
PID_INV=$(docker inspect -f '{{.State.Pid}}' clab-proyecto-grupo1-pc-invitados)
sudo ip link add inv-cli type veth peer name eth1 netns "$PID_INV"
sudo ip link set dev inv-cli master sw-a
sudo ip link set dev inv-cli up
docker exec clab-proyecto-grupo1-pc-invitados ip link set dev eth1 up
docker exec clab-proyecto-grupo1-pc-invitados ip link add link eth1 name eth1.30 type vlan id 30
docker exec clab-proyecto-grupo1-pc-invitados ip link set dev eth1.30 up
docker exec clab-proyecto-grupo1-pc-invitados ip addr add 172.16.1.82/28 dev eth1.30
docker exec clab-proyecto-grupo1-pc-invitados ip route replace default via 172.16.1.81 dev eth1.30
```
2. Ahora actualizar `monitor.json` y mostrar con `git diff` que **solo se modificó `monitor.json` y que `netlab_monitor.py` no se tocó**:
```bash
cat << 'EOF' > monitor.json
{
    "prefijo_clab": "clab-proyecto-grupo1-",
    "nodos": {
        "r1": "172.16.1.57",
        "r2": "172.16.1.58",
        "r3": "172.16.1.66",
        "sw-a": "bridge",
        "sw-b": "bridge",
        "pc-admin": "172.16.1.2",
        "pc-ventas": "172.16.1.34",
        "pc-invitados": "172.16.1.82",
        "srv-web": "172.16.1.50",
        "srv-datos": "172.16.1.51",
        "externo": "203.0.113.2"
    },
    "vlans": [
        {
            "id": 10,
            "nombre": "Administracion",
            "red": "172.16.1.0/27",
            "gateway": "172.16.1.1",
            "cliente": "pc-admin"
        },
        {
            "id": 20,
            "nombre": "Ventas",
            "red": "172.16.1.32/28",
            "gateway": "172.16.1.33",
            "cliente": "pc-ventas"
        },
        {
            "id": 30,
            "nombre": "Invitados",
            "red": "172.16.1.80/28",
            "gateway": "172.16.1.81",
            "cliente": "pc-invitados"
        }
    ],
    "servicios": {
        "srv-web": {
            "ip": "172.16.1.50",
            "puerto": 80,
            "protocolo": "tcp"
        },
        "srv-datos": {
            "ip": "172.16.1.51",
            "puerto": 9000,
            "protocolo": "tcp"
        }
    },
    "rutas_esperadas": {
        "r1": [
            "172.16.1.0/27",
            "172.16.1.32/28",
            "172.16.1.80/28",
            "172.16.1.48/29",
            "203.0.113.0/29"
        ],
        "r2": [
            "172.16.1.0/27",
            "172.16.1.32/28",
            "172.16.1.80/28",
            "172.16.1.48/29",
            "default"
        ],
        "r3": [
            "172.16.1.0/27",
            "172.16.1.32/28",
            "172.16.1.80/28",
            "172.16.1.48/29",
            "default"
        ]
    },
    "ospf_routers": ["r1", "r2", "r3"],
    "vecinos_ospf_esperados": 2,
    "nat": {
        "router": "r1",
        "interfaz_salida": "eth4",
        "ip_publica_r1": "203.0.113.1",
        "ip_externo": "203.0.113.2"
    }
}
EOF
git diff monitor.json
```
3. Ejecutar el monitor para demostrar que detecta y valida la VLAN 30, `pc-invitados`, las rutas OSPF y los pings/traceroutes hacia servidores y `externo` sin haber modificado `netlab_monitor.py`:
```bash
python3 netlab_monitor.py
```

### 🗣️ Qué decir:

- **Sebita (Explica el cálculo VLSM de la VLAN 30 y el cambio en `monitor.json`):**
  *"Para la Pregunta 4, el cambio asignado a la Letra A es **agregar la VLAN 30 'Invitados' con 10 hosts requeridos y un cliente, editando en el monitor únicamente `monitor.json`**.*
  *Siguiendo VLSM, para 10 hosts requeridos (incluyendo el gateway) necesitamos un prefijo `/28` ($2^4 - 2 = 14$ hosts utilizables). Como nuestras subredes actuales ocupan hasta `172.16.1.67` y los bloques `/28` se alinean en múltiplos de 16, el siguiente bloque `/28` libre sin solapamiento es **`172.16.1.80/28`**, donde la primera IP utilizable (`172.16.1.81/28`) es el gateway en la subinterfaz `eth3.30` de `r2` y `172.16.1.82/28` se asigna a la subinterfaz `eth1.30` del nuevo cliente `pc-invitados` conectado a `sw-a`.*
  *Como en `r2` OSPF anuncia `172.16.1.0/24 area 0`, `r2` propaga automáticamente la nueva red `172.16.1.80/28` hacia `r1` y `r3`. Con `git diff monitor.json` mostramos que para auditarla solo agregamos `pc-invitados` en `nodos`, la VLAN 30 en `vlans` y la subred `172.16.1.80/28` en `rutas_esperadas`, sin modificar ni una sola línea de `netlab_monitor.py`. Al ejecutar `python3 netlab_monitor.py`, vemos que el reporte incorpora automáticamente a `pc-invitados` y la VLAN 30 en Inventario, VLANs, Rutas y Conectividad dando los **7 `[OK]`**."*

---

## PREGUNTA 5: Preguntas individuales (15:00 – 19:00)
*(Se reparten las 6 preguntas en partes iguales: 2 preguntas cada uno frente a cámara).*

### 👤 Turno 1: Dylan (Preguntas 1 y 2)
*(En pantalla puedes mostrar `netlab_monitor.py` en la función `check_rutas` y `run_docker_cmd`).*

- **Pregunta 5.1: ¿Qué hace la función de su script que revisa las rutas y qué ocurre si `docker exec` falla?**
  - **Dylan:** *"La función `check_rutas(config)` primero verifica que `net.ipv4.ip_forward` esté en `1` en los tres routers y luego recorre el diccionario `rutas_esperadas` de `monitor.json` para `r1`, `r2` y `r3`. En cada router llama a `run_docker_cmd(router, 'ip route')` y comprueba que cada prefijo esperado (`172.16.1.0/27`, `172.16.1.32/28`, `172.16.1.48/29` y `default`) esté en la tabla de enrutamiento. Si `docker exec` falla (por ejemplo si el contenedor está detenido o hay un timeout), `run_docker_cmd` captura la excepción dentro de un bloque `try/except` con `timeout=6` y retorna un código `returncode` distinto de cero sin que el script explote, registrando la falla controlada en la capa `Rutas/OSPF`."*

- **Pregunta 5.2: ¿Por qué `externo` ve la IP de `r1` y no la del cliente?**
  - **Dylan:** *"Porque en `r1` configuramos una regla `MASQUERADE` en la cadena `POSTROUTING` de la tabla `nat` de `iptables` (`iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -o eth4 -j MASQUERADE`). Cuando un paquete de un cliente privado como `172.16.1.2` va a salir por `eth4` hacia `203.0.113.2`, el kernel reescribe la IP de origen del paquete por la IP pública de `r1` en `eth4` (`203.0.113.1`) y guarda el mapeo de puertos en la tabla `conntrack` para destraducir la respuesta cuando regrese desde `externo`."*

---

### 👤 Turno 2: Pablito (Preguntas 3 y 4)

- **Pregunta 5.3: Si cae el enlace `r1–r2`, ¿qué pasa con las rutas y cómo se ve en su reporte?**
  - **Pablito:** *"Si cae el enlace directo `r1–r2` (`172.16.1.56/30`), expira el `dead-interval` de 4 segundos entre `r1` y `r2`. El algoritmo SPF de OSPF recalcula las rutas de menor costo en el Área 0 y tanto `r1` como `r2` actualizan sus tablas `ip route` para alcanzar las redes del otro a través del router de tránsito `r3` (`r2 -> r3 -> r1`). En nuestro reporte, las pruebas **3 (Rutas)**, **4 (Conectividad)**, **5 (Servicios)** y **7 (NAT)** siguen dando **`[OK]`** porque el tráfico reconverge por `r3` (viéndose un salto más en el traceroute), mientras que la prueba **6 (OSPF)** marca **`[FAIL]`** en `r1` y `r2` indicando que tienen `1/2` vecinos en estado `Full` debido al enlace caído."*

- **Pregunta 5.4: ¿Qué diferencia hay entre una ruta estática y una aprendida por OSPF en `ip route`?**
  - **Pablito:** *"En la salida de `ip route`, una ruta estática (agregada manualmente con `ip route add` o `replace`) aparece sin protocolo dinámico y permanece fija aunque el enlace falle. En cambio, una ruta aprendida dinámicamente por OSPF es inyectada en el kernel por el demonio `zebra` de FRRouting y se identifica explícitamente porque incluye la etiqueta **`proto ospf`** junto con su métrica o costo OSPF (por ejemplo, `172.16.1.0/27 via 172.16.1.58 dev eth1 proto ospf metric 20`)."*

---

### 👤 Turno 3: Sebita (Preguntas 5 y 6)

- **Pregunta 5.5: ¿Por qué la falla asignada pertenece a esa capa y no a otra?**
  - **Sebita:** *"Nuestra falla asignada (detener OSPF en `r3`) pertenece a la capa **`Rutas/OSPF`** y no a otra porque, siguiendo la escalera de diagnóstico del curso de abajo hacia arriba: primero, en **`Enlace/VLAN`** todos los enlaces veth, bridges y subinterfaces 802.1Q están en `UP`; segundo, en **`IP/Gateway`** todos los nodos tienen sus IPs y puertas de enlace bien asignadas; cuarto, en **`NAT`** la regla `MASQUERADE` en `r1` sigue traduciendo; y quinto, en **`Servicios`** los puertos 80 y 9000 siguen escuchando. Lo único afectado es el plano de control de enrutamiento dinámico en `r3`, que dejó de formar adyacencias OSPF y de poblar su tabla de rutas."*

- **Pregunta 5.6: ¿Qué propuso la IA que ustedes corrigieron o rechazaron, y por qué?**
  - **Sebita:** *"Tal como documentamos en `bitacora-ia.md`, corregimos y rechazamos tres cosas clave que propuso la IA: primero, la IA propuso reiniciar FRRouting con `/etc/init.d/frr restart` en `config-ospf.sh`, lo cual en la imagen `frrouting/frr:v8.2.2` borraba `watchfrr.pid` haciendo que el proceso principal del contenedor muriera y reiniciara los routers borrando todas sus IPs y VLANs; lo corregimos iniciando el demonio directamente con `/usr/lib/frr/ospfd -d`. Segundo, rechazamos una propuesta de quitar el switch `sw-a` y las subinterfaces 802.1Q cuando los pings fallaban, porque descubrimos que el bloqueo real era el módulo `br_netfilter` de Docker en el host descartando las tramas VLAN en los bridges, lo cual solucionamos deshabilitando `bridge-nf-call-iptables` en `desplegar.sh`. Y tercero, corregimos el código de `netlab_monitor.py` donde la IA había dejado IPs de VLANs y clientes hardcodeados, haciéndolo 100% dinámico desde `monitor.json`."*

---

## (Opcional después de terminar de grabar el video) Dejar `monitor.json` como estaba originalmente y generar las evidencias para el `.zip`:
```bash
git checkout monitor.json
./desplegar.sh
./generar-evidencias.sh
history > evidencias/historial.txt
```
