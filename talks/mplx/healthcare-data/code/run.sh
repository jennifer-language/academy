#!/bin/sh
# The whole chain on loopback: the FHIR fake, the bridge, the LIS, then the
# analyzer sends its results; readback.j reads them back. Logs go to fhirfake.log, bridge.log and lis.log.
set -e
cd "$(dirname "$0")"
jennifer run fhirfake.j > fhirfake.log 2>&1 & fake=$!
jennifer run bridge.j > bridge.log 2>&1 & bridge=$!
sleep 1
jennifer run lis.j > lis.log 2>&1 & lis=$!
sleep 1
jennifer run analyzer.j
wait $lis
sleep 1
kill $bridge
cat lis.log bridge.log
jennifer run readback.j
kill $fake
