#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="test that ExecStopPost= is always run"

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    create_empty_image_rootdir

    (
        LOG_LEVEL=5
        eval $(udevadm info --export --query=env --name=${LOOPDEV}p2)

        setup_basic_environment

        mask_supporting_services

        # setup policy for Type=dbus test
        mkdir -p $initdir/etc/dbus-1/system.d
        cat > $initdir/etc/dbus-1/system.d/systemd.test.ExecStopPost.conf <<EOF
<?xml version="1.0"?>
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
        "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
    <policy user="root">
        <allow own="systemd.test.ExecStopPost"/>
    </policy>
</busconfig>
EOF

        # setup the testsuite service
        cat >$initdir/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service
Before=getty-pre.target
Wants=getty-pre.target

[Service]
ExecStart=/testsuite.sh
Type=oneshot
EOF
        cp testsuite.sh $initdir/
        cp testsuite.sh /
        cp $initdir/etc/systemd/system/testsuite.service /etc/systemd/system/
        mkdir -p /etc/dbus-1/system.d
        cp $initdir/etc/dbus-1/system.d/systemd.test.ExecStopPost.conf /etc/dbus-1/system.d/

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
    rm -f /etc/dbus-1/system.d/systemd.test.ExecStopPost.conf
    rm -f /etc/systemd/system/testsuite.service
    rm -f /testsuite.sh
    for file in $(ls /testok* /failed* 2>/dev/null); do
      rm $file
    done
    return 0
}

do_test "$@"
