#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: ./release.sh <version> <message>"
  echo "Example: ./release.sh 0.3.0 \"Institutional CI + release pipeline\""
  exit 1
fi

VER="$1"
MSG="$2"
TAG="v${VER}"

if ! echo "$VER" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "ERROR: version must be MAJOR.MINOR.PATCH (e.g., 0.3.0)"
  exit 1
fi

echo "$VER" > VERSION

# best effort update in pyproject.toml
if [ -f pyproject.toml ]; then
python - <<PY
import re, pathlib
p = pathlib.Path("pyproject.toml")
s = p.read_text(encoding="utf-8")
s2, n = re.subn(r'(?m)^version\\s*=\\s*"[0-9]+\\.[0-9]+\\.[0-9]+"\\s*$', f'version = "{VER}"', s)
if n == 0:
  raise SystemExit("Could not find version line in pyproject.toml")
p.write_text(s2, encoding="utf-8")
PY
fi

# quick repro smoke gate
python scripts/run_full_verification.py --seed 42 >/dev/null
test -f results/seed42_verification.json

git add -A
git commit -m "Release ${TAG}: ${MSG}" || true
git tag -a "${TAG}" -m "${MSG}"

git push origin main
git push origin "${TAG}"

echo "OK: pushed tag ${TAG}. GitHub Actions will build signed release artifacts and SBOMs."
