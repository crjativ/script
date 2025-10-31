#!/bin/bash
 
# =============================================
# SISTEMA DE MONITOREO VPN - RETO INFORMÁTICA
# Versión: 3.0 - Mejorado para competición
# =============================================
 
# Configuración
VPN_CONFIG="${1:-config/vpn-client.ovpn}"
LOG_DIR="logs"
REPORT_DIR="reports"
INTERFACE=""
START_TIME=""
SESSION_ID="RETO-$(date +%Y%m%d-%H%M%S)"
 
# Colores RETO INFORMÁTICA (Verde principal)
GREEN='\033[0;32m'
LIGHT_GREEN='\033[1;32m'
DARK_GREEN='\033[0;92m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
 
# Señal de salida mejorada
trap 'cleanup_exit' INT TERM HUP
 
cleanup_exit() {
    echo -e "\n${YELLOW}🛑 Cerrando sistema...${NC}"
    log_event "Solicitud de cierre recibida via señal"
    generate_session_report
    echo -e "${GREEN}✅ Sistema cerrado correctamente${NC}"
    echo -e "${LIGHT_GREEN}📊 Reporte: $REPORT_DIR/session-$SESSION_ID.html${NC}"
    echo -e "${LIGHT_GREEN}📋 Logs: $LOG_DIR/vpn-monitor.log${NC}"
    exit 0
}
 
# Inicializar directorios
init_directories() {
    mkdir -p $LOG_DIR $REPORT_DIR config backups
    echo "[$SESSION_ID] Inicializando sistema Reto Informática..." >> $LOG_DIR/system.log
}
 
# Función de logging
log_event() {
    local level="INFO"
    if [[ "$1" == "ERROR"* ]]; then
        level="ERROR"
    elif [[ "$1" == "WARN"* ]]; then
        level="WARN"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $1" | tee -a "$LOG_DIR/vpn-monitor.log"
}
 
# Verificar prerrequisitos
verify_prerequisites() {
    log_event "Verificando prerrequisitos para reto..."
    
    if [ ! -f "$VPN_CONFIG" ]; then
        log_event "Creando template de configuración VPN..."
        create_vpn_template
    fi
    
    local critical_tools=("openvpn" "curl" "jq" "ip")
    for tool in "${critical_tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${RED}❌ Error: Herramienta $tool no disponible${NC}"
            exit 1
        fi
    done
    
    log_event "Prerrequisitos verificados correctamente"
}
 
# Crear template de configuración VPN
create_vpn_template() {
    cat > config/vpn-client.ovpn << 'EOF'
# =============================================
# CONFIGURACIÓN VPN - RETO INFORMÁTICA
# =============================================
 
client
dev tun
proto udp
remote your-vpn-server.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
verb 2
 
# INSTRUCCIONES:
# 1. Reemplazar 'your-vpn-server.com' con servidor real
# 2. Configurar autenticación según proveedor
# 3. Agregar certificados si son necesarios
 
EOF
    echo -e "${YELLOW}⚠️  Template creado. Editar config/vpn-client.ovpn con datos reales.${NC}"
}
 
# Obtener información geográfica
get_geo_info() {
    local ip_info=$(curl -s --connect-timeout 5 http://ipinfo.io/json)
    if [ $? -eq 0 ] && [ -n "$ip_info" ]; then
        IP=$(echo "$ip_info" | jq -r .ip 2>/dev/null || echo "N/A")
        COUNTRY=$(echo "$ip_info" | jq -r '.country // "N/A"')
        CITY=$(echo "$ip_info" | jq -r '.city // "N/A"')
        ORG=$(echo "$ip_info" | jq -r '.org // "N/A"')
        TIMEZONE=$(echo "$ip_info" | jq -r '.timezone // "N/A"')
    else
        IP="No disponible"
        COUNTRY="Error conexión"
        CITY="Error conexión"
        ORG="Error conexión"
        TIMEZONE="N/A"
    fi
}
 
# Obtener métricas de red
get_network_metrics() {
    if [ -n "$INTERFACE" ]; then
        local metrics=$(ip -s link show dev "$INTERFACE" 2>/dev/null)
        if [ $? -eq 0 ]; then
            CURRENT_RX=$(echo "$metrics" | awk '/RX:/{rx=$2} END{print rx}')
            CURRENT_TX=$(echo "$metrics" | awk '/TX:/{tx=$2} END{print tx}')
        else
            CURRENT_RX=0
            CURRENT_TX=0
        fi
    else
        CURRENT_RX=0
        CURRENT_TX=0
    fi
}
 
# Formatear duración
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $horas $minutos $segs
}
 
# Formatear bytes
format_bytes() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$((bytes / 1024)) KB"
    else
        echo "$bytes B"
    fi
}
 
# Generar reporte de sesión
generate_session_report() {
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    
    cat > $REPORT_DIR/session-$SESSION_ID.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Reporte Reto Informática - $SESSION_ID</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f0fff0; }
        .header { background: #228B22; color: white; padding: 20px; border-radius: 8px; }
        .metric { background: white; margin: 10px 0; padding: 15px; border-radius: 5px; border-left: 4px solid #228B22; }
        .success { background: #d4edda; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏆 Reporte Reto Informática - Monitoreo VPN</h1>
        <p>ID: $SESSION_ID | Generado: $(date)</p>
    </div>
    
    <div class="metric">
        <h3>⏱️ Resumen de Tiempo</h3>
        <p><strong>Duración total:</strong> $(format_duration $total_duration)</p>
        <p><strong>Inicio:</strong> $(date -d @$START_TIME)</p>
        <p><strong>Fin:</strong> $(date -d @$end_time)</p>
    </div>
    
    <div class="metric">
        <h3>📈 Métricas de Tráfico</h3>
        <p><strong>Datos recibidos:</strong> $(format_bytes $TOTAL_RX)</p>
        <p><strong>Datos enviados:</strong> $(format_bytes $TOTAL_TX)</p>
        <p><strong>Total transferido:</strong> $(format_bytes $((TOTAL_RX + TOTAL_TX)))</p>
    </div>
    
    <div class="metric">
        <h3>🌍 Información de Conexión</h3>
        <p><strong>IP final:</strong> $IP</p>
        <p><strong>Ubicación:</strong> $CITY, $COUNTRY</p>
        <p><strong>Proveedor:</strong> $ORG</p>
    </div>
</body>
</html>
EOF
    
    log_event "Reporte de sesión generado: $REPORT_DIR/session-$SESSION_ID.html"
}
 
# Mostrar dashboard RETO INFORMÁTICA
show_dashboard() {
    clear
    echo -e "${DARK_GREEN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${DARK_GREEN}║                  🏆 RETO INFORMÁTICA - VPN MONITOR                     ║${NC}"
    echo -e "${DARK_GREEN}╠════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${DARK_GREEN}║  Session: $SESSION_ID${NC}"
    echo -e "${DARK_GREEN}║  Status:  $STATUS${NC}"
    echo -e "${DARK_GREEN}║  Interface: ${INTERFACE:-No detectada}${NC}"
    echo -e "${DARK_GREEN}╠════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${DARK_GREEN}║  🌐 CONEXIÓN:${NC}"
    echo -e "${DARK_GREEN}║    IP: $IP${NC}"
    echo -e "${DARK_GREEN}║    País: $COUNTRY | Ciudad: $CITY${NC}"
    echo -e "${DARK_GREEN}║    Proveedor: $(echo $ORG | cut -c1-50)${NC}"
    echo -e "${DARK_GREEN}╠════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${DARK_GREEN}║  ⏱️  TIEMPO: $(format_duration $DURATION)${NC}"
    echo -e "${DARK_GREEN}║  📊 TRÁFICO DESDE INICIO:${NC}"
    echo -e "${DARK_GREEN}║    ⬇️  Recibido: $(format_bytes $TOTAL_RX)${NC}"
    echo -e "${DARK_GREEN}║    ⬆️  Enviado: $(format_bytes $TOTAL_TX)${NC}"
    echo -e "${DARK_GREEN}║    📈 Total: $(format_bytes $((TOTAL_RX + TOTAL_TX)))${NC}"
    echo -e "${DARK_GREEN}╠════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${DARK_GREEN}║  🕐 Actualizado: $(date '+%Y-%m-%d %H:%M:%S') | TZ: $TIMEZONE${NC}"
    echo -e "${DARK_GREEN}║  💡 ${YELLOW}Ctrl+C para SALIR fácilmente${NC} ${DARK_GREEN}| Logs automáticos${NC}"
    echo -e "${DARK_GREEN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
}
 
# Función principal
main() {
    log_event "=== INICIANDO SISTEMA RETO INFORMÁTICA ==="
    log_event "Session ID: $SESSION_ID"
    
    init_directories
    verify_prerequisites
    
    # Mostrar información inicial
    echo -e "${GREEN}🚀 INICIANDO RETO INFORMÁTICA - VPN MONITOR${NC}"
    echo -e "${LIGHT_GREEN}Session: $SESSION_ID${NC}"
    echo -e "${LIGHT_GREEN}Config: $VPN_CONFIG${NC}"
    echo -e "${LIGHT_GREEN}Logs: $LOG_DIR/vpn-monitor.log${NC}"
    echo -e "${YELLOW}💡 Presiona Ctrl+C en cualquier momento para salir${NC}"
    echo
    
    # Inicializar métricas
    START_TIME=$(date +%s)
    
    log_event "Sistema de monitoreo iniciado - Listo para competencia"
    
    # Bucle principal de monitoreo
    while true; do
        CURRENT_TIME=$(date +%s)
        DURATION=$((CURRENT_TIME - START_TIME))
        
        get_network_metrics
        get_geo_info
        
        # Calcular totales
        TOTAL_RX=$CURRENT_RX
        TOTAL_TX=$CURRENT_TX
        
        if [ "$IP" != "No disponible" ] && [ "$IP" != "N/A" ]; then
            STATUS="${GREEN}CONECTADO ✅${NC}"
        else
            STATUS="${YELLOW}SIN CONEXIÓN ⚠️${NC}"
        fi
        
        show_dashboard
        sleep 5
    done
}
 
# Ejecutar sistema
main "$@"
