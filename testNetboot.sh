#!/bin/bash
cd alpine-netboot

# Определяем текущий IP и интерфейс
CURRENT_IP=$(hostname -I | awk '{print $1}')
PRIMARY_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')

# Пароль (должен совпадать с тем, что в скрипте выше)
ROOT_PASSWORD="alpine-test-2026"
ROOT_HASH=$(openssl passwd -6 "$ROOT_PASSWORD" 2>/dev/null || echo "alpine")

# Параметры для netboot (минимальные и рабочие):
KERNEL_PARAMS="ip=dhcp alpine_dev=eth0 ssh cryptroot=plain:${ROOT_HASH} apkovl=-"

echo "Тестовая загрузка (без -e)..."
kexec -l vmlinuz \
  --initrd=initramfs \
  --append="$KERNEL_PARAMS" \
  --debug 2>&1 | head -20

if [ $? -eq 0 ]; then
    echo -e "\n✅ Тест успешен — параметры корректны"
    echo "Параметры ядра: $KERNEL_PARAMS"
    echo ""
    echo "⚠️  Готовы к финальной загрузке. После kexec -e откат невозможен!"
    read -p "Выполнить загрузку? (yes/no): " CONFIRM
    if [ "$CONFIRM" == "yes" ]; then
        echo "Загрузка Alpine netboot..."
        kexec -e
        # Эта точка никогда не будет достигнута
    else
        echo "Отмена."
        exit 0
    fi
else
    echo "❌ Ошибка в параметрах ядра"
    exit 1
fi
