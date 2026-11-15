# Bitácora de Uso de Inteligencia Artificial (`bitacora-ia.md`)

Registro de consultas realizadas a herramientas de IA durante el desarrollo del proyecto **NetLab Monitor**, detallando qué se solicitó, qué errores propuso la IA y cómo el equipo los detectó, corrigió o rechazó.

---

## 1. Consultas Realizadas (Qué pedimos)

1. **Estructura base del script `netlab_monitor.py`:**
   - Se pidió una plantilla en Python usando únicamente la librería estándar (`subprocess`, `socket`, `os`, `json`, `argparse`, `datetime`) para ejecutar comandos `docker exec` sobre los contenedores de Containerlab y generar el archivo `reporte_monitor.txt`.
2. **Sintaxis de automatización de FRRouting con `vtysh` en `config-ospf.sh`:**
   - Se consultó cómo inyectar comandos de configuración de OSPF de forma no interactiva en contenedores `frrouting/frr:v8.2.2` mediante bloques heredoc (`<< 'EOF'`).
3. **Reglas de `iptables` para `MASQUERADE` en `config-nat.sh`:**
   - Se consultó la sintaxis de las cadenas `POSTROUTING` (tabla `nat`) y `FORWARD` (tabla `filter`) para permitir la salida desde las redes internas hacia `eth4` y el retorno de paquetes con estado `RELATED,ESTABLISHED`.

---

## 2. Qué Corregimos de las Propuestas de la IA

### Corrección 1: Bloqueo silencioso en los Bridges de Linux (`sw-a` y `sw-b`) por Docker `br_netfilter`
- **Qué propuso la IA inicialmente:** Crear los bridges únicamente con `sudo ip link add name sw-a type bridge && sudo ip link set dev sw-a up`. Sin embargo, al desplegar, los pings entre `r2` y los clientes (a través de `sw-a`) y entre `r1` y los servidores (a través de `sw-b`) fallaban al 100%. Asistentes previos incluso sugirieron eliminar `sw-a` y conectar los clientes directo a `r2` sin VLANs, lo cual violaba la pauta del proyecto.
- **Qué corregimos y por qué:** Diagnosticamos que en Linux, cuando Docker está instalado, carga el módulo del kernel `br_netfilter` (`net.bridge.bridge-nf-call-iptables=1`) y fija la política por defecto de la cadena `FORWARD` de `iptables` del host en `DROP`. Esto provocaba que todas las tramas que cruzaban los bridges `sw-a` y `sw-b` fueran descartadas por el firewall del host. Lo corregimos restaurando `sw-a` y las subinterfaces 802.1Q (`eth3.10` y `eth3.20`) como exige la pauta, desactivando `bridge-nf-call-iptables` y `bridge-nf-filter-vlan-tagged` en `desplegar.sh` y agregando reglas `ACCEPT` para `sw-a` y `sw-b`.

### Corrección 2: La ruta por defecto (`0.0.0.0/0`) de OSPF no se instalaba en `r2` ni `r3`
- **Qué propuso la IA inicialmente:** Configurar `default-information originate always` en `r1` sin modificar las tablas de rutas iniciales de `r2` y `r3`.
- **Qué corregimos y por qué:** En Containerlab, Docker asigna a cada contenedor una interfaz de gestión `eth0` (`172.20.20.0/24`) con una ruta por defecto del kernel (`default via 172.20.20.1 dev eth0`) con distancia administrativa `0`. Aunque `r2` y `r3` recibían el LSA Tipo 5 de `r1` por OSPF (distancia administrativa `110`), Zebra no podía sobreescribir la ruta por defecto de `eth0`, por lo que el tráfico hacia `203.0.113.2` (`externo`) salía por la red de gestión de Docker en vez de ir hacia `r1`. Lo corregimos eliminando la ruta por defecto de `eth0` en `r2`, `r3` y `externo` (`ip route del default dev eth0`) en `rutas-estaticas.sh`.

### Corrección 3: Tiempo de convergencia OSPF (40 segundos de elección DR/BDR)
- **Qué propuso la IA inicialmente:** Poner `sleep 5` después de reiniciar FRR con interfaces Ethernet por defecto.
- **Qué corregimos y por qué:** En enlaces Ethernet (tipo `broadcast` por defecto en OSPF), los routers esperan el `Wait Timer` (40 segundos) para elegir DR y BDR antes de pasar del estado `2-Way` a `Full`. Al ejecutar el monitor a los 5 segundos, los vecinos aún no estaban en `Full` ni habían intercambiado rutas. Lo corregimos configurando `ip ospf network point-to-point` y temporizadores `hello-interval 1` / `dead-interval 4` en los enlaces `/30` entre routers (`eth1` y `eth2`), logrando convergencia a `Full` en menos de 2 segundos y reconvergencia ante caída de enlace en 4 segundos.

### Corrección 4: Verificación de Servicios por Socket y valores hardcodeados en `netlab_monitor.py`
- **Qué propuso la IA inicialmente:**
  1. Hardcodear las IPs de las VLANs (`172.16.1.1/27`, `172.16.1.33/28`) y la lista de clientes (`["pc-admin", "pc-ventas"]`) dentro de `netlab_monitor.py`.
  2. Verificar solo `"Full" in out` en OSPF (lo que daba un falso `OK` en `r1` y `r2` cuando se apagaba OSPF en `r3`, ya que `r1` y `r2` seguían siendo vecinos entre sí).
- **Qué corregimos y por qué:**
  1. Reescribimos `check_vlans`, `check_conectividad` y `check_nat` para leer dinámicamente todos los nodos, VLANs, rutas y servicios desde `monitor.json`, cumpliendo el requisito de que agregar una red o servicio no obligue a modificar el código Python.
  2. En `check_ospf`, contamos la cantidad exacta de vecinos en estado `Full` por cada router (`2/2` en topología triangular).
  3. En `check_nat`, agregamos la verificación del contador de paquetes (`pkts > 0`) y la comprobación real en `externo` de que la IP origen vista es `203.0.113.1` (`r1`) y nunca `172.16.1.2` (`pc-admin`).

---

## 3. Qué Rechazamos de las Propuestas de la IA

1. **Rechazo de eliminar `sw-a` y las subinterfaces 802.1Q (`config-vlans.sh`):**
   - Rechazamos la solución parche de conectar `pc-admin` y `pc-ventas` directo a `r2:eth3` y `r2:eth4` sin etiquetas VLAN 802.1Q, porque la pauta exige explícitamente **Router-on-a-Stick en `r2` con subinterfaces 802.1Q para VLAN 10 y VLAN 20 a través del bridge `sw-a`** y verificarlas con `ip -d link`.
2. **Rechazo de usar librerías externas de Python (`paramiko`, `docker`, `requests`, `scapy`):**
   - Rechazamos cualquier dependencia externa porque la sección 3.2 restringe el script exclusivamente a la librería estándar de Python (`subprocess`, `socket`, `os`, `json`, `argparse`, `datetime`).
3. **Rechazo de usar `redistribute connected` indiscriminado en OSPF:**
   - Rechazamos usar `redistribute connected` en todos los routers porque ello anunciaba la red de gestión de Docker (`172.20.20.0/24`) y la red externa (`203.0.113.0/29`) como rutas externas OSPF. En su lugar, anunciamos únicamente las subredes internas en el Área 0 con `network ... area 0` y propagamos hacia el interior la salida a Internet desde `r1` con `default-information originate always`.
