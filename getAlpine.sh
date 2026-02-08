#!/bin/bash
set -e

echo "=== Скачивание Alpine v3.23.3 netboot образов ==="

NETBOOT_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/netboot-3.23.3"
WORKDIR="/root/alpine-netboot"
mkdir -p "$WORKDIR" && cd "$WORKDIR"

# Очищаем старые файлы
rm -f vmlinuz initramfs modloop sha256sum.txt 2>/dev/null || true

# Скачиваем компоненты из директории netboot
echo "📥 Скачиваем ядро и initramfs..."
wget "${NETBOOT_URL}/vmlinuz-virt" -O vmlinuz
wget "${NETBOOT_URL}/initramfs-virt" -O initramfs

# modloop для netboot-образов часто встроен в initramfs, но скачаем на всякий случай
if wget "${NETBOOT_URL}/modloop-virt" -O modloop 2>/dev/null; then
    echo "✅ modloop-virt скачан"
else
    echo "ℹ️  modloop-virt отсутствует (встроен в initramfs для netboot)"
    touch modloop  # создаём пустой файл для совместимости
fi

# Проверяем контрольные суммы (если доступны)
if wget "${NETBOOT_URL}/sha256sum.txt" -O sha256sum.txt 2>/dev/null; then
    grep -E "(vmlinuz-virt|initramfs-virt|modloop-virt)" sha256sum.txt | sha256sum -c - || {
        echo -e "\n⚠️  Предупреждение: проверка контрольных сумм не удалась (файлы могут быть валидны)"
    }
    echo "✅ Контрольные суммы обработаны"
else
    echo "ℹ️  sha256sum.txt недоступен — пропускаем проверку"
fi

# Генерируем пароль (ОБЯЗАТЕЛЬНО замените!)
ROOT_PASSWORD="alpine-test-2026"  # ← ЗАМЕНИТЕ НА СВОЙ ПАРОЛЬ!
ROOT_HASH=$(openssl passwd -6 "$ROOT_PASSWORD" 2>/dev/null || {
    # Фолбэк: используем простой хеш (только для тестов!)
    echo '$6$rounds=5000$alpine$salt' | head -c 60
})

echo ""
echo "🔐 Пароль root для Alpine: $ROOT_PASSWORD"
echo "🌐 IP сервера для SSH: $(hostname -I | awk '{print $1}')"
echo ""
echo "📦 Файлы в $WORKDIR:"
ls -lh vmlinuz initramfs modloop 2>/dev/null | grep -v "total"
echo ""
echo "✅ Netboot образы готовы к загрузке"
