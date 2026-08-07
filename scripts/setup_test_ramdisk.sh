#!/usr/bin/env bash
# Creates (if needed) and mounts a 500MB RAM-backed HFS+ volume at
# /private/tmp/WilesTestsRAMDisk. Tests route through testTemporaryDirectory()
# (Tests/WilesTests/TestScratchDirectory.swift), which uses this volume when present instead of
# the real on-disk system temp directory - the whole point being that hundreds of real file
# creates/writes/hashes across the test suite never touch actual disk I/O.
#
# Deliberately mounted OUTSIDE /Volumes/: AppState.navigateTo() treats any /Volumes/-prefixed path
# as a possibly-slow external/network mount and dispatches through Task.detached instead of
# completing synchronously (correct production behavior for real external drives/network shares),
# which breaks tests that assume navigateTo() on a fast local temp path finishes synchronously.
#
# Idempotent: safe to run before every test session.
set -euo pipefail

MOUNT_POINT="/private/tmp/WilesTestsRAMDisk"
SIZE_SECTORS=1024000 # ~500MB (512-byte sectors)

if mount | grep -q " on ${MOUNT_POINT} "; then
  echo "RAM disk already mounted at $MOUNT_POINT"
  exit 0
fi

echo "Creating ${SIZE_SECTORS}-sector RAM disk and mounting at $MOUNT_POINT..."
DEVICE=$(hdiutil attach -nomount "ram://${SIZE_SECTORS}" | tr -d '[:space:]')
newfs_hfs -v "WilesTestsRAMDisk" "$DEVICE" >/dev/null
mkdir -p "$MOUNT_POINT"
mount -t hfs "$DEVICE" "$MOUNT_POINT"
echo "RAM disk mounted at $MOUNT_POINT"
