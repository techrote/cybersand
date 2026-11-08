#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
runtime="$HOME/.cache/cybersand-wb"
godot_cpp="$runtime/godot-cpp"
venv="$runtime/scons"
godot_dir="$runtime/godot"
godot_bin="$godot_dir/Godot_v4.7-stable_linux.x86_64"
mkdir -p "$runtime" "$godot_dir"

# Materialize only the Linux Rapier runtime required by the desktop workbench.
# Explicit git-lfs pull needs no hook installation. Never rewrite an existing
# repo pre-push hook (Codespaces/Actions can provide a guarded hook already).
git lfs version
git lfs pull --include='godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so' --exclude=''
printf '%s  %s\n' \
  '566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a' \
  'godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so' \
  | sha256sum --check --strict

# Existing repository lock supplies the exact SCons wheel hash.
python3 -m venv "$venv"
"$venv/bin/python" -m pip install --disable-pip-version-check \
  --require-hashes -r tools/requirements-build.txt

godot_cpp_commit='101ae38034304346a46ea9ea84ae156d3e860496'
if [[ ! -d "$godot_cpp/.git" ]]; then
  rm -rf "$godot_cpp"
  mkdir -p "$godot_cpp"
  git -C "$godot_cpp" init
  git -C "$godot_cpp" remote add origin https://github.com/godotengine/godot-cpp.git
fi
git -C "$godot_cpp" fetch --depth=1 origin "$godot_cpp_commit"
git -C "$godot_cpp" checkout --detach FETCH_HEAD
test "$(git -C "$godot_cpp" rev-parse HEAD)" = "$godot_cpp_commit"

# Restore the repository's checksum-locked official Godot editor.
if [[ ! -x "$godot_bin" ]]; then
  archive="$runtime/Godot_v4.7-stable_linux.x86_64.zip"
  readarray -t lock < <(python3 - <<'PY'
import json
with open("third_party/godot-runtime.lock.json", encoding="utf-8") as stream:
    editor = json.load(stream)["editor"]
print(editor["origin_url"])
print(editor["size"])
print(editor["sha256"])
PY
)
  curl --fail --location --connect-timeout 45 --max-time 300 \
    --output "$archive" "${lock[0]}"
  test "$(stat -c %s "$archive")" = "${lock[1]}"
  printf '%s  %s\n' "${lock[2]}" "$archive" | sha256sum --check --strict
  unzip -t "$archive" >/dev/null
  unzip -jo "$archive" 'Godot_v4.7-stable_linux.x86_64' -d "$godot_dir"
  chmod 0755 "$godot_bin"
fi
test "$("$godot_bin" --version)" = '4.7.stable.official.5b4e0cb0f'
# Godot's runtime graphics path uses Fontconfig via dynamic loading; a
# headless import alone may succeed even when the display-backed player fails.
# Godot dlopen()s several graphical libraries at display creation.
# ldd and --version alone did not catch the original Fontconfig/Xcursor
# startup failures: check the actual shared-library loading before launch.
python3 - <<'PY'
import ctypes
for library in ("libfontconfig.so.1", "libXcursor.so.1",
                "libXinerama.so.1", "libXi.so.6", "libXrandr.so.2",
                "libXrender.so.1"):
    ctypes.CDLL(library)
print("All required Godot X11 runtime libraries load")
PY
if ldd "$godot_bin" | grep -q 'not found'; then
  echo 'Godot has unresolved runtime shared libraries' >&2
  ldd "$godot_bin" >&2
  exit 1
fi

# Build the native owner from the checked-out CyberSand source through existing
# repository build scripts. They verify GCC 13.3, binutils 2.42 and godot-cpp.
export GODOT_CPP_ROOT="$godot_cpp"
export SCONS_PYTHON="$venv/bin/python"
export SCONS_JOBS="${SCONS_JOBS:-2}"
export CYBERSAND_REAL_CXX=/usr/bin/g++-13
export LINUX_CXX=/usr/bin/g++-13
export CYBERSAND_NATIVE_OUTPUT="$runtime/libcybersand_native.linux.x86_64.so"
tools/build_pinned_godot_cpp.sh linux
tools/build_native_extension.sh
cp "$CYBERSAND_NATIVE_OUTPUT" \
  godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so
tools/check_linux_runtime_floor.sh

# Import only is headless; the actual remote workbench runtime uses Xvfb/OpenGL.
timeout 180 "$godot_bin" --headless --path godot --editor --import --quit
python3 tools/remote_workbench/test_protocol.py
python3 tools/remote_workbench/test_transport.py

cat > "$runtime/runtime.env" <<EOF
export GODOT_BIN='$godot_bin'
export CYBERSAND_WB_RUNTIME='$runtime'
EOF
printf 'CyberSand workbench runtime prepared at %s\n' "$runtime"
