#!/bin/bash
cd /root/alpine-netboot

echo "=== ФИНАЛЬНАЯ ЗАГРУЗКА В ALPINE ==="
echo "⚠️  Через 10 секунд будет выполнена kexec -e"
echo "⚠️  Нажмите Ctrl+C СЕЙЧАС, если не готовы!"
sleep 10

# Запускаем failsafe-таймер
/root/alpine-failsafe.sh

# Загружаем Alpine в память
echo "Загрузка Alpine netboot..."
kexec -l vmlinuz \
  --initrd=initramfs \
  --reuse-cmdline \
  --append="ip=dhcp ssh cryptroot=plain:$ROOT_HASH"

# ТОЧКА НЕВОЗВРАТА
echo "Выполняется kexec -e... Система будет заменена!"
sleep 3
kexec -e

# Эта точка никогда не будет достигнута — система уже заменена
