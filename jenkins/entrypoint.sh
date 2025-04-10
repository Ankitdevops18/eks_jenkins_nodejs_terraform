#!/bin/bash

set -e

echo "[INFO] Starting buildkitd..."
export XDG_RUNTIME_DIR=/tmp/runtime
mkdir -p $XDG_RUNTIME_DIR

# Start buildkitd in background
nohup buildkitd > /tmp/buildkitd.log 2>&1 & disown

# Wait a bit to make sure buildkitd is ready
sleep 2

# Optional: show versions
nerdctl --version
buildctl --version