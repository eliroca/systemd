#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="https://github.com/systemd/systemd/issues/2730"
TEST_NO_NSPAWN=1

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {
    (
        LOG_LEVEL=5

        # setup the testsuite service
        cat >/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service

[Service]
ExecStart=/bin/sh -x -c 'mount -o remount,rw /dev/vda2 && echo SUSEtest OK > /testok'
ExecStartPost=/bin/sh -x -c 'systemctl --state=failed --no-pager > /failed'
Type=oneshot
EOF

    mv /etc/fstab /etc-fstab
    cat >/etc/systemd/system/-.mount <<EOF
[Unit]
Before=local-fs.target

[Mount]
What=/dev/vda2
Where=/
Type=ext4
Options=errors=remount-ro,noatime

[Install]
WantedBy=local-fs.target
Alias=root.mount
EOF

    cat >/etc/systemd/system/systemd-remount-fs.service <<EOF
[Unit]
DefaultDependencies=no
Conflicts=shutdown.target
After=systemd-fsck-root.service
Before=local-fs-pre.target local-fs.target shutdown.target
Wants=local-fs-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/systemctl reload /
EOF

    )

    ln -s /etc/systemd/system/-.mount /etc/systemd/system/root.mount
    mkdir -p /etc/systemd/system/local-fs.target.wants
    ln -s /etc/systemd/system/-.mount /etc/systemd/system/local-fs.target.wants/-.mount
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
    for unit in root.mount -.mount systemd-remount-fs.service testsuite.service; do
        rm -f /etc/systemd/system/$unit
    done
    rm -rf /etc/systemd/system/local-fs.target.wants
    [[ -e /etc-fstab ]] && mv /etc-fstab /etc/fstab
    [[ -e /testok ]] && rm /testok
    [[ -e /failed ]] && rm /failed
    return 0
}

do_test "$@"
