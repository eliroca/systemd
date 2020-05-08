#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="/etc/machine-id testing"
TEST_NO_NSPAWN=1

export TEST_BASE_DIR=/var/opt/systemd-tests/test
. $TEST_BASE_DIR/test-functions

test_setup() {

    # Create what will eventually be our root filesystem onto an overlay
    (
        LOG_LEVEL=5

        mask_supporting_services
        mv /etc/machine-id /etc/machine-id.orig
        printf "556f48e837bc4424a710fa2e2c9d3e3c\ne3d\n" >/etc/machine-id

        # setup the testsuite service
        cat >/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service

[Service]
ExecStart=/bin/sh -e -x -c '/test-machine-id-setup.sh; systemctl --state=failed --no-legend --no-pager > /failed ; echo SUSEtest OK > /testok'
Type=oneshot
EOF

cat >/test-machine-id-setup.sh <<'EOF'
#!/usr/bin/env bash

set -e
set -x

function setup_root {
    local _root="$1"
    mkdir -p "$_root"
    mount -t tmpfs tmpfs "$_root"
    mkdir -p "$_root/etc" "$_root/run"
}

function check {
    printf "Expected\n"
    cat "$1"
    printf "\nGot\n"
    cat "$2"
    cmp "$1" "$2"
}

r="$(pwd)/overwrite-broken-machine-id"
setup_root "$r"
systemd-machine-id-setup --print --root "$r"
echo abc >>"$r/etc/machine-id"
id=$(systemd-machine-id-setup --print --root "$r")
echo $id >expected
check expected "$r/etc/machine-id"

r="$(pwd)/transient-machine-id"
setup_root "$r"
systemd-machine-id-setup --print --root "$r"
echo abc >>"$r/etc/machine-id"
mount -o remount,ro "$r"
mount -t tmpfs tmpfs "$r/run"
transient_id=$(systemd-machine-id-setup --print --root "$r")
mount -o remount,rw "$r"
commited_id=$(systemd-machine-id-setup --print --commit --root "$r")
[[ "$transient_id" = "$commited_id" ]]
check "$r/etc/machine-id" "$r/run/machine-id"
EOF
chmod +x /test-machine-id-setup.sh
    )
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
    rm -f /test-machine-id-setup.sh
    mv /etc/machine-id.orig /etc/machine-id
    umount /overwrite-broken-machine-id && rm -r /overwrite-broken-machine-id
    umount -R /transient-machine-id && rm -r /transient-machine-id
    rm -f /expected
    [[ -e /testok ]] && rm /testok
    [[ -e /failed ]] && rm /failed
    return 0
}

do_test "$@"
