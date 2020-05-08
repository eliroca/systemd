#!/bin/bash
set -e
TEST_DESCRIPTION="Test that KillMode=mixed does not leave left over proccesses with ExecStopPost="

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    create_empty_image_rootdir

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
ExecStart=/testsuite.sh
Type=oneshot
EOF
        cat > $initdir/etc/systemd/system/issue_14566_test.service << EOF
[Unit]
Description=Issue 14566 Repro

[Service]
ExecStart=/repro.sh
ExecStopPost=/bin/true
KillMode=mixed
EOF

        cp testsuite.sh $initdir/
        cp repro.sh $initdir/
        cp testsuite.sh /
        cp repro.sh /
        cp $initdir/etc/systemd/system/testsuite.service /etc/systemd/system/
        cp $initdir/etc/systemd/system/issue_14566_test.service /etc/systemd/system/

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
    rm -f /etc/systemd/system/issue_14566_test.service
    rm -f /etc/systemd/system/testsuite.service
    rm -f /testsuite.sh /repro.sh /leakedtestpid
    for file in $(ls /testok* /failed* 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
