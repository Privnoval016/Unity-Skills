#!/usr/bin/env bash
# Run from Unity project root: bash Unity-Skills/install.sh
set -e
SKILLS_DIR="$(cd "$(dirname "$0")" && pwd)/skills"
TARGET_DIR="$(pwd)/.claude/skills"
mkdir -p "$TARGET_DIR"
linked=0
for d in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$d")
  ln -sfn "$d" "$TARGET_DIR/$skill_name"
  echo "  Linked: $skill_name"
  linked=$((linked + 1))
done
# Agents: one symlink per agent file. Definitions load at session start, so restart Claude Code
# after installing or adding an agent.
AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)/agents"
if [ -d "$AGENTS_DIR" ]; then
  mkdir -p "$(pwd)/.claude/agents"
  for a in "$AGENTS_DIR"/*.md; do
    ln -sfn "$a" "$(pwd)/.claude/agents/$(basename "$a")"
  done
  echo "  Linked: $(ls "$AGENTS_DIR"/*.md | wc -l | tr -d ' ') agents (restart Claude Code to load them)"
fi

echo ""
echo "Done — $linked skills available as /u-* in Claude Code."
echo "If Claude Code is already running, skills activate immediately (no restart needed)."
