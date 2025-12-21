#!/bin/bash

#############################################
# Дополнительная настройка системы
#############################################

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo "Запустите с правами root (sudo)"
    exit 1
fi

# Отключение IPv6 (опционально, если не используется)
read -p "Отключить IPv6? (y/n): " disable_ipv6
if [ "$disable_ipv6" = "y" ]; then
    log_info "Отключение IPv6..."
    cat >> /etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p
fi

# Настройка swap (если мало RAM)
read -p "Создать swap файл 2GB? (y/n): " create_swap
if [ "$create_swap" = "y" ]; then
    if [ ! -f /swapfile ]; then
        log_info "Создание swap файла..."
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        log_info "Swap файл создан и активирован"
    else
        log_warn "Swap файл уже существует"
    fi
fi

# Настройка автоматических обновлений безопасности
read -p "Настроить автоматические обновления безопасности? (y/n): " auto_updates
if [ "$auto_updates" = "y" ]; then
    log_info "Настройка автоматических обновлений..."
    apt-get install -y unattended-upgrades
    dpkg-reconfigure -plow unattended-upgrades
fi

# Настройка SSH (повышение безопасности)
read -p "Настроить SSH для повышения безопасности? (y/n): " config_ssh
if [ "$config_ssh" = "y" ]; then
    log_info "Настройка SSH..."
    
    # Бэкап оригинального конфига
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Полное отключение входа для root
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' /etc/ssh/sshd_config
    
    # Отключение пустых паролей
    sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    sed -i 's/PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    
    # Перезапуск SSH
    systemctl restart sshd
    log_warn "ВАЖНО: Вход для root полностью отключен! Используйте созданного пользователя для SSH доступа."
fi

# Установка дополнительных инструментов мониторинга
read -p "Установить дополнительные инструменты мониторинга? (y/n): " install_monitoring
if [ "$install_monitoring" = "y" ]; then
    log_info "Установка инструментов мониторинга..."
    apt-get install -y \
        iftop \
        iotop \
        nethogs \
        nload \
        speedtest-cli \
        glances
fi

# Очистка истории и логов
read -p "Очистить системные логи и историю? (y/n): " clean_logs
if [ "$clean_logs" = "y" ]; then
    log_info "Очистка логов..."
    journalctl --vacuum-time=7d
    > /var/log/syslog
    > /var/log/kern.log
    history -c
fi

log_info "Дополнительная настройка системы завершена!"
