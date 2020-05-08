#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="EXTEND_TIMEOUT_USEC=usec start/runtime/stop tests"
SKIP_INITRD=yes
TEST_NO_QEMU=1

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    create_empty_image

    # Create what will eventually be our root filesystem onto an overlay
    (
        eval $(udevadm info --export --query=env --name=${LOOPDEV}p2)

        setup_basic_environment
        mask_supporting_services

        for s in success-all success-start success-stop success-runtime \
                 fail-start fail-stop fail-runtime
        do
            cp testsuite-${s}.service ${initdir}/etc/systemd/system
            cp testsuite-${s}.service /etc/systemd/system
        done
        cp testsuite.service ${initdir}/etc/systemd/system
        cp testsuite.service /etc/systemd/system

        cp extend_timeout_test_service.sh ${initdir}/
        cp extend_timeout_test_service.sh /
        cp assess.sh ${initdir}/
        cp assess.sh /

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
    for s in success-all success-start success-stop success-runtime \
             fail-start fail-stop fail-runtime
    do
        rm /etc/systemd/system/testsuite-${s}.service
    done
    rm -f /etc/systemd/system/testsuite.service
    rm -f /extend_timeout_test_service.sh /assess.sh
    for file in $(ls /testok* /failed* 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
