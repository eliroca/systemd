#!/usr/bin/env bash
set -e
TEST_DESCRIPTION="https://github.com/systemd/systemd/issues/3166"
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
ExecStart=/test-fail-on-restart.sh
ExecStartPost=/bin/sh -x -c 'systemctl status fail-on-restart.service > /failed; echo SUSEtest OK > /testok'
Type=oneshot
EOF

        cat >/etc/systemd/system/fail-on-restart.service <<EOF
[Unit]
Description=Fail on restart
StartLimitIntervalSec=1m
StartLimitBurst=3

[Service]
Type=simple
ExecStart=/bin/false
Restart=always
EOF


        cat >/test-fail-on-restart.sh <<'EOF'
#!/usr/bin/env bash
set -x

systemctl start fail-on-restart.service
active_state=$(systemctl show --property ActiveState fail-on-restart.service)
while [[ "$active_state" == "ActiveState=activating" || "$active_state" == "ActiveState=active" ]]; do
    sleep 1
    active_state=$(systemctl show --property ActiveState fail-on-restart.service)
done
systemctl is-failed fail-on-restart.service || exit 1
touch /testok
EOF

        chmod 0755 /test-fail-on-restart.sh
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
    for unit in testsuite.service fail-on-restart.service; do
        rm -f /etc/systemd/system/$unit
    done
    rm -f /test-fail-on-restart.sh
    [[ -e /testok ]] && rm /testok
    [[ -e /failed ]] && rm /failed
    return 0
}

do_test "$@"
