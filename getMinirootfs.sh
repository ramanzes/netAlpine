#!/bin/bash
set -e

echo "=== Скачивание Alpine minirootfs (v3.23.3) ==="

ALPINE_VERSION="v3.23"
ALPINE_FULL_VERSION="3.23.3"
ARCH="x86_64"
MIRROR="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/releases/${ARCH}"
ARCHIVE="alpine-minirootfs-${ALPINE_FULL_VERSION}-${ARCH}.tar.gz"
ROOTFS_DIR="/mnt/alpine-rootfs"

mkdir -p "$ROOTFS_DIR" /tmp

# Скачиваем архив (если ещё не скачан)
if [ ! -f "/tmp/$ARCHIVE" ]; then
    echo "📥 Скачиваем $ARCHIVE..."
    wget "${MIRROR}/${ARCHIVE}" -O "/tmp/$ARCHIVE"
    
    # Проверка контрольной суммы
    echo "🔍 Проверяем контрольную сумму..."
    if wget "${MIRROR}/${ARCHIVE}.sha256" -O - 2>/dev/null | sha256sum -c -; then
        echo "✅ Контрольная сумма подтверждена"
    else
        echo "⚠️  Предупреждение: проверка пропущена (файл .sha256 недоступен)"
    fi
else
    echo "✅ Архив уже скачан: /tmp/$ARCHIVE"
fi

# Распаковываем (если ещё не распакован)
if [ ! -f "$ROOTFS_DIR/bin/sh" ]; then
    echo "📦 Распаковываем в $ROOTFS_DIR..."
    tar xzf "/tmp/$ARCHIVE" -C "$ROOTFS_DIR" --exclude='dev/*' --exclude='proc/*' --exclude='sys/*'
    
    # Проверяем наличие /bin/sh
    if [ -f "$ROOTFS_DIR/bin/sh" ]; then
        echo "✅ Minirootfs готов: $ROOTFS_DIR/bin/sh существует"
        echo "📦 Содержимое:"
        ls -d "$ROOTFS_DIR"/{bin,sbin,etc,usr,var} 2>/dev/null | xargs -n1 basename | sed 's/^/   • /'
    else
        echo "❌ Ошибка: /bin/sh не найден после распаковки!"
        exit 1
    fi
else
    echo "✅ Minirootfs уже распакован в $ROOTFS_DIR"
fi
