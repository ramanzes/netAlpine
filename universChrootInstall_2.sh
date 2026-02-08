#!/bin/bash
set -e

echo "=========================================="
echo "🏔️  УСТАНОВКА ALPINE ЧЕРЕЗ CHROOT + setup-disk"
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

# === 2. Скачивание minirootfs (если ещё не скачан) ===
ROOTFS_DIR="/mnt/alpine-rootfs"
ARCHIVE="/tmp/alpine-minirootfs-3.23.3-x86_64.tar.gz"

if [ ! -f "$ROOTFS_DIR/bin/sh" ]; then
    echo ""
    echo "📥 Minirootfs не найден — скачиваем..."
    
    # Скачиваем архив
    if [ ! -f "$ARCHIVE" ]; then
        wget "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.3-x86_64.tar.gz" -O "$ARCHIVE"
    fi
    
    # Распаковываем
    mkdir -p "$ROOTFS_DIR"
    tar xzf "$ARCHIVE" -C "$ROOTFS_DIR" --exclude='dev/*' --exclude='proc/*' --exclude='sys/*'
    
    echo "✅ Minirootfs распакован в $ROOTFS_DIR"
fi

# === 3. Подготовка chroot-окружения ===
echo ""
echo "🔧 Подготавливаем chroot-окружение..."

# Монтируем системные ФС
for fs in proc sys dev dev/pts run; do
    mountpoint -q "$ROOTFS_DIR/$fs" 2>/dev/null || {
        case "$fs" in
            proc) mount -t proc proc "$ROOTFS_DIR/$fs" ;;
            sys)  mount -t sysfs sys "$ROOTFS_DIR/$fs" ;;
            dev)  mount -o bind /dev "$ROOTFS_DIR/$fs" ;;
            *)    mount -o bind "/$fs" "$ROOTFS_DIR/$fs" ;;
        esac
    }
done

# Сетевые настройки
cp /etc/resolv.conf "$ROOTFS_DIR/etc/" 2>/dev/null || echo "nameserver 1.1.1.1" > "$ROOTFS_DIR/etc/resolv.conf"
cp /etc/hosts "$ROOTFS_DIR/etc/" 2>/dev/null || true

# Добавляем репозиторий Alpine
cat > "$ROOTFS_DIR/etc/apk/repositories" << EOF
https://dl-cdn.alpinelinux.org/alpine/v3.23/main
https://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

# === 4. Автоустановка alpine-base внутри chroot ===
echo ""
echo "📦 Устанавливаем alpine-base внутри chroot..."
chroot "$ROOTFS_DIR" /bin/sh -c "
apk update >/dev/null 2>&1
apk add --no-cache alpine-base >/dev/null 2>&1
echo '✅ alpine-base установлен'
"

# === 5. Информация для пользователя ===
PRIMARY_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
ROOT_DISK="/dev/vda"

echo ""
echo "🌐 Сетевые параметры:"
ip -4 addr show "$PRIMARY_IFACE" | grep inet | grep -v 127.0.0.1 | head -1
ip route | grep default | head -1
echo ""
echo "💾 Основной диск для установки: $ROOT_DISK"
echo ""
echo "⚠️  ВАЖНО: Выберите ОДИН из двух вариантов установки:"
echo ""
echo "Вариант А (рекомендуется): Автоматическая установка"
echo "  # setup-disk -m sys $ROOT_DISK"
echo "  → Полная установка с загрузчиком на весь диск"
echo "  → Все данные на $ROOT_DISK будут УДАЛЕНЫ!"
echo ""
echo "Вариант Б: Ручная установка (для опытных)"
echo "  # fdisk $ROOT_DISK          → разметить диск"
echo "  # mkfs.ext4 /dev/vda1       → создать ФС"
echo "  # setup-disk /mnt            → установить систему"
echo ""
echo "После установки:"
echo "  # exit"
echo "  # reboot"
echo ""

read -p "Начать установку? (yes): " CONFIRM
[ "$CONFIRM" != "yes" ] && echo "❌ Отмена" && exit 1

# === 6. Вход в chroot ===
echo ""
echo "🚪 Вход в chroot-окружение Alpine..."
echo ""

chroot "$ROOTFS_DIR" /bin/sh -c "
echo '=========================================='
echo '🏔️  ВЫ В CHROOT ALPINE (v3.23.3)'
echo '=========================================='
echo ''
echo 'Сетевой интерфейс: $PRIMARY_IFACE'
ip -4 addr show $PRIMARY_IFACE 2>/dev/null | grep inet | grep -v 127.0.0.1 | head -1 || echo '   inet (настроен через сеть хоста)'
echo ''
echo 'Доступные команды:'
echo '  • setup-disk -m sys /dev/vda    → автоматическая установка'
echo '  • apk update && apk add пакет   → установка пакетов'
echo '  • exit                          → выход из chroot'
echo ''
echo 'РЕКОМЕНДУЕТСЯ: выполните установку одной командой:'
echo '  # setup-disk -m sys /dev/vda'
echo ''
/bin/sh
"

# === 7. Очистка ===
echo ""
echo "🧹 Очищаем chroot-окружение..."
for mnt in dev/pts dev run sys proc; do
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
