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

# Sanity: semantic version
if ! echo "$VER" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "ERROR: version must be semantic MAJOR.MINOR.PATCH (e.g., 0.3.0)"
  exit 1
fi

echo "[+] Updating VERSION"
echo "$VER" > VERSION

echo "[+] Updating pyproject.toml version (if present)"
if [ -f pyproject.toml ]; then
python - <<PY
import re, pathlib
ver = "${VER}"
p = pathlib.Path("pyproject.toml")
s = p.read_text(encoding="utf-8")
s2, n = re.subn(
    r'(?m)^version\\s*=\\s*"[0-9]+\\.[0-9]+\\.[0-9]+"\\s*$',
    f'version = "{ver}"',
    s
)
if n == 0:
    raise SystemExit("Could not find version line in pyproject.toml")
p.write_text(s2, encoding="utf-8")
PY
fi

echo "[+] Local repro smoke gate"
python scripts/run_full_verification.py --seed 42 >/dev/null
test -f results/seed42_verification.json

echo "[+] Commit release bump"
git add VERSION results/seed42_verification.json 2>/dev/null || true
[ -f pyproject.toml ] && git add pyproject.toml || true
git add -A

git commit -m "Release ${TAG}: ${MSG}" || echo "[i] Nothing to commit (continuing)"

echo "[+] Create annotated tag ${TAG}"
# Avoid failing if tag exists
if git rev-parse "${TAG}" >/dev/null 2>&1; then
  echo "[!] Tag ${TAG} already exists locally. Delete it first if you intended a re-tag:"
  echo "    git tag -d ${TAG} && git push origin :refs/tags/${TAG}"
  exit 1
fi
git tag -a "${TAG}" -m "${MSG}"

echo "[+] Push main + tag"
git push origin main
git push origin "${TAG}"

echo
echo "OK: pushed ${TAG}."
echo "Next: GitHub Actions will run the Release workflow on the tag and attach SBOM/signatures/provenance to the GitHub Release."
echo "Zenodo should auto-archive the GitHub Release and mint a new version DOI."
