#!/bin/bash
set -e

echo "=== Проверка требований ==="

# Минимум 512 МБ свободной RAM для Alpine netboot
FREE_RAM=$(free -m | awk '/^Mem:/ {print $7}')
if [ "$FREE_RAM" -lt 512 ]; then
    echo "❌ Недостаточно свободной RAM: $FREE_RAM МБ (требуется минимум 512 МБ)"
    exit 1
fi
echo "✅ Свободная RAM: $FREE_RAM МБ"

# Проверка поддержки kexec в ядре
if ! grep -q CONFIG_KEXEC /boot/config-$(uname -r) 2>/dev/null; then
    echo "❌ Ядро не поддерживает kexec (CONFIG_KEXEC отсутствует)"
    exit 1
fi
echo "✅ Ядро поддерживает kexec"

# Проверка сетевого интерфейса (должен быть один основной)
PRIMARY_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
if [ -z "$PRIMARY_IFACE" ]; then
    echo "❌ Не удалось определить основной сетевой интерфейс"
    exit 1
fi
echo "✅ Основной интерфейс: $PRIMARY_IFACE"

# Сохраняем текущий IP для подключения к Alpine
CURRENT_IP=$(hostname -I | awk '{print $1}')
echo "✅ Текущий IP сервера: $CURRENT_IP"

# Проверка доступности порта 22 (чтобы убедиться, что SSH работает)
if ! ss -tulpn | grep -q ':22 '; then
    echo "❌ SSH-сервер не слушает порт 22"
    exit 1
fi
echo "✅ SSH-сервер активен"

echo -e "\n⚠️  ВНИМАНИЕ: После выполнения 'kexec -e' откат невозможен!"
echo "⚠️  Убедитесь, что вы готовы потерять этот VPS в случае ошибки."
read -p "Продолжить? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Отмена операции."
    exit 0
fi



# Установка необходимых пакетов
apt update && apt install -y kexec-tools curl wget gnupg

# Отключаем автоматические обновления во время операции
systemctl stop unattended-upgrades 2>/dev/null || true
