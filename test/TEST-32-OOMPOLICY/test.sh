#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="test OOM killer logic"
TEST_NO_NSPAWN=1

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

UNIFIED_CGROUP_HIERARCHY=yes

test_setup() {
    (
        LOG_LEVEL=5
        mask_supporting_services

        # setup the testsuite service
        cat >/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service

[Service]
ExecStart=/testsuite.sh
Type=oneshot
MemoryAccounting=yes
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
    [[ -e /testok ]] && rm /testok
    [[ -e /failed ]] && rm /failed
    return 0
}

do_test "$@"
