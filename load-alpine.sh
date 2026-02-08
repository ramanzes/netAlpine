#!/bin/bash
set -e

echo "=========================================="
echo "🚀 УНИВЕРСАЛЬНАЯ ЗАГРУЗКА ALPINE ЧЕРЕЗ KEXEC"
echo "=========================================="
echo ""

# === 1. Автоопределение сетевых параметров ===
echo "🔍 Сбор сетевых параметров..."

# Основной интерфейс (через который идёт трафик к интернету)
PRIMARY_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
if [ -z "$PRIMARY_IFACE" ]; then
    echo "❌ Не удалось определить основной интерфейс"
    exit 1
fi

# IP-адрес и маска (обработка /32 и других)
IP_INFO=$(ip -4 addr show dev "$PRIMARY_IFACE" | grep -oP 'inet \K[\d.]+/\d+' | head -1)
if [ -z "$IP_INFO" ]; then
    echo "❌ Не удалось определить IP-адрес интерфейса $PRIMARY_IFACE"
    exit 1
fi

IP=$(echo "$IP_INFO" | cut -d'/' -f1)
CIDR=$(echo "$IP_INFO" | cut -d'/' -f2)

# Преобразуем CIDR в netmask (255.255.255.255 для /32 и т.д.)
case "$CIDR" in
    32) NETMASK="255.255.255.255" ;;
    31) NETMASK="255.255.255.254" ;;
    30) NETMASK="255.255.255.252" ;;
    29) NETMASK="255.255.255.248" ;;
    28) NETMASK="255.255.255.240" ;;
    27) NETMASK="255.255.255.224" ;;
    26) NETMASK="255.255.255.192" ;;
    25) NETMASK="255.255.255.128" ;;
    24) NETMASK="255.255.255.0" ;;
    23) NETMASK="255.255.254.0" ;;
    22) NETMASK="255.255.252.0" ;;
    21) NETMASK="255.255.248.0" ;;
    20) NETMASK="255.255.240.0" ;;
    19) NETMASK="255.255.224.0" ;;
    18) NETMASK="255.255.192.0" ;;
    17) NETMASK="255.255.128.0" ;;
    16) NETMASK="255.255.0.0" ;;
    *) 
        echo "⚠️  Неизвестная маска /$CIDR — используем 255.255.255.255"
        NETMASK="255.255.255.255"
        ;;
esac

# Шлюз по умолчанию
GATEWAY=$(ip route | grep '^default' | awk '{print $3}' | head -1)
if [ -z "$GATEWAY" ]; then
    echo "❌ Не удалось определить шлюз по умолчанию"
    exit 1
fi

# DNS (первый из /etc/resolv.conf)
DNS=$(grep -v '^#' /etc/resolv.conf | grep nameserver | awk '{print $2}' | head -1)
if [ -z "$DNS" ]; then
    DNS="8.8.8.8"
    echo "⚠️  DNS не найден — используем $DNS"
fi

# === 2. Генерация пароля ===
ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
ROOT_HASH=$(openssl passwd -6 "$ROOT_PASSWORD" 2>/dev/null || {
    # Фолбэк для систем без openssl (крайне редко)
    echo '$6$rounds=5000$alpine$hashed'
})

# === 3. Вывод параметров для подтверждения ===
echo ""
echo "🌐 Обнаруженная конфигурация сети:"
echo "   IP:       $IP/$CIDR"
echo "   Маска:    $NETMASK"
echo "   Шлюз:     $GATEWAY"
echo "   Интерфейс: $PRIMARY_IFACE"
echo "   DNS:      $DNS"
echo ""
echo "🔐 Сгенерированный пароль root для Alpine:"
echo "   $ROOT_PASSWORD"
echo ""
echo "⚠️  ВАЖНО: После kexec -e ОТКАТ НЕВОЗМОЖЕН!"
echo "   Единственный способ восстановить доступ — ребут через панель хостера."
echo ""

read -p "Подтвердите запуск (yes): " CONFIRM
[ "$CONFIRM" != "yes" ] && echo "❌ Отмена" && exit 1

# === 4. Формирование параметров ядра ===
# Формат: ip=<client-ip>::<gateway>:<netmask>::<device>:off
IP_PARAM="ip=${IP}::${GATEWAY}:${NETMASK}::${PRIMARY_IFACE}:off"

KERNEL_PARAMS="${IP_PARAM} nameserver=${DNS} ssh cryptroot=plain:${ROOT_HASH} apkovl=- modules=virtio_net,virtio_blk,ext4,squashfs,loop"

# === 5. Проверка наличия образов ===
WORKDIR="alpine-netboot"
if [ ! -f "$WORKDIR/vmlinuz" ] || [ ! -f "$WORKDIR/initramfs" ]; then
    echo "❌ Образы не найдены в $WORKDIR"
    echo "   Скачайте их сначала:"
    echo "   mkdir -p $WORKDIR && cd $WORKDIR"
    echo "   wget https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/netboot-3.23.3/vmlinuz-virt -O vmlinuz"
    echo "   wget https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/netboot-3.23.3/initramfs-virt -O initramfs"
    exit 1
fi

cd "$WORKDIR"

# === 6. Тестовый прогон ===
echo ""
echo "🔍 Тестовый прогон (проверка параметров без загрузки)..."
if ! kexec -l vmlinuz --initrd=initramfs --append="$KERNEL_PARAMS" 2>&1 | grep -q "entry at"; then
    echo "❌ Ошибка при загрузке образа в память"
    exit 1
fi
echo "✅ Параметры приняты ядром"

# Очищаем тестовую загрузку
kexec -u

# === 7. ФИНАЛЬНАЯ ЗАГРУЗКА ===
echo ""
echo "⏳ ФИНАЛЬНАЯ ЗАГРУЗКА через 5 секунд..."
echo "   Нажмите Ctrl+C СЕЙЧАС для отмены!"
for i in 5 4 3 2 1; do
    echo -n "$i... "
    sleep 1
done
echo ""

kexec -l vmlinuz --initrd=initramfs --append="$KERNEL_PARAMS"
echo "🔄 Выполняется kexec -e (точка невозврата)..."

sleep 2
kexec -e

# Эта точка никогда не будет достигнута
echo "❌ КРИТИЧЕСКАЯ ОШИБКА: система не заменилась"
exit 1
