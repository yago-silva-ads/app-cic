#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
symbols_dir="${2:-build/symbols}"

if [[ "$platform" != "android" && "$platform" != "ios" ]]; then
  echo "Uso: tool/build_mobile.sh android|ios [diretorio-de-simbolos]" >&2
  exit 2
fi

mkdir -p "$symbols_dir/$platform"

if [[ "$platform" == "android" ]]; then
  flutter build appbundle --release --obfuscate \
    --split-debug-info="$symbols_dir/$platform"
else
  flutter build ipa --release --obfuscate \
    --split-debug-info="$symbols_dir/$platform"
fi
