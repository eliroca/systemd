#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="FailureAction= operation"

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    create_empty_image_rootdir

    (
        LOG_LEVEL=5
        eval $(udevadm info --export --query=env --name=${LOOPDEV}p2)

        setup_basic_environment

        # setup the testsuite service
        cat >$initdir/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service

[Service]
ExecStart=/bin/bash -x /testsuite.sh
Type=oneshot
EOF
        cp testsuite.sh $initdir/

        setup_testsuite
    )

    setup_nspawn_root
}

test_run() {
    if [ -z "$TEST_NO_NSPAWN" ]; then
        if run_nspawn "nspawn-root"; then
            check_result_nspawn "nspawn-root" || return 1
        else
            dwarn "can't run systemd-nspawn, skipping"
        fi
    fi
}

test_cleanup() {
    _test_cleanup
    for file in $(ls /testok* /failed* 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
