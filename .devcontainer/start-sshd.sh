#!/usr/bin/env bash
# Per-container SSH bootstrap for Codespaces CLI. This script is idempotent:
# a container restart preserves its own host keys, but a rebuilt container
# gets fresh keys. Never load keys from the source tree or an image layer.
set -euo pipefail

expected='1:9.6p1-3ubuntu13.20'
actual="$(dpkg-query -W -f='${Version}' openssh-server)"
if [[ "$actual" != "$expected" ]]; then
  printf 'Unexpected openssh-server version: %s (expected %s)\n' "$actual" "$expected" >&2
  exit 2
fi

if (( EUID == 0 )); then
  root() { "$@"; }
else
  command -v sudo >/dev/null || { echo 'Passwordless sudo is required for SSH startup' >&2; exit 2; }
  root() { sudo -n "$@"; }
fi

# /run is runtime-only; these host private keys live in the current container
# writable filesystem, not in the Docker image or shared repository.
root install -d -m 0755 /run/sshd
root ssh-keygen -A >/dev/null
root test -s /etc/ssh/ssh_host_ed25519_key
root test -s /etc/ssh/ssh_host_ed25519_key.pub
test "$(root stat -c '%u:%a' /etc/ssh/ssh_host_ed25519_key)" = '0:600' || {
  echo 'SSH private host key ownership/mode is not root:600' >&2
  exit 2
}
root /usr/sbin/sshd -t
effective="$(root /usr/sbin/sshd -T)"
for required in 'pubkeyauthentication yes' 'passwordauthentication no' \
                'kbdinteractiveauthentication no' 'permitrootlogin no' \
                'allowtcpforwarding yes'; do
  grep -Fxq "$required" <<< "$effective" || {
    printf 'Unsafe/unexpected sshd setting: %s\n' "$required" >&2
    exit 2
  }
done

# The base image uses SysV's ssh service, without requiring systemd as PID 1.
# Do not restart an already-running sshd or regenerate its existing keys.
if ! root service ssh status >/dev/null 2>&1; then
  root service ssh start >/dev/null
fi
root service ssh status >/dev/null
echo 'CyberSand SSH preflight passed: pinned OpenSSH, container-local host keys, key-only sshd ready'
