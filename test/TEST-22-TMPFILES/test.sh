#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="Tmpfiles related tests"
TEST_NO_QEMU=1

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    LOG_LEVEL=5

    # create the basic filesystem layout
    setup_basic_environment
    mask_supporting_services
    inst_binary mv
    inst_binary stat
    inst_binary seq
    inst_binary xargs
    inst_binary mkfifo
    inst_binary readlink

    # setup the testsuite service
    cp testsuite.service $initdir/etc/systemd/system/
    cp testsuite.service /etc/systemd/system/
    setup_testsuite

    mkdir -p $initdir/testsuite
    cp run-tmpfiles-tests.sh $initdir/testsuite/
    cp test-*.sh $initdir/testsuite/

    mkdir -p /testsuite
    cp run-tmpfiles-tests.sh /testsuite/
    cp test-*.sh /testsuite/

    # create dedicated rootfs for nspawn (located in $TESTDIR/nspawn-root)
    setup_nspawn_root
}

test_run() {
    systemctl daemon-reload
    systemctl start testsuite.service || return 1
    if [ -z "$TEST_NO_NSPAWN" ]; then
        if run_nspawn "nspawn-root"; then
            check_result_nspawn "nspawn-root" || return 1
        else
            dwarn "can't run systemd-nspawn, skipping"
        fi
    fi
    ret=1
    test -s /failed && ret=$(($ret+1))
    [[ -e /testok ]] && ret=0
    return $ret
}

test_cleanup() {
    _test_cleanup
    rm -rf /testsuite
    rm -f /etc/systemd/system/testsuite.service
    for file in $(ls /testok* /failed* 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
