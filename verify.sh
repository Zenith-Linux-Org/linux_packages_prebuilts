#!/bin/bash
# Prebuilts drop verification for Zenith Linux
# Checks each binary in drop/ is musl-compatible or static
set -euo pipefail

DROP_DIR="${1:-packages/prebuilts/drop}"
SYSROOT="${2:-out/target}"
REJECT=0

mkdir -p "$SYSROOT/usr/bin"

if [ ! -d "$DROP_DIR" ] || [ -z "$(ls -A "$DROP_DIR" 2>/dev/null)" ]; then
    echo "prebuilts: no binaries in $DROP_DIR"
    exit 0
fi

for bin in "$DROP_DIR"/*; do
    [ -f "$bin" ] || continue
    name=$(basename "$bin")

    # Check if executable
    if [ ! -x "$bin" ]; then
        echo "prebuilts: $name — not executable, skipping"
        continue
    fi

    # readelf check: reject if NEEDED libs contain glibc
    if command -v readelf &>/dev/null; then
        needed=$(readelf -d "$bin" 2>/dev/null | grep NEEDED | awk '{print $5}')
        if echo "$needed" | grep -q "ld-linux\|libc.so.6\|libpthread\|libdl\|libm.so"; then
            echo "prebuilts: REJECTED — $name linked against glibc"
            REJECT=1
            continue
        fi
    fi

    # Deploy to sysroot
    cp "$bin" "$SYSROOT/usr/bin/$name"
    chmod 0755 "$SYSROOT/usr/bin/$name"
    echo "prebuilts: deployed $name -> $SYSROOT/usr/bin/"
done

if [ "$REJECT" -eq 1 ]; then
    echo "prebuilts: some binaries rejected (glibc linked)"
    exit 1
fi

echo "prebuilts: all binaries OK"
