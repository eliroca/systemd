#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="test OnClockChange= + OnTimezoneChange="
TEST_NO_NSPAWN=1

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    (
        LOG_LEVEL=5
        mask_supporting_services

        # extend the watchdog
        mkdir -p /etc/systemd/system/systemd-timedated.service.d
        cat >/etc/systemd/system/systemd-timedated.service.d/watchdog.conf <<EOF
[Service]
WatchdogSec=10min
EOF

        # setup the testsuite service
        cat >/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service

[Service]
ExecStart=/testsuite.sh
Type=oneshot
EOF
        cp testsuite.sh /
    )
}

test_run() {
    ret=1
    systemctl daemon-reload
    systemctl start testsuite.service || return 1
    test -s /failed && ret=$(($ret+1))
    [[ -e /testok ]] && ret=0
    return $ret
}

test_cleanup() {
    _test_cleanup
    rm -f /testsuite.sh
    rm -f /etc/systemd/system/testsuite.service
    rm -rf /etc/systemd/system/systemd-timedated.service.d
    for file in $(ls /testok* /failed* 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
