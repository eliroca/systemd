#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="Journal-related tests"

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    create_empty_image_rootdir

    # Create what will eventually be our root filesystem onto an overlay
    (
        LOG_LEVEL=5
        eval $(udevadm info --export --query=env --name=${LOOPDEV}p2)

        setup_basic_environment
        mask_supporting_services

        # setup the testsuite service
        cat >$initdir/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service

[Service]
ExecStart=/test-journal.sh
Type=oneshot
EOF

        cat >$initdir/etc/systemd/system/forever-print-hola.service <<EOF
[Unit]
Description=ForeverPrintHola service

[Service]
Type=simple
ExecStart=/bin/sh -x -c 'while :; do printf "Hola\n" || touch /i-lose-my-logs; sleep 1; done'
EOF
        # copy the units used by this test
        cp test-journal.sh $initdir/
        cp test-journal.sh /
        for service in forever-print-hola.service testsuite.service; do
            cp $initdir/etc/systemd/system/$service /etc/systemd/system/
        done

        setup_testsuite
    )
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
    for service in forever-print-hola.service testsuite.service; do
        rm /etc/systemd/system/$service
    done
    for file in $(ls /testok* /failed* /test-journal.sh 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
