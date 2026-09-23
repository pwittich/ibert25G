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
# Cornell's Vivado is intentionally not on a non-interactive shell PATH.
# Keep the license/server setup inside the approved project launcher so every
# build uses the same toolchain rather than relying on caller shell state.
if ! command -v vivado >/dev/null 2>&1; then
  source /nfs/opt/Xilinx/Vivado/2023.2/settings64.sh
fi
: "${XILINXD_LICENSE_FILE:=2100@lnxlm.classe.cornell.edu}"
export XILINXD_LICENSE_FILE
# XSim's elaborated kernels can fail before time zero with only an
# "unexpected exception" when inherited from the 4-MiB Codex shell stack.
# Match the normal Cornell interactive environment for every approved Vivado
# and XSim launch.
ulimit -s unlimited
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
