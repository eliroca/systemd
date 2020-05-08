#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="cryptsetup systemd setup"
TEST_NO_NSPAWN=1

export TEST_BASE_DIR="/var/opt/systemd-tests/test/"
. $TEST_BASE_DIR/test-functions

test_setup() {
    mkdir -p $TESTDIR/root
    initdir=$TESTDIR/root
    STRIP_BINARIES=no

    sfdisk --force "/dev/vdb" <<EOF
,2000M
,
EOF

    echo -n test >$TESTDIR/keyfile
    cryptsetup -q luksFormat /dev/vdb1 $TESTDIR/keyfile
    cryptsetup luksOpen /dev/vdb1 varcrypt <$TESTDIR/keyfile
    mkfs.ext3 -L var /dev/mapper/varcrypt
    sed -i 's/ \/var / \/mnt /' /etc/fstab

    (
        LOG_LEVEL=5
        eval $(udevadm info --export --query=env --name=/dev/mapper/varcrypt)
        eval $(udevadm info --export --query=env --name=/dev/vdb1)

        # setup the testsuite service
        cat >/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service
After=multi-user.target

[Service]
ExecStart=/bin/sh -e -x -c 'systemctl --state=failed --no-pager > /failed ; systemctl daemon-reload ; echo SUSEtest OK > /testok'
ExecStartPost=/bin/sh -x -c "cat /proc/mounts | /usr/bin/sed -n '/ \/var /p' >> /testok"
Type=oneshot
EOF

        cat >/etc/crypttab <<EOF
$DM_NAME UUID=$ID_FS_UUID /etc/varkey
EOF
        echo -n test > /etc/varkey
        cat /etc/crypttab | ddebug

        cat >>/etc/fstab <<EOF
/dev/mapper/varcrypt    /var    ext4    defaults 0 1
EOF
    )

    mount /dev/mapper/varcrypt /mnt
    cp -avr /var/* /mnt
    umount /mnt
    cryptsetup luksClose /dev/mapper/varcrypt

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
    sed -i '/varcrypt/d' /etc/fstab
    sed -i 's/ \/mnt / \/var /' /etc/fstab

    rm /etc/systemd/system/testsuite.service
    [[ -e /testok ]] && rm /testok
    [[ -e /failed ]] && rm /failed

    rm -rf /mnt/tmp/systemd-test.*
    rm -f /etc/varkey
    rm -f /etc/crypttab
    dd if=/dev/zero of=/dev/vdb count=100
    return 0
}

do_test "$@"
