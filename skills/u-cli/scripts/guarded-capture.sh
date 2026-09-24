#!/usr/bin/env bash
# Guarded Play Mode capture. Enters Play Mode, optionally runs a setup command, waits, captures the
# composited screen (Screen Space - Overlay UI included) to a PNG, and ALWAYS exits Play Mode.
#
# Usage: guarded-capture.sh <out.png> [wait_seconds] [setup command...]
#   e.g. guarded-capture.sh Temp/combat.png 6 coc_combat_start
#
# Guards (any one aborts and stops Play Mode):
#   - compile failure before starting
#   - frameCount not advancing between two checks (throttled or hung Editor)
#   - console error count rising above (snapshot + ALLOWED_NEW_ERRORS); the default of 1 tolerates a
#     standing error that some plugins log on every scene change
#   - a modal dialog blocking the Editor (commands time out)
# Optional env PRECAPTURE_WAIT: seconds to wait after PRECAPTURE_EVAL (default 0.5); raise it when the
# eval opens screens that animate in.
# Optional env PRECAPTURE_EVAL: C# for `eval`, run just before the capture (e.g. hide canvases to get
# a clean plate). Play Mode only, so nothing it changes persists.
# Needs OS focus: set_autotick does NOT advance the Play Mode player loop; editor_focus does. This
# script calls editor_focus, which takes focus away from the user's terminal.
set -u
export PATH="$HOME/.unity/bin:$PATH"
OUT="${1:?output png path (project-relative)}"; WAIT="${2:-5}"; shift 2 2>/dev/null || shift $#
SETUP=("$@")
ALLOWED_NEW_ERRORS="${ALLOWED_NEW_ERRORS:-1}"
res(){ python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)["data"]["result"]; d=json.loads(d) if isinstance(d,str) and d[:1] in "{[" else d
  print(json.dumps(d) if not isinstance(d,str) else d)
except Exception: print("")'; }
q(){ unity command "$@" --timeout 20 --format json 2>/dev/null | res; }
field(){ python3 -c "import json,sys; d=json.loads(sys.stdin.read() or '{}'); print(eval(sys.argv[1]))" "$1" 2>/dev/null; }
ev(){ unity command eval --code "$1" --timeout 20 --format json 2>/dev/null | res | python3 -c 'import json,sys
t=sys.stdin.read().strip()
try: d=json.loads(t); print(d.get("result","") if isinstance(d,dict) else d)
except Exception: print(t)'; }
stop(){ unity command editor_stop --timeout 20 >/dev/null 2>&1; echo "[capture] play mode stopped"; }
abort(){ echo "[capture] ABORT: $*"; stop; exit 1; }

st=$(q console_status); [ -z "$st" ] && { echo "[capture] ABORT: Editor unresponsive (modal dialog open?)"; exit 1; }
[ "$(echo "$st" | field "d['groundTruth']['compilationFailed']")" = "True" ] && { echo "[capture] ABORT: compile errors"; exit 1; }
base=$(echo "$st" | field "d['groundTruth']['consoleErrors']")
q editor_focus >/dev/null
q editor_play >/dev/null
for i in $(seq 1 30); do pm=$(q editor_status | field "d.get('playMode')"); [ "$pm" = "playing" ] && break; sleep 1; done
[ "$pm" = "playing" ] || abort "did not enter play mode"
sleep 1
if [ ${#SETUP[@]} -gt 0 ]; then echo "[capture] setup: ${SETUP[*]}"; q "${SETUP[@]}" >/dev/null; fi
f1=$(ev 'return UnityEngine.Time.frameCount;')
sleep "$WAIT"
f2=$(ev 'return UnityEngine.Time.frameCount;')
[ -n "$f1" ] && [ -n "$f2" ] && [ "$f2" -gt "$f1" ] || abort "frames not advancing ($f1 -> $f2)"
now=$(q console_status | field "d['groundTruth']['consoleErrors']")
[ -n "$now" ] && [ "$now" -le $((base + ALLOWED_NEW_ERRORS)) ] || abort "errors rose $base -> $now"
if [ -n "${PRECAPTURE_EVAL:-}" ]; then q eval --code "$PRECAPTURE_EVAL" >/dev/null; sleep "${PRECAPTURE_WAIT:-0.5}"; fi
q eval --code "UnityEngine.ScreenCapture.CaptureScreenshot(\"$OUT\"); return 0;" >/dev/null
sleep 2
stop
[ -f "$OUT" ] && echo "[capture] saved $OUT (frames $f1 -> $f2, errors $base -> $now)" || { echo "[capture] FAILED: no file"; exit 1; }
