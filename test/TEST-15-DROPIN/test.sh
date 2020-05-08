#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="Dropin tests"
TEST_NO_QEMU=1

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    # create the basic filesystem layout
    setup_basic_environment
    mask_supporting_services

    # import the test scripts in the rootfs and plug them in systemd
    cp testsuite.service $initdir/etc/systemd/system/
    cp testsuite.service /etc/systemd/system/
    cp test-dropin.sh    $initdir/
    cp test-dropin.sh /
    setup_testsuite

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
    rm -f /etc/systemd/system/testsuite.service
    for file in $(ls /testok* /failed* /test-dropin.sh 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
