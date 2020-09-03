#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="https://github.com/systemd/systemd/issues/2467"

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    mkdir -p $TESTDIR/root
    initdir=$TESTDIR/root
    STRIP_BINARIES=no

    # Create what will eventually be our root filesystem onto an overlay
    (
        LOG_LEVEL=5

        setup_basic_environment
        dracut_install true rm socat

        # setup the testsuite service
        cat >$initdir/etc/systemd/system/testsuite.service <<'EOF'
[Unit]
Description=Testsuite service

[Service]
Type=oneshot
StandardOutput=kmsg
StandardError=kmsg
ExecStart=/bin/sh -e -x -c 'rm -f /tmp/nonexistent; systemctl start test.socket; printf x > test.file; socat -t20 OPEN:test.file UNIX-CONNECT:/run/test.ctl; >/testok'
ExecStartPost=/bin/sh -x -c 'systemctl status test.socket > /failed; echo SUSEtest OK > /testok'
TimeoutStartSec=10s
EOF

	cat  >$initdir/etc/systemd/system/test.socket <<'EOF'
[Socket]
ListenStream=/run/test.ctl
EOF

	cat > $initdir/etc/systemd/system/test.service <<'EOF'
[Unit]
Requires=test.socket
ConditionPathExistsGlob=/tmp/nonexistent

[Service]
ExecStart=/bin/true
EOF

        setup_testsuite
    )
    setup_nspawn_root

    # copy the units used by this test
    for unit in test.service test.socket testsuite.service; do
        cp $initdir/etc/systemd/system/$unit /etc/systemd/system/
    done

    mask_supporting_services_nspawn
    mask_supporting_services
}

test_run() {
    systemctl daemon-reload
    systemctl start testsuite.service || return 1
    ret=1
    test -s /failed && ret=$(($ret+1))
    [[ -e /testok ]] && ret=0
    return $ret
}

test_cleanup() {
    _test_cleanup
    for unit in test.service test.socket testsuite.service; do
        rm -f /etc/systemd/system/$unit
    done
    for file in $(ls /testok* /failed* /test.file 2>/dev/null); do
        rm -f $file
    done
    return 0
}

do_test "$@"
