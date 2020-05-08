#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="test cgroup delegation in the unified hierarchy"
TEST_NO_NSPAWN=1

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    (
        LOG_LEVEL=5
        mask_supporting_services

        # setup the testsuite service
        cat >/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service

[Service]
ExecStart=/bin/bash -x /testsuite.sh
Type=oneshot
EOF
        cp testsuite.sh /
    )

    sed -i '/^[ !·······]*GRUB_CMDLINE_LINUX_DEFAULT.*/s/"$/ systemd.unified_cgroup_hierarchy=yes"/' /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg || return 1
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
    rm -f /etc/systemd/system/testsuite.service
    rm -f /testsuite.sh
    sed -i '/^[ !·······]*GRUB_CMDLINE_LINUX_DEFAULT.*/s/ systemd.unified_cgroup_hierarchy=yes//' /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg
    [[ -e /testok ]] && rm /testok
    [[ -e /failed ]] && rm /failed
    return 0
}

do_test "$@"
