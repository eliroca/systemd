#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="Basic systemd setup"
RUN_IN_UNPRIVILEGED_CONTAINER=${RUN_IN_UNPRIVILEGED_CONTAINER:-yes}

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    create_empty_image_rootdir

    # Create what will eventually be our root filesystem onto an overlay
    (
        LOG_LEVEL=5
        eval $(udevadm info --export --query=env --name=${LOOPDEV}p2)

        setup_basic_environment

        # setup the testsuite service
        cat >$initdir/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service
After=multi-user.target

[Service]
ExecStart=/bin/sh -e -x -c 'systemctl --state=failed --no-legend --no-pager > /failed ; systemctl daemon-reload ; echo SUSEtest OK > /testok'
Type=oneshot
EOF

        setup_testsuite
        cp $initdir/etc/systemd/system/testsuite.service /etc/systemd/system/testsuite.service
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

        if [[ "$RUN_IN_UNPRIVILEGED_CONTAINER" = "yes" ]]; then
            if NSPAWN_ARGUMENTS="-U --private-network $NSPAWN_ARGUMENTS" run_nspawn "unprivileged-nspawn-root"; then
                check_result_nspawn "unprivileged-nspawn-root" || return 1
            else
                dwarn "can't run systemd-nspawn, skipping"
            fi
        fi
    fi
    ret=1
    test -s /failed && ret=$(($ret+1))
    [[ -e /testok ]] && ret=0
    return $ret
}

test_cleanup() {
    _test_cleanup
    for service in testsuite.service; do
        rm /etc/systemd/system/$service
    done
    for file in $(ls /testok* /failed* 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
