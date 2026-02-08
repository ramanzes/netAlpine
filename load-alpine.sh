#!/bin/bash
set -e

echo "=========================================="
echo "⚠️  ФИНАЛЬНАЯ ЗАГРУЗКА В ALPINE NETBOOT ⚠️"
echo "=========================================="
echo ""
echo "Текущий IP сервера: $(hostname -I | awk '{print $1}')"
echo "Пароль root для Alpine: alpine-test-2026"
echo ""
echo "❗ После выполнения kexec -e:"
echo "   • Текущая SSH-сессия ОБОРВЁТСЯ"
echo "   • Ждите 60-90 секунд"
echo "   • Подключайтесь по тому же IP: ssh root@<IP>"
echo ""
echo "🛡️  Включён failsafe-таймер: перезагрузка в Debian через 5 минут"
echo "   (если Alpine зависнет или не запустит SSH)"
echo ""

# 1. Запускаем таймер перезагрузки (защита от зависания)
echo "Запуск failsafe-таймера (5 минут)..."
shutdown -r +5 "Failsafe: возврат к Debian" &
SHUTDOWN_PID=$!
echo $SHUTDOWN_PID > /tmp/alpine-shutdown.pid
echo "✅ Таймер запущен (PID: $SHUTDOWN_PID)"

# 2. Сохраняем текущий IP для быстрого подключения
CURRENT_IP=$(hostname -I | awk '{print $1}')
echo "$CURRENT_IP" > /tmp/alpine-target-ip.txt

sleep 3

# 3. ФИНАЛЬНАЯ ЗАГРУЗКА (ТОЧКА НЕВОЗВРАТА)
echo ""
echo "⏳ Загрузка Alpine netboot через 5 секунд..."
echo "   Нажмите Ctrl+C СЕЙЧАС, если не готовы!"
sleep 5

cd alpine-netboot
ROOT_PASSWORD="alpine-test-2026"
ROOT_HASH=$(openssl passwd -6 "$ROOT_PASSWORD" 2>/dev/null || echo '$6$Xkf7WOQwwQGnJ1pr$dfpvF/yYXDLlcXdPfjJuSGRHpd/bnWxEWqGEB1Nsz49DiUINR8IpW4LgRJ82cJ9EBD4En84wi1g8qbvvLlY390')

kexec -l vmlinuz \
  --initrd=initramfs \
  --append="ip=dhcp alpine_dev=eth0 ssh cryptroot=plain:${ROOT_HASH} apkovl=-"

echo "Выполняется kexec -e..."
sleep 2
kexec -e

# Эта точка НИКОГДА не будет достигнута — система уже заменена
echo "❌ Ошибка: выполнение продолжилось после kexec -e (должно быть невозможно)"
exit 1
