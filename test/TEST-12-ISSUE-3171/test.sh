#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="https://github.com/systemd/systemd/issues/3171"
TEST_NO_QEMU=1

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
        mask_supporting_services_nspawn
        dracut_install cat mv stat nc

        # setup the testsuite service
        cat >$initdir/etc/systemd/system/testsuite.service <<EOF
[Unit]
Description=Testsuite service
After=multi-user.target

[Service]
ExecStart=/test-socket-group.sh
Type=oneshot
EOF

        cat >$initdir/test-socket-group.sh <<'EOF'
#!/usr/bin/env bash
set -x
set -e
set -o pipefail

U=/run/systemd/system/test.socket
cat <<'EOL' >$U
[Unit]
Description=Test socket
[Socket]
Accept=yes
ListenStream=/run/test.socket
SocketGroup=adm
SocketMode=0660
EOL

cat <<'EOL' > /run/systemd/system/test@.service
[Unit]
Description=Test service
[Service]
StandardInput=socket
ExecStart=/bin/sh -x -c cat
EOL

systemctl start test.socket
systemctl is-active test.socket
[[ "$(stat --format='%G' /run/test.socket)" == adm ]]
echo A | nc -w1 -U /run/test.socket

mv $U ${U}.disabled
systemctl daemon-reload
systemctl is-active test.socket
[[ "$(stat --format='%G' /run/test.socket)" == adm ]]
echo B | nc -w1 -U /run/test.socket && exit 1

mv ${U}.disabled $U
systemctl daemon-reload
systemctl is-active test.socket
echo C | nc -w1 -U /run/test.socket && exit 1
[[ "$(stat --format='%G' /run/test.socket)" == adm ]]

systemctl restart test.socket
systemctl is-active test.socket
echo D | nc -w1 -U /run/test.socket
[[ "$(stat --format='%G' /run/test.socket)" == adm ]]


echo SUSEtest OK > /testok
EOF

        chmod 0755 $initdir/test-socket-group.sh

        # copy the units used by this test
        cp $initdir/test-socket-group.sh /
        cp $initdir/etc/systemd/system/testsuite.service /etc/systemd/system/

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
    rm -f /run/systemd/system/test.socket
    rm -f /run/systemd/system/test@.service
    rm -f /run/test.socket
    for file in $(ls /testok* /failed* /test-socket-group.sh 2>/dev/null); do
        rm -f $file
    done
    return 0
}

do_test "$@"
