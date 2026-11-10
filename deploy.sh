#!/usr/bin/env bash
# This script does not copy the addon anywhere.
# The old macOS rsync --delete into World of Warcraft/_anniversary_ was removed
# because it can delete other addons and it targets the wrong client.
set -euo pipefail

echo "journal-addon-forever does not install itself."
echo "The anniversary rsync --delete path is not used."
echo "Copy the JournalingAddon folder by hand, without deleting other addons."
echo "Steps and the in-game checklist: docs/FOREVER.md"
exit 1
