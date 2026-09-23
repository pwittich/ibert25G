#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "usage: $0 TCL_SCRIPT [TCL_ARG ...]"
  exit 0
fi

flow_script=$1
shift
if [[ ! -f "$flow_script" ]]; then
  echo "error: Tcl script not found: $flow_script" >&2
  exit 2
fi
if ! command -v vivado >/dev/null 2>&1; then
  echo "error: vivado is not on PATH" >&2
  exit 127
fi

mkdir -p build/logs
flow_name=$(basename "$flow_script" .tcl)
stamp=$(date -u +%Y%m%dT%H%M%SZ)
log_base="build/logs/${flow_name}-${stamp}"

echo "Vivado flow: $flow_script"
echo "Log: ${log_base}.log"
exec vivado -mode batch -notrace \
  -journal "${log_base}.jou" \
  -log "${log_base}.log" \
  -source "$flow_script" -tclargs "$@"
