#!/bin/bash
set -e

echo "=========================================="
echo "🏔️  УСТАНОВКА ALPINE ЧЕРЕЗ CHROOT (БЕЗОПАСНО)"
echo "=========================================="
echo ""

# === 1. Проверка прав и диска ===
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Запустите от имени root"
    exit 1
fi

FREE_DISK=$(df -BM / | awk 'NR==2 {print $4}' | sed 's/M//')
if [ "$FREE_DISK" -lt 500 ]; then
    echo "❌ Недостаточно места: $FREE_DISK МБ (нужно минимум 500 МБ)"
    exit 1
fi
echo "✅ Свободно на диске: $FREE_DISK МБ"

# === 2. Скачивание minirootfs ===
ROOTFS_DIR="/mnt/alpine-rootfs"

if [ ! -f "$ROOTFS_DIR/bin/sh" ]; then
    echo ""
    echo "📥 Minirootfs не найден — запускаем загрузку..."
    ./getMinirootfs.sh
else
    echo "✅ Minirootfs уже готов в $ROOTFS_DIR"
fi

# === 3. Монтирование системных ФС ===
echo ""
echo "🔧 Монтируем критические файловые системы..."

mount -t proc proc "$ROOTFS_DIR/proc" 2>/dev/null || true
mount -t sysfs sys "$ROOTFS_DIR/sys" 2>/dev/null || true
mount -o bind /dev "$ROOTFS_DIR/dev" 2>/dev/null || true
mount -o bind /dev/pts "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
mount -o bind /run "$ROOTFS_DIR/run" 2>/dev/null || true

# === 4. Сетевые настройки ===
PRIMARY_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
cp /etc/resolv.conf "$ROOTFS_DIR/etc/" 2>/dev/null || true
cp /etc/hosts "$ROOTFS_DIR/etc/" 2>/dev/null || true

cat > "$ROOTFS_DIR/etc/network/interfaces" << EOF
auto lo
iface lo inet loopback

auto $PRIMARY_IFACE
iface $PRIMARY_IFACE inet manual
EOF

# === 5. Информация для пользователя ===
echo ""
echo "🌐 Сетевые параметры:"
ip -4 addr show "$PRIMARY_IFACE" | grep inet | grep -v 127.0.0.1 | head -1
ip route | grep default | head -1
echo ""
echo "⚠️  ВАЖНО: После входа в chroot выполните:"
echo "   1. setup-alpine"
echo "   2. При выборе диска: /dev/vda → 'sys' (полная установка с загрузчиком)"
echo "   3. Подтвердите форматирование (ВСЕ ДАННЫЕ БУДУТ УДАЛЕНЫ!)"
echo "   4. После установки: exit → reboot"
echo ""
read -p "Начать установку? (yes): " CONFIRM
[ "$CONFIRM" != "yes" ] && echo "❌ Отмена" && exit 1

# === 6. Вход в chroot ===
echo ""
echo "🚪 Вход в chroot-окружение Alpine..."
echo "   Команды внутри chroot:"
echo "     • setup-alpine  — запустить установщик"
echo "     • exit          — выйти из chroot"
echo ""

chroot "$ROOTFS_DIR" /bin/sh -c "
echo '=========================================='
echo '🏔️  ВЫ В CHROOT ALPINE (v3.23.3)'
echo '=========================================='
echo ''
echo 'Сетевой интерфейс: $PRIMARY_IFACE'
ip -4 addr show $PRIMARY_IFACE 2>/dev/null | grep inet | grep -v 127.0.0.1 | head -1 || echo '   (настроен через DHCP)'
echo ''
echo 'Запустите установку:'
echo '   # setup-alpine'
echo ''
/bin/sh
"

# === 7. Очистка ===
echo ""
echo "🧹 Очищаем chroot-окружение..."
for mnt in proc sys dev/pts dev run; do
    umount "$ROOTFS_DIR/$mnt" 2>/dev/null || true
done

echo ""
echo "✅ Chroot завершён."
echo ""
echo "Что делать дальше:"
echo "  • Если установка прошла успешно: выполните 'reboot'"
echo "  • Если что-то пошло не так: просто НЕ перезагружайтесь —"
echo "    вы останетесь в Debian и сможете повторить попытку."
echo ""
echo "После перезагрузки сервер загрузится в Alpine Linux."


# 1. Настроить репозиторий вручную
echo "https://dl-cdn.alpinelinux.org/alpine/v3.23/main" > /etc/apk/repositories
echo "https://dl-cdn.alpinelinux.org/alpine/v3.23/community" >> /etc/apk/repositories

# 2. Обновить индексы
echo "apk update"

# 3. Установить базовые пакеты
echo "apk add --no-cache alpine-base"

# 4. Выполнить установку на диск
echo "setup-disk -m sys /dev/vda"


