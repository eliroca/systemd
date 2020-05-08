#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="Resource limits-related tests"

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

        cat >$initdir/etc/systemd/system.conf <<EOF
[Manager]
DefaultLimitNOFILE=10000:16384
EOF

        # setup the testsuite service
        cat >$initdir/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service

[Service]
ExecStart=/test-rlimits.sh
Type=oneshot
EOF

        cp test-rlimits.sh $initdir/
        cp test-rlimits.sh /
        cp $initdir/etc/systemd/system/testsuite.service /etc/systemd/system/testsuite.service
        mv /etc/systemd/system.conf /etc/systemd/system.conf.orig
        cp $initdir/etc/systemd/system.conf /etc/systemd/

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
    rm -f /etc/systemd/system/testsuite.service
    mv /etc/systemd/system.conf.orig /etc/systemd/system.conf
    for file in $(ls /testok* /failed* /test-rlimits.sh 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
