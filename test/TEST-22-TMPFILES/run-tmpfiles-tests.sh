#!/usr/bin/env bash

set -x
set -e

>/failed

for t in test-*.sh; do
        echo "Running $t"; ./$t
done

echo SUSEtest OK > /testok
rm /failed
