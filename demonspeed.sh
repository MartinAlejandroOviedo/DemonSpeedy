#!/bin/sh

# ========== CONFIGURACIÓN ==========

DESTINO_PING="8.8.8.8"  # Google DNS, lo más estable
CANTIDAD_PING=10
TMP_BEFORE="/tmp/lat_before.txt"
TMP_AFTER="/tmp/lat_after.txt"

# ========== FUNCIÓN DE LATENCIA ==========

medir_latencia() {
    local archivo=$1
    echo "⏱️  Midiendo latencia hacia $DESTINO_PING..."
    ping -c $CANTIDAD_PING "$DESTINO_PING" | tee "$archivo" | awk -F '/' '/^rtt/ {print $5}' || echo "Error"
}

comparar_latencias() {
    BEFORE=$(awk -F '/' '/^rtt/ {print $5}' "$TMP_BEFORE")
    AFTER=$(awk -F '/' '/^rtt/ {print $5}' "$TMP_AFTER")

    if [ -z "$BEFORE" ] || [ -z "$AFTER" ]; then
        echo "❌ No se pudo calcular diferencia de latencias."
        return
    fi

    echo "📉 Latencia promedio antes: $BEFORE ms"
    echo "📈 Latencia promedio después: $AFTER ms"

    RESULTADO=$(echo "$BEFORE - $AFTER" | bc)
    if [ "$(echo "$RESULTADO > 0" | bc)" -eq 1 ]; then
        echo "✅ Mejora de latencia: -$RESULTADO ms"
    else
        echo "⚠️ No hubo mejora real. Tal vez ya estás optimizado o usás Internet por palomas."
    fi
}

# ========== DETECCIÓN DEL ENTORNO ==========

echo "🚀 Script Inteligente de Aceleración de Latencia TCP/UDP"
echo "🖥️  Host: $(hostname)"
echo "📦 Distro: $(grep -E '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')"
echo "🧠 Kernel: $(uname -r)"
echo "🌐 Interfaz activa: $(ip route | awk '/default/ { print $5 }')"
echo ""

# ========== TEST DE LATENCIA INICIAL ==========

medir_latencia "$TMP_BEFORE"

# ========== APLICAR OPTIMIZACIONES ==========

echo ""
read -p "¿Aplicar ajustes de red ahora? (sí/no): " RESP
[ "$RESP" != "sí" ] && [ "$RESP" != "si" ] && echo "🛑 Cancelado." && exit 0

echo "🔧 Aplicando sysctl..."
sysctl -w net.ipv4.tcp_fastopen=3
sysctl -w net.ipv4.tcp_low_latency=1
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
sysctl -w net.ipv4.tcp_mtu_probing=1

IFACE=$(ip route | awk '/default/ { print $5 }')
if command -v tc >/dev/null; then
    tc qdisc add dev "$IFACE" root handle 1: prio bands 4 2>/dev/null
    tc filter add dev "$IFACE" protocol ip parent 1:0 prio 1 u32 match ip dport 22 0xffff flowid 1:1 2>/dev/null
    tc filter add dev "$IFACE" protocol ip parent 1:0 prio 2 u32 match ip dport 80 0xffff flowid 1:2 2>/dev/null
    echo "🎛️  QoS aplicado sobre $IFACE"
else
    echo "⚠️ No se pudo aplicar QoS. Falta 'tc'"
fi

# ========== TEST DE LATENCIA POST-AJUSTES ==========

echo ""
echo "📡 Esperando 5 segundos antes de volver a medir..."
sleep 5
medir_latencia "$TMP_AFTER"
comparar_latencias

echo ""
echo "📦 Script finalizado. Podés revisar los logs en:"
echo "   ➤ $TMP_BEFORE (antes)"
echo "   ➤ $TMP_AFTER (después)"
