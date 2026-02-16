#!/bin/bash

#############################################
# Скрипт автоматической установки 3X-UI
# для Ubuntu Linux
#############################################

set -e  # Выход при любой ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    log_error "Пожалуйста, запустите скрипт с правами root (sudo)"
    exit 1
fi

log_info "Начало установки и настройки системы для 3X-UI..."

# Создание нового пользователя (опционально)
read -p "Создать нового пользователя для SSH доступа? (y/n): " create_user
if [ "$create_user" = "y" ]; then
    log_info "Создание нового пользователя..."
    while true; do
        read -p "Введите имя нового пользователя: " new_username
        if [ -z "$new_username" ]; then
            log_error "Имя пользователя не может быть пустым!"
            continue
        fi
        if id "$new_username" &>/dev/null; then
            log_warn "Пользователь $new_username уже существует, введите другое имя"
            continue
        fi
        break
    done

    # Генерация случайного пароля
    random_password=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

    # Создание пользователя
    useradd -m -s /bin/bash "$new_username"
    echo "$new_username:$random_password" | chpasswd

    # Добавление в группу sudo
    usermod -aG sudo "$new_username"

    # Сохранение данных пользователя
    echo "Пользователь: $new_username" > /root/3xui-user-credentials.txt
    echo "Пароль: $random_password" >> /root/3xui-user-credentials.txt
    chmod 600 /root/3xui-user-credentials.txt

    log_info "Пользователь $new_username создан и добавлен в группу sudo"
    log_warn "ВАЖНО: Данные для входа сохранены в /root/3xui-user-credentials.txt"
    log_warn "Пользователь: $new_username"
    log_warn "Пароль: $random_password"
else
    log_info "Создание нового пользователя пропущено"
fi

# Обновление системы
log_info "Обновление списка пакетов..."
apt-get update -y

log_info "Обновление установленных пакетов..."
apt-get upgrade -y

log_info "Обновление дистрибутива (dist-upgrade)..."
apt-get dist-upgrade -y

# Установка необходимых пакетов
log_info "Установка необходимых пакетов..."
apt-get install -y \
    curl \
    wget \
    git \
    socat \
    ufw \
    fail2ban \
    unzip \
    tar \
    nano \
    vim \
    htop \
    net-tools \
    openssl \
    cron

# Настройка временной зоны
log_info "Настройка временной зоны..."
timedatectl set-timezone Europe/Moscow || log_warn "Не удалось установить часовой пояс"

# Настройка firewall (UFW)
log_info "Настройка firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

ufw allow 2053/tcp comment 'X-Ray'
ufw allow 2096/tcp comment 'X-Ray'
ufw reload

# Настройка fail2ban для защиты от брутфорса
log_info "Настройка fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Оптимизация системы
read -p "Применить оптимизации системы (BBR, TCP Fast Open, увеличение лимитов)? (y/n): " apply_optimization
if [ "$apply_optimization" = "y" ]; then
    log_info "Применение оптимизаций системы..."
    cat >> /etc/sysctl.conf <<EOF

# Оптимизация для 3X-UI
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
fs.file-max=1000000
EOF

    sysctl -p

    # Увеличение лимитов
    log_info "Увеличение системных лимитов..."
    cat > /etc/security/limits.conf <<EOF
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000
EOF
    log_info "Оптимизации применены успешно"
else
    log_warn "Оптимизации системы пропущены"
fi

# Установка 3X-UI
log_info "Установка 3X-UI панели..."
bash <(cat ./assets/install-3xui-21-12-2025.sh)

# Применение кастомной конфигурации, если она есть
if [ -f "./config/x-ui.db" ]; then
    log_info "Применение кастомной конфигурации..."
    systemctl stop x-ui
    cp ./config/x-ui.db /etc/x-ui/x-ui.db
    systemctl start x-ui
fi

# Очистка
log_info "Очистка временных файлов..."
apt-get autoremove -y
apt-get clean

log_info "═══════════════════════════════════════════════"
log_info "Установка завершена успешно!"
log_info "═══════════════════════════════════════════════"
log_info ""
log_info "3X-UI панель доступна по адресу:"
log_info "http://ваш-ip:порт (порт указан в настройках панели)"
log_info ""
log_info "Стандартные данные для входа в панель:"
log_info "Логин: admin"
log_info "Пароль: admin"
log_info ""
log_warn "ВАЖНО: Измените пароль панели после первого входа!"
log_info ""
if [ -f "/root/3xui-user-credentials.txt" ]; then
    log_info "Данные для входа на сервер (SSH):"
    log_info "Пользователь: $new_username"
    log_info "Пароль: сохранен в /root/3xui-user-credentials.txt"
    log_warn "ВАЖНО: Сохраните эти данные в безопасном месте!"
    log_info ""
fi
log_info "Полезные команды:"
log_info "  x-ui               - Управление панелью"
log_info "  systemctl status x-ui  - Статус службы"
log_info "  ufw status        - Статус firewall"
log_info ""
log_info "Рекомендуется перезагрузить систему:"
log_info "  reboot"
