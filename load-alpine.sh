#!/bin/bash
set -e

echo "=========================================="
echo "🚀 УНИВЕРСАЛЬНАЯ ЗАГРУЗКА ALPINE ЧЕРЕЗ KEXEC"
echo "=========================================="
echo ""

# === 1. Автоопределение сетевых параметров ===
echo "🔍 Сбор сетевых параметров..."

PRIMARY_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}' || echo "ens3")
if [ -z "$PRIMARY_IFACE" ]; then
    echo "❌ Не удалось определить основной интерфейс"
    exit 1
fi

IP_INFO=$(ip -4 addr show dev "$PRIMARY_IFACE" | grep -oP 'inet \K[\d.]+/\d+' | head -1)
if [ -z "$IP_INFO" ]; then
    echo "❌ Не удалось определить IP-адрес интерфейса $PRIMARY_IFACE"
    exit 1
fi

IP=$(echo "$IP_INFO" | cut -d'/' -f1)
CIDR=$(echo "$IP_INFO" | cut -d'/' -f2)

# CIDR → netmask
NETMASK="255.255.255.255"
if [ "$CIDR" -lt 32 ]; then
    # Расчёт маски для не-/32 сетей (редко на VPS)
    NETMASK=$(printf "%d.%d.%d.%d" \
        $((256 - 2**(8 - CIDR/8 % 8))) \
        $((256 - 2**(8 - (CIDR-8)/8 % 8))) \
        $((256 - 2**(8 - (CIDR-16)/8 % 8))) \
        $((256 - 2**(8 - (CIDR-24)/8 % 8))) 2>/dev/null || echo "255.255.255.0")
fi

GATEWAY=$(ip route | grep '^default' | awk '{print $3}' | head -1)
if [ -z "$GATEWAY" ]; then
    echo "❌ Не удалось определить шлюз по умолчанию"
    exit 1
fi

DNS=$(grep -v '^#' /etc/resolv.conf | grep nameserver | awk '{print $2}' | head -1 || echo "8.8.8.8")

# === 2. Генерация пароля ===
ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
ROOT_HASH=$(openssl passwd -6 "$ROOT_PASSWORD" 2>/dev/null || echo '$6$rounds=5000$alpine$hashed')

# === 3. Вывод параметров ===
echo ""
echo "🌐 Обнаруженная конфигурация сети:"
echo "   IP:       $IP/$CIDR"
echo "   Маска:    $NETMASK"
echo "   Шлюз:     $GATEWAY"
echo "   Интерфейс: $PRIMARY_IFACE"
echo "   DNS:      $DNS"
echo ""
echo "🔐 Пароль root для Alpine: $ROOT_PASSWORD"
echo ""

# === 4. Проверка образов ===
WORKDIR="alpine-netboot"
if [ ! -f "$WORKDIR/vmlinuz" ] || [ ! -f "$WORKDIR/initramfs" ]; then
    echo "❌ Образы не найдены в $WORKDIR"
    echo "   Скачайте их:"
    echo "   mkdir -p $WORKDIR && cd $WORKDIR"
    echo "   wget https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/netboot-3.23.3/vmlinuz-virt -O vmlinuz"
    echo "   wget https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/netboot-3.23.3/initramfs-virt -O initramfs"
    exit 1
fi

echo "📦 Образы найдены:"
ls -lh "$WORKDIR"/vmlinuz "$WORKDIR"/initramfs 2>/dev/null | awk '{print "   " $9 ": " $5}'

# === 5. КРИТИЧЕСКИ ВАЖНО: Формат параметра для /32 + onlink ===
# Для сетей /32 с шлюзом в другой подсети ИСПОЛЬЗУЕМ СПЕЦИАЛЬНЫЙ ФОРМАТ:
#   ip=<IP>::<шлюз>::<интерфейс>:on
# Обратите внимание: МАСКА ОПУЩЕНА (пустое поле после шлюза), и ":on" в конце

if [ "$CIDR" = "32" ]; then
    echo "💡 Сеть /32 обнаружена — используем специальный формат для onlink шлюза"
    IP_PARAM="ip=${IP}::${GATEWAY}::${PRIMARY_IFACE}:on"
else
    IP_PARAM="ip=${IP}::${GATEWAY}:${NETMASK}::${PRIMARY_IFACE}:off"
fi

KERNEL_PARAMS="${IP_PARAM} nameserver=${DNS} ssh cryptroot=plain:${ROOT_HASH} apkovl=- modules=virtio_net,virtio_blk,ext4,squashfs,loop"

echo ""
echo "⚙️  Параметры ядра:"
echo "   $KERNEL_PARAMS"
echo ""

read -p "Подтвердите запуск (yes): " CONFIRM
[ "$CONFIRM" != "yes" ] && echo "❌ Отмена" && exit 1

cd "$WORKDIR"

# === 6. ТЕСТОВЫЙ ПРОГОН С ОТЛАДКОЙ ===
echo ""
echo "🔍 Тестовый прогон с отладкой..."
echo "   Выполняется: kexec -l vmlinuz --initrd=initramfs --append=\"$KERNEL_PARAMS\""
echo ""

# Запускаем с выводом ошибок
if ! kexec_output=$(kexec -l vmlinuz --initrd=initramfs --append="$KERNEL_PARAMS" 2>&1); then
    echo "❌ kexec завершился с ошибкой:"
    echo "$kexec_output"
    echo ""
    echo "🔍 Возможные причины:"
    echo "   • Неправильный формат параметра ip= (особенно для /32)"
    echo "   • Отсутствует модуль ядра (попробуйте добавить 'modules=...')"
    echo "   • Повреждённые образы vmlinuz/initramfs"
    exit 1
fi

echo "✅ Тестовый прогон успешен — параметры приняты ядром"
echo "$kexec_output" | head -3

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

echo "❌ Невозможное состояние — система должна была замениться"
exit 1
