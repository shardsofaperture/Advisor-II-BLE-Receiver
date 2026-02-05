#!/usr/bin/env zsh
set -euo pipefail

xml="assets/android/tasker/PagerBLE.prj.xml"
doc="docs/android-tasker.md"
vals="assets/android/tasker/known-good-values.txt"

[[ -f "$xml" ]] || { echo "missing $xml"; exit 1; }
[[ -f "$doc" ]] || { echo "missing $doc"; exit 1; }
[[ -f "$vals" ]] || { echo "missing $vals"; exit 1; }

rg -q "20:6E:F1:86:D3:89" "$xml" || { echo "MAC not found in XML"; exit 1; }
rg -q "1b0ee9b4-e833-5a9e-354c-7e2d486b2b7f" "$xml" || { echo "UUID not found in XML"; exit 1; }
rg -q "Known Working Values" "$doc" || { echo "Known Working Values section missing"; exit 1; }

if rg -n "\?\?\?" assets/android/tasker docs/android-tasker.md README.md >/dev/null; then
  echo "Placeholder ??? found"
  exit 1
fi

echo "Tasker asset validation passed"
