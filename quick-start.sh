#!/bin/bash

#############################################
# Скрипт быстрого старта
# Для использования на новом сервере
#############################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║       3X-UI Быстрая Установка            ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Проверка Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    echo -e "${YELLOW}Внимание: Скрипт тестировался на Ubuntu${NC}"
    read -p "Продолжить? (y/n): " continue
    if [ "$continue" != "y" ]; then
        exit 0
    fi
fi

echo -e "${GREEN}Шаг 1/4: Основная установка${NC}"
sudo bash install.sh

echo ""
echo -e "${GREEN}Шаг 2/4: Дополнительная настройка${NC}"
read -p "Выполнить дополнительную настройку системы? (y/n): " run_config
if [ "$run_config" = "y" ]; then
    sudo bash configure-system.sh
fi

echo ""
echo -e "${GREEN}Шаг 3/4: Настройка самоподписанного SSL сертификата${NC}"
read -p "Создать самоподписанный SSL сертификат? (y/n): " setup_ssl
if [ "$setup_ssl" = "y" ]; then
    read -p "Введите ваш домен (например, example.com): " domain
    
    # Создание директории для сертификатов
    sudo mkdir -p /etc/x-ui/certs
    
    # Генерация самоподписанного сертификата
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/x-ui/certs/privkey.pem \
        -out /etc/x-ui/certs/fullchain.pem \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=3X-UI/CN=$domain"
    
    sudo chmod 600 /etc/x-ui/certs/privkey.pem
    sudo chmod 644 /etc/x-ui/certs/fullchain.pem
    
    echo -e "${GREEN}Самоподписанный SSL сертификат создан${NC}"
    echo -e "${GREEN}Сертификат: /etc/x-ui/certs/fullchain.pem${NC}"
    echo -e "${GREEN}Ключ: /etc/x-ui/certs/privkey.pem${NC}"
fi

echo ""
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║         Установка завершена! ✓            ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${GREEN}Следующие шаги:${NC}"
echo "1. Откройте панель в браузере"
echo "2. Войдите с логином: admin, паролем: admin"
echo "3. Измените логин и пароль"
echo "4. Настройте конфигурации X-Ray"
echo "5. Создайте пользователей"
echo ""
echo -e "${YELLOW}Полная документация: README.md${NC}"
echo -e "${YELLOW}Настройка конфигураций: config/README.md${NC}"
echo ""
read -p "Перезагрузить систему сейчас? (рекомендуется) (y/n): " reboot_now
if [ "$reboot_now" = "y" ]; then
    sudo reboot
fi
