#!/usr/bin/env bash
# Run from Unity project root: bash Unity-Skills/install.sh
set -e
SKILLS_DIR="$(cd "$(dirname "$0")" && pwd)/skills"
TARGET_DIR="$(pwd)/.claude/skills"
mkdir -p "$TARGET_DIR"
linked=0
for d in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$d")
  ln -sf "$d" "$TARGET_DIR/$skill_name"
  echo "  Linked: $skill_name"
  linked=$((linked + 1))
done
echo ""
echo "Done — $linked skills available as /u-* in Claude Code."
echo "If Claude Code is already running, skills activate immediately (no restart needed)."
