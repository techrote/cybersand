#!/usr/bin/env bash
set -euo pipefail
target="${1:?linux or windows}"
[[ "$target" == linux || "$target" == windows ]]
test "$(git rev-parse HEAD)" = "$TARGET_SOURCE"
python3 -m venv "$RUNNER_TEMP/swarm45-scons"
"$RUNNER_TEMP/swarm45-scons/bin/python" -m pip install --require-hashes -r tools/requirements-build.txt
git init "$RUNNER_TEMP/swarm45-godot-cpp"
git -C "$RUNNER_TEMP/swarm45-godot-cpp" remote add origin https://github.com/godotengine/godot-cpp.git
timeout 600 git -C "$RUNNER_TEMP/swarm45-godot-cpp" fetch --depth=1 origin "$GODOT_CPP_COMMIT"
git -C "$RUNNER_TEMP/swarm45-godot-cpp" checkout --detach FETCH_HEAD
test "$(git -C "$RUNNER_TEMP/swarm45-godot-cpp" rev-parse HEAD)" = "$GODOT_CPP_COMMIT"
{
  echo "GODOT_CPP_ROOT=$RUNNER_TEMP/swarm45-godot-cpp"
  echo "SCONS_PYTHON=$RUNNER_TEMP/swarm45-scons/bin/python"
  echo 'SCONS_JOBS=2'
} >> "$GITHUB_ENV"
if [[ "$target" == linux ]]; then
  {
    echo 'CYBERSAND_REAL_CXX=/usr/bin/g++-13'
    echo 'LINUX_CXX=/usr/bin/g++-13'
  } >> "$GITHUB_ENV"
fi
if [[ "$target" == windows ]]; then
  timeout 900 curl -fL --retry 3 -o "$RUNNER_TEMP/swarm45-llvm-mingw.tar.xz" "$LLVM_MINGW_URL"
  echo "$LLVM_MINGW_SHA256  $RUNNER_TEMP/swarm45-llvm-mingw.tar.xz" | sha256sum -c --strict
  mkdir -p "$RUNNER_TEMP/swarm45-llvm-mingw"
  tar -xJf "$RUNNER_TEMP/swarm45-llvm-mingw.tar.xz" -C "$RUNNER_TEMP/swarm45-llvm-mingw" --strip-components=1
  if test ! -e "$RUNNER_TEMP/swarm45-llvm-mingw/bin/x86_64-w64-mingw32-gcc-ar"; then
    ln -s llvm-ar "$RUNNER_TEMP/swarm45-llvm-mingw/bin/x86_64-w64-mingw32-gcc-ar"
  fi
  {
    echo "LLVM_MINGW_ROOT=$RUNNER_TEMP/swarm45-llvm-mingw"
    echo "WINDOWS_CXX=$RUNNER_TEMP/swarm45-llvm-mingw/bin/x86_64-w64-mingw32-g++"
  } >> "$GITHUB_ENV"
fi
