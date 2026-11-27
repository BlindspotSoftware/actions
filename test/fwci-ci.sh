#!/bin/sh
# Runs fwci-ci with a fake fwci that prints its arguments: test/fwci-ci.sh [fwci-ci], in the image as
#   docker run --rm -v "$PWD/test:/test:ro" firmwareci/action:v8 sh /test/fwci-ci.sh
script=${1:-fwci-ci}
fake=$(mktemp -d)
trap 'rm -rf "$fake"' EXIT
printf '#!/bin/sh\nprintf "[%%s]" "$@"\nexit "${FAKE_EXIT:-0}"\n' >"$fake/fwci"
chmod +x "$fake/fwci"
failed=0

# check runs fwci-ci with the variables after name, code and want, and expects it to exit with code
# and print want: fwci's arguments, or the message that refuses them.
check() {
  name=$1 code=$2 want=$3
  shift 3
  got=$(env -i PATH="$fake:$PATH" "$@" "$script" 2>&1)
  status=$?
  if [ "$status $got" = "$code $want" ]; then
    echo "ok   $name"
  else
    printf 'FAIL %s\n  want %s %s\n  got  %s %s\n' "$name" "$code" "$want" "$status" "$got"
    failed=1
  fi
}

check defaults 0 '[run][-w][wf][--synced][--follow=false]' FWCI_WORKFLOW=wf
check 'empty switches are defaults' 0 '[run][-w][wf][--synced][--follow=false]' \
  FWCI_WORKFLOW=wf FWCI_LOCAL= FWCI_SYNCED= FWCI_FOLLOW=
check 'tests, args and binaries' 0 \
  '[run][-w][wf][-t][boot][-t][flash][-t][s3 resume][--synced][--follow=false][--priority][low][*][A=a.rom][B=https://x/b.rom][C=my c.rom]' \
  FWCI_WORKFLOW=wf FWCI_TESTS=' boot , flash
 s3 resume ,,' FWCI_ARGS='--priority low *' FWCI_BINARIES=' A=a.rom ; B=https://x/b.rom
  C=my c.rom ;'
check 'metadata' 0 '[run][-w][wf][--metadata][BMC.Version=2.19.0][--metadata][Board=HPE DL320][--synced][--follow=false]' \
  FWCI_WORKFLOW=wf FWCI_METADATA=' BMC.Version=2.19.0 ; Board=HPE DL320
'
check 'local on a DUT' 0 '[run][-w][wf][--dut][board-2]' FWCI_WORKFLOW=wf FWCI_LOCAL=TRUE FWCI_DUT=board-2
check 'not synced' 0 '[run][-w][wf][--remote][--follow=false]' FWCI_WORKFLOW=wf FWCI_SYNCED=No
check 'dut on FirmwareCI' 0 '[run][-w][wf][--dut][b][--synced][--follow=false]' FWCI_WORKFLOW=wf FWCI_DUT=b
check 'follow 1' 0 '[run][-w][wf][--synced][--follow=true]' FWCI_WORKFLOW=wf FWCI_FOLLOW=1
check 'follow 0' 0 '[run][-w][wf][--synced][--follow=false]' FWCI_WORKFLOW=wf FWCI_FOLLOW=0
check 'follow 2h' 0 '[run][-w][wf][--synced][--follow=2h]' FWCI_WORKFLOW=wf FWCI_FOLLOW=2h
check 'local maybe' 1 'FWCI_LOCAL is "maybe": set it to true or false.' FWCI_WORKFLOW=wf FWCI_LOCAL=maybe
check 'synced typo' 1 'FWCI_SYNCED is "ture": set it to true or false.' FWCI_WORKFLOW=wf FWCI_SYNCED=ture
check 'follow soon' 1 'FWCI_FOLLOW is "soon": set it to true, false or a time such as 2h.' \
  FWCI_WORKFLOW=wf FWCI_FOLLOW=soon
check 'local and not synced' 1 \
  "FWCI_SYNCED false sends this checkout's tests to FirmwareCI, and FWCI_LOCAL true runs them here: drop one." \
  FWCI_WORKFLOW=wf FWCI_LOCAL=true FWCI_SYNCED=false
check 'a failed test exits 7' 7 '[run][-w][wf][--synced][--follow=true]' FWCI_WORKFLOW=wf FWCI_FOLLOW=true FAKE_EXIT=7
check 'a follow limit exits 8' 8 '[run][-w][wf][--synced][--follow=2h]' FWCI_WORKFLOW=wf FWCI_FOLLOW=2h FAKE_EXIT=8

exit $failed
