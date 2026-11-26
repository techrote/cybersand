#!/usr/bin/env bash
set -eu
cd /workspace/scratch/1c5fccfbe328/ultima-b
export XDG_DATA_HOME=/workspace/scratch/1c5fccfbe328/b-closure-gui-4b7/profile/data
export XDG_CONFIG_HOME=/workspace/scratch/1c5fccfbe328/b-closure-gui-4b7/profile/config
export XDG_CACHE_HOME=/workspace/scratch/1c5fccfbe328/b-closure-gui-4b7/profile/cache
export CYBERSAND_SOURCE_REVISION=4b7cbcd2a0ac90e3ee5b5abfd14b6b6cba24c8b0
export LIBGL_ALWAYS_SOFTWARE=1
export LP_NUM_THREADS=2
export GALLIVM_PERF=nopt
/workspace/scratch/b5ff5c354306/crash-check/engine/Godot_v4.7-stable_linux.x86_64 --headless --editor --path godot --import --quit > /workspace/scratch/1c5fccfbe328/b-closure-gui-4b7/import.log 2>&1
/workspace/scratch/b5ff5c354306/crash-check/engine/Godot_v4.7-stable_linux.x86_64 --audio-driver Dummy --rendering-method gl_compatibility --path godot --resolution 1366x768 --position 0,0 -- --workbench > /workspace/scratch/1c5fccfbe328/b-closure-gui-4b7/workbench.log 2>&1
