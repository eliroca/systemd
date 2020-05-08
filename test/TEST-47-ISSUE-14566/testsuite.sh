#!/bin/bash
set -ex
set -o pipefail

systemd-analyze log-level debug
systemd-analyze log-target kmsg

systemctl start issue_14566_test
sleep 1
systemctl status issue_14566_test

leaked_pid=$(cat /leakedtestpid)

systemctl stop issue_14566_test
sleep 1

# Leaked PID will still be around if we're buggy.
# I personally prefer to see 42.
ps -p "$leaked_pid" && exit 42

systemd-analyze log-level info

echo SUSEtest OK > /testok

exit 0
