#!/bin/bash
set -e

echo "=========================================="
echo "🏔️  УСТАНОВКА ALPINE ЧЕРЕЗ CHROOT (БЕЗОПАСНО)"
echo "=========================================="
echo ""

# === 1. Проверка требований ===
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Запустите от root"
    exit 1
fi

FREE_DISK=$(df -BM / | awk 'NR==2 {print $4}' | sed 's/M//')
if [ "$FREE_DISK" -lt 500 ]; then
    echo "❌ Недостаточно места на диске: $FREE_DISK МБ (требуется минимум 500 МБ)"
    exit 1
fi

echo "✅ Проверки пройдены: $FREE_DISK МБ свободно"

# === 2. Скачивание minirootfs ===
./getAlpine.sh

# === 3. Распаковка в chroot ===
echo "🔧 Настраиваем окружение chroot..."

# Монтируем критические файловые системы
mount -t proc proc "$WORKDIR/proc" 2>/dev/null || true
mount -t sysfs sys "$WORKDIR/sys" 2>/dev/null || true
mount -o bind /dev "$WORKDIR/dev" 2>/dev/null || true
mount -o bind /dev/pts "$WORKDIR/dev/pts" 2>/dev/null || true
mount -o bind /run "$WORKDIR/run" 2>/dev/null || true

# Копируем сетевые настройки из Debian
cp /etc/resolv.conf "$WORKDIR/etc/" 2>/dev/null || true
cp /etc/hosts "$WORKDIR/etc/" 2>/dev/null || true

# Создаём /etc/network/interfaces для setup-alpine
cat > "$WORKDIR/etc/network/interfaces" << EOF
auto lo
iface lo inet loopback

auto $(ip route get 8.8.8.8 | awk '{print $5; exit}')
iface $(ip route get 8.8.8.8 | awk '{print $5; exit}') inet manual
EOF

# === 4. Подготовка к установке ===
echo ""
echo "🌐 Сетевые параметры (будут использованы при установке):"
ip -4 addr show | grep inet | grep -v 127.0.0.1
ip route | grep default
echo ""

echo "⚠️  ВАЖНО: После входа в chroot выполните:"
echo "   1. setup-alpine"
echo "   2. При вопросе 'Which disk(s) would you like to use?' выберите:"
echo "        /dev/vda (или ваш основной диск) → ответьте 'sys'"
echo "   3. Подтвердите форматирование (все данные будут УДАЛЕНЫ!)"
echo "   4. После установки: exit → reboot"
echo ""
echo "✅ Alpine будет установлена на диск. После перезагрузки сервер загрузится в Alpine."
echo ""

read -p "Начать установку? (yes): " CONFIRM
[ "$CONFIRM" != "yes" ] && echo "❌ Отмена" && exit 1

# === 5. Вход в chroot ===
echo ""
echo "🚪 Вход в chroot-окружение Alpine..."
echo "   Чтобы выйти: наберите 'exit' или нажмите Ctrl+D"
echo ""

# Выполняем chroot с наследованием сетевых настроек
chroot "$WORKDIR" /bin/sh -c "
echo '=========================================='
echo '🏔️  ВЫ В CHROOT ALPINE'
echo '=========================================='
echo ''
echo 'Доступные команды:'
echo '  • setup-alpine    — запустить установщик'
echo '  • apk update      — обновить пакеты'
echo '  • ip a            — проверить сеть'
echo '  • exit            — выйти из chroot'
echo ''
/bin/sh
"

# === 6. Очистка после выхода ===
echo ""
echo "🧹 Очищаем chroot-окружение..."
umount "$WORKDIR/proc" 2>/dev/null || true
umount "$WORKDIR/sys" 2>/dev/null || true
umount "$WORKDIR/dev/pts" 2>/dev/null || true
umount "$WORKDIR/dev" 2>/dev/null || true
umount "$WORKDIR/run" 2>/dev/null || true

echo ""
echo "✅ Chroot завершён. Теперь выполните:"
echo "   reboot"
echo ""
echo "После перезагрузки сервер загрузится в Alpine Linux."
