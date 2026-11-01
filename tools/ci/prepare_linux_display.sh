#!/usr/bin/env bash
# Avoid mirror acquisition when the hosted image already has the display stack.
# The caller retains its generous whole-step watchdog; network stalls are bounded.
set -euo pipefail
packages=(xvfb xauth libgl1-mesa-dri mesa-utils)
missing=()
for package in "${packages[@]}"; do
  if [[ "$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)" != installed ]]; then
    missing+=("$package")
  fi
done
if (( ${#missing[@]} == 0 )); then
  echo 'Display packages already installed; no package-mirror request needed.'
  exit 0
fi
options=(-o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30)
sudo apt-get "${options[@]}" -o APT::Update::Error-Mode=any update
sudo apt-get "${options[@]}" install --no-install-recommends --yes "${missing[@]}"
