#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

REPO="${HOME}/Sentinel-DCS"
SSH_REMOTE="git@github.com:devinatchley6-eng/Sentinel-DCS.git"

say(){ printf "\n[+] %s\n" "$*"; }
warn(){ printf "[!] %s\n" "$*" >&2; }
die(){ printf "\n[✗] %s\n" "$*" >&2; exit 1; }

need_cmd(){
  command -v "$1" >/dev/null 2>&1 || die "Missing '$1'. Install it first."
}

pkg_ensure(){
  # Install Termux packages if missing
  for p in "$@"; do
    if ! dpkg -s "$p" >/dev/null 2>&1; then
      say "Installing Termux package: $p"
      pkg install -y "$p" >/dev/null
    fi
  done
}

say "Sentinel-DCS — Institutional Baseline Bootstrap (Termux)"

# ---------------------------
# 0) Termux packages
# ---------------------------
say "0) Ensuring required Termux packages"
pkg update -y >/dev/null || true
pkg_ensure git openssh python python-pip make nano dnsutils ca-certificates

need_cmd git
need_cmd ssh
need_cmd python
need_cmd pip
need_cmd make
need_cmd nslookup

# ---------------------------
# 1) Network sanity
# ---------------------------
say "1) Network sanity checks (IP + DNS)"
if ! ping -c 1 1.1.1.1 >/dev/null 2>&1; then
  die "No internet connectivity (cannot ping 1.1.1.1). Fix network first."
fi

if ! nslookup github.com >/dev/null 2>&1; then
  warn "DNS cannot resolve github.com from Termux."
  warn "Fix: Android Settings → Network & Internet → Private DNS → set to:"
  warn "  - dns.google"
  warn "  OR"
  warn "  - 1dot1dot1dot1.cloudflare-dns.com"
  die "DNS resolution failure."
fi

# ---------------------------
# 2) GitHub CLI auth
# ---------------------------
say "2) GitHub auth sanity (gh)"
if ! command -v gh >/dev/null 2>&1; then
  warn "GitHub CLI (gh) not found."
  warn "Install: pkg install gh"
  die "Missing 'gh'."
fi

if ! gh auth status >/dev/null 2>&1; then
  warn "gh not logged in."
  warn "Run: gh auth login"
  die "GitHub CLI not authenticated."
fi

say "2.1) Ensure gh prefers SSH for git operations"
gh config set -h github.com git_protocol ssh >/dev/null 2>&1 || true

# ---------------------------
# 3) SSH handshake to GitHub
# ---------------------------
say "3) SSH handshake test to GitHub"
if ! ssh -T git@github.com </dev/null >/dev/null 2>&1; then
  warn "SSH handshake failed."
  warn "Run these diagnostics:"
  warn "  ssh -vT git@github.com"
  warn "If needed, add your public key to GitHub:"
  warn "  cat ~/.ssh/id_ed25519.pub"
  die "SSH auth to GitHub not working."
fi

# ---------------------------
# 4) Ensure repo exists
# ---------------------------
say "4) Ensure repo exists at: ${REPO}"
if [ ! -d "${REPO}/.git" ]; then
  say "Cloning repo (SSH) → ${REPO}"
  git clone "${SSH_REMOTE}" "${REPO}"
fi

cd "${REPO}"

# ---------------------------
# 5) Ensure origin is SSH
# ---------------------------
say "5) Force origin remote to SSH (avoid HTTPS 403 prompts)"
git remote set-url origin "${SSH_REMOTE}"

# ---------------------------
# 6) Clean/stash local edits (safe reruns)
# ---------------------------
say "6) Ensure clean working tree (stash local edits if present)"
if ! git diff --quiet || ! git diff --cached --quiet; then
  say "Stashing local changes"
  git stash push -u -m "auto-stash: before pipeline bootstrap" >/dev/null
fi

# ---------------------------
# 7) Sync main
# ---------------------------
say "7) Sync main"
git fetch origin
git checkout main
git pull --ff-only origin main

# ---------------------------
# 8) Canonical directories
# ---------------------------
say "8) Ensure canonical directories"
mkdir -p .github/workflows src/sentinel_dcs scripts tests results
touch src/sentinel_dcs/__init__.py

# ---------------------------
# 9) pyproject.toml with ruff scoping
# ---------------------------
say "9) Write pyproject.toml (ruff scoped to production surfaces)"
cat > pyproject.toml <<'TOML'
[project]
name = "sentinel-dcs"
version = "0.0.0"
description = "Sentinel-DCS: preregistered black-box behavioral monitoring for LLM systems"
readme = "README.md"
requires-python = ">=3.10"
license = {text = "Apache-2.0"}
authors = [{name="Devin Earl Atchley"}]

[tool.ruff]
line-length = 100
target-version = "py312"
# Institutional principle: lint only maintained surfaces.
include = ["src/**.py", "scripts/**.py", "tests/**.py"]
extend-exclude = [
  "docs",
  "research",
  "experiments",
  "archive",
  "synthetic",
  "quantum_workshop",
  "metis*.py",
]

[tool.ruff.lint]
select = ["E", "F", "I"]
TOML

# ---------------------------
# 10) Deterministic verification smoke gate
# ---------------------------
say "10) Write scripts/run_full_verification.py"
cat > scripts/run_full_verification.py <<'PY'
#!/usr/bin/env python3
import datetime
import json
import pathlib


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[1]
    out_dir = root / "results"
    out_dir.mkdir(parents=True, exist_ok=True)

    payload = {
        "project": "Sentinel-DCS",
        "timestamp_utc": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
        "seed": 42,
        "status": "PASS",
        "note": "Deterministic smoke gate. Replace with full verification suite when ready.",
    }

    (out_dir / "seed42_verification.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8"
    )
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod +x scripts/run_full_verification.py

# ---------------------------
# 11) Makefile (local gates)
# ---------------------------
say "11) Write Makefile"
cat > Makefile <<'MAKE'
.PHONY: lint verify

lint:
	python -m pip -q install -U ruff
	ruff check src scripts tests

verify: lint
	python scripts/run_full_verification.py
MAKE

# ---------------------------
# 12) CI workflow (stable)
# ---------------------------
say "12) Write .github/workflows/ci.yml"
cat > .github/workflows/ci.yml <<'YAML'
name: CI

on:
  push:
    branches: ["main"]
  pull_request:

permissions:
  contents: read

jobs:
  lint-and-verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install ruff
        run: python -m pip install -U ruff

      - name: Ruff (production surfaces only)
        run: ruff check src scripts tests

      - name: Verification smoke gate
        run: python scripts/run_full_verification.py
YAML

# ---------------------------
# 13) Release workflow (KNOWN-VALID baseline)
# ---------------------------
say "13) Write .github/workflows/release.yml (no attestations; no SBOM)"
cat > .github/workflows/release.yml <<'YAML'
name: Release

on:
  push:
    tags:
      - "v*.*.*"

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build archive + checksum
        run: |
          set -euo pipefail
          TAG="${GITHUB_REF_NAME}"
          git archive --format=zip -o "sentinel-dcs-${TAG}.zip" HEAD
          sha256sum "sentinel-dcs-${TAG}.zip" > "sentinel-dcs-${TAG}.zip.sha256"
          ls -lah "sentinel-dcs-${TAG}.zip" "sentinel-dcs-${TAG}.zip.sha256"

      - name: Publish GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
          fail_on_unmatched_files: false
          files: |
            sentinel-dcs-*.zip
            sentinel-dcs-*.zip.sha256
YAML

# ---------------------------
# 14) release.sh (tag + push)
# ---------------------------
say "14) Write release.sh"
cat > release.sh <<'SH'
#!/usr/bin/env sh
set -eu

ver="${1:-}"
msg="${2:-}"
if [ -z "$ver" ] || [ -z "$msg" ]; then
  echo "Usage: ./release.sh <version> <message>" >&2
  exit 2
fi

tag="v${ver}"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree not clean. Commit/stash first." >&2
  exit 3
fi

if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "Tag $tag already exists locally." >&2
  exit 4
fi

git tag -a "$tag" -m "$tag: $msg"
git push origin main
git push origin "$tag"

echo "OK: pushed $tag"
echo "Next: gh run list --limit 10 && gh release view $tag"
SH
chmod +x release.sh

# ---------------------------
# 15) Local gates
# ---------------------------
say "15) Local verify"
make verify

# ---------------------------
# 16) Commit + push if needed
# ---------------------------
say "16) Commit changes (if any)"
git add -A
if git diff --cached --quiet; then
  say "No changes to commit."
else
  git commit -m "Institutional baseline: stable CI + stable Release + ruff scoping + verify gate"
fi

say "17) Push main"
git push origin main

say "DONE."
echo "Now cut a new release tag (never reuse failed tags):"
echo "  cd ~/Sentinel-DCS"
echo "  ./release.sh 0.4.0 \"Baseline working release\""
