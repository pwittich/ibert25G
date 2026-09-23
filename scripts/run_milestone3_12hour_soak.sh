#!/bin/sh
set -eu

# Run the Milestone 3 v11 12-hour external-path soak, showing all output on
# screen while retaining the same output in a timestamped log file.

script_dir="$(CDPATH= cd -P "$(dirname "$0")" && pwd)"
soak_script="${script_dir}/milestone3_12hour_external_soak.py"

request_sequence="${1:-4}"
previous_sequence="${2:-3}"
start_stamp="$(date +%Y%m%d_%H%M%S)"
log_file="${3:-${PWD}/milestone3_12hour_soak_${start_stamp}.log}"

status_interval_seconds=1800
status_check_count=24

if [ ! -f "${soak_script}" ]; then
  echo "ERROR: missing ${soak_script}" >&2
  exit 1
fi

mkdir -p "$(dirname "${log_file}")"

# A FIFO keeps output live on screen and in the log without Bash process
# substitution. Preserve the original descriptors so the EXIT trap can close
# the FIFO, wait for tee to flush, and return the actual script status.
log_tmp="$(mktemp -d "${TMPDIR:-/tmp}/m3-soak.XXXXXX")"
log_fifo="${log_tmp}/output"
mkfifo "${log_fifo}"
tee -a "${log_file}" <"${log_fifo}" &
tee_pid=$!
exec 3>&1 4>&2
exec >"${log_fifo}" 2>&1

cleanup()
{
  exit_status=$?
  trap - 0 1 2 15
  exec 1>&3 2>&4
  exec 3>&- 4>&-
  wait "${tee_pid}" || true
  rm -f "${log_fifo}"
  rmdir "${log_tmp}"
  exit "${exit_status}"
}
trap cleanup 0 1 2 15

echo "Milestone 3 v11 12-hour external soak"
echo "Started: $(date --iso-8601=seconds)"
echo "Request sequence: ${request_sequence}"
echo "Previous sequence: ${previous_sequence}"
echo "Status interval: 30 minutes"
echo "Log file: ${log_file}"
echo

python3 "${soak_script}" start \
  --sequence "${request_sequence}" \
  --previous-sequence "${previous_sequence}"

check=1
while [ "${check}" -le "${status_check_count}" ]; do
  echo
  echo "Sleeping 30 minutes before status check ${check}/${status_check_count}."
  sleep "${status_interval_seconds}"
  echo
  echo "Status check ${check}/${status_check_count}: $(date --iso-8601=seconds)"
  python3 "${soak_script}" status --sequence "${request_sequence}"
  check=$((check + 1))
done

echo
echo "Collecting final results: $(date --iso-8601=seconds)"
python3 "${soak_script}" results --sequence "${request_sequence}"

echo
echo "Completed: $(date --iso-8601=seconds)"
echo "Complete log: ${log_file}"
