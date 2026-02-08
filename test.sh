# Формируем параметры ядра для Alpine netboot
KERNEL_PARAMS="ip=dhcp ssh cryptroot=plain:$ROOT_HASH"

echo "Тестовая загрузка (без -e)..."
kexec -l vmlinuz \
  --initrd=initramfs \
  --reuse-cmdline \
  --append="$KERNEL_PARAMS" \
  --debug

if [ $? -eq 0 ]; then
    echo "✅ Тестовый прогон успешен — параметры корректны"
    echo "Параметры ядра: $KERNEL_PARAMS"
else
    echo "❌ Ошибка в параметрах ядра — исправьте перед финальной загрузкой"
    exit 1
fi

# Очищаем тестовую загрузку
kexec -u
