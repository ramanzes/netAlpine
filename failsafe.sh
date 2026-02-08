#!/bin/bash
# /root/alpine-failsafe.sh

echo "=== Настройка защиты от зависания ==="

# Запускаем перезагрузку через 5 минут (выполнится даже если система частично зависла)
shutdown -r +5 "Failsafe: возврат к Debian через 5 минут" &

# Сохраняем PID для возможной отмены (если успеем подключиться к Alpine)
SHUTDOWN_PID=$!
echo $SHUTDOWN_PID > /tmp/alpine-shutdown.pid

echo "✅ Перезагрузка запланирована на $(date -d '+5 minutes')"
echo "⚠️  Чтобы отменить: после подключения к Alpine выполните 'shutdown -c' на СТАРОЙ системе"
echo "    (но это маловероятно — после kexec процессы Debian умрут)"
sleep 3
