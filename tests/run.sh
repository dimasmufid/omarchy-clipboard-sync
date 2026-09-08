#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"

omarchy plugin validate .
python3 -m py_compile scripts/clipboard-sync-adapter tests/test_adapter.py
python3 -m unittest -v tests/test_adapter.py

if command -v qmllint >/dev/null 2>&1; then
  qmllint ClipboardSync.qml ClipboardSyncService.qml
else
  printf '%s\n' 'qmllint not installed; live Omarchy shell validation is required.'
fi
