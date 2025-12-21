#!/bin/bash

#############################################
# Скрипт проверки статуса системы
#############################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Проверка статуса 3X-UI системы       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Функция для проверки статуса
check_service() {
    if systemctl is-active --quiet $1; then
        echo -e "${GREEN}✓${NC} $2: ${GREEN}Работает${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} $2: ${RED}Остановлен${NC}"
        return 1
    fi
}

# Функция для проверки порта
check_port() {
    if netstat -tuln | grep -q ":$1 "; then
        echo -e "${GREEN}✓${NC} Порт $1: ${GREEN}Открыт${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} Порт $1: ${RED}Закрыт${NC}"
        return 1
    fi
}

# Проверка служб
echo -e "${YELLOW}Службы:${NC}"
check_service "x-ui" "3X-UI"
check_service "fail2ban" "Fail2ban"
check_service "ufw" "UFW Firewall"
echo ""

# Проверка портов
echo -e "${YELLOW}Порты:${NC}"
echo -e "${YELLOW}⚠${NC} Проверка портов зависит от вашей конфигурации панели${NC}"
echo ""

# Проверка BBR
echo -e "${YELLOW}Оптимизация:${NC}"
bbr_status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
if [ "$bbr_status" = "bbr" ]; then
    echo -e "${GREEN}✓${NC} TCP BBR: ${GREEN}Включен${NC}"
else
    echo -e "${YELLOW}⚠${NC} TCP BBR: ${YELLOW}$bbr_status${NC}"
fi

fastopen=$(sysctl net.ipv4.tcp_fastopen | awk '{print $3}')
if [ "$fastopen" = "3" ]; then
    echo -e "${GREEN}✓${NC} TCP Fast Open: ${GREEN}Включен${NC}"
else
    echo -e "${YELLOW}⚠${NC} TCP Fast Open: ${YELLOW}$fastopen${NC}"
fi
echo ""

# Использование ресурсов
echo -e "${YELLOW}Ресурсы:${NC}"
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
echo -e "CPU: ${BLUE}$cpu_usage%${NC}"

mem_total=$(free -h | awk '/^Mem:/ {print $2}')
mem_used=$(free -h | awk '/^Mem:/ {print $3}')
mem_percent=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')
echo -e "RAM: ${BLUE}$mem_used / $mem_total (${mem_percent}%)${NC}"

disk_usage=$(df -h / | awk 'NR==2 {print $5}')
disk_used=$(df -h / | awk 'NR==2 {print $3}')
disk_total=$(df -h / | awk 'NR==2 {print $2}')
echo -e "Диск: ${BLUE}$disk_used / $disk_total ($disk_usage)${NC}"
echo ""

# SSL сертификаты
echo -e "${YELLOW}SSL сертификаты:${NC}"
if [ -f "/etc/x-ui/certs/fullchain.pem" ] && [ -f "/etc/x-ui/certs/privkey.pem" ]; then
    echo -e "${GREEN}✓${NC} Самоподписанные SSL сертификаты найдены${NC}"
    cert_info=$(sudo openssl x509 -in /etc/x-ui/certs/fullchain.pem -noout -subject -dates 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "$cert_info" | grep -E "subject=|notAfter="
    fi
else
    echo -e "${YELLOW}⚠${NC} SSL сертификаты не найдены в /etc/x-ui/certs/${NC}"
fi
echo ""

# Последние логи 3X-UI
echo -e "${YELLOW}Последние логи 3X-UI (последние 5 строк):${NC}"
sudo journalctl -u x-ui -n 5 --no-pager
echo ""

# Активные подключения X-Ray
echo -e "${YELLOW}Активные подключения:${NC}"
active_connections=$(ss -tn | grep -E ':(2053|2096|443)' | wc -l)
echo -e "Текущих подключений: ${BLUE}$active_connections${NC}"
echo ""

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Проверка завершена              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
