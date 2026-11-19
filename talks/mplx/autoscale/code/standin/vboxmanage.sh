#!/bin/sh
# A stand-in VBoxManage for the calls the autoscaler makes. Machines are
# files in $STATE: "<uuid>" holding "name state stop-at-seconds".
STATE="$(dirname "$0")/vbox-state"
mkdir -p "$STATE"
echo "VBoxManage $*" >> "$STATE/../vbox-calls.log"
now=$(date +%s)
settle() {
  for f in "$STATE"/*; do
    [ -f "$f" ] || continue
    read -r n s t < "$f"
    if [ "$t" != 0 ] && [ "$now" -ge "$t" ]; then echo "$n poweroff 0" > "$f"; fi
  done
}
find_vm() {
  for f in "$STATE"/*; do
    [ -f "$f" ] || continue
    read -r n s t < "$f"
    if [ "$n" = "$1" ] || [ "$(basename "$f")" = "$1" ]; then echo "$f"; return; fi
  done
  echo "VBoxManage: error: Could not find a registered machine named '$1'" >&2
  echo "VBoxManage: error: Details: code VBOX_E_OBJECT_NOT_FOUND (0x80bb0001)" >&2
  exit 1
}
[ -f "$STATE/00000000-0000-4000-8000-000000009000" ] ||
  echo "worker-template poweroff 0" > "$STATE/00000000-0000-4000-8000-000000009000"
settle
case "$1" in
  --version) echo "7.1.4r165100" ;;
  list)
    for f in "$STATE"/*; do
      read -r n s t < "$f"
      if [ "$2" = vms ] || [ "$s" = running ]; then echo "\"$n\" {$(basename "$f")}"; fi
    done ;;
  clonevm)
    find_vm "$2" >/dev/null || exit 1
    shift 2
    while [ $# -gt 0 ]; do [ "$1" = --name ] && name="$2"; shift; done
    seq=$(ls "$STATE" | wc -l)
    uuid=$(printf '00000000-0000-4000-8000-%012d' "$seq")
    echo "$name poweroff 0" > "$STATE/$uuid"
    echo "0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%"
    echo "Machine has been successfully cloned as \"$name\"" ;;
  startvm)
    f=$(find_vm "$2") || exit 1
    read -r n s t < "$f"; echo "$n running 0" > "$f"
    echo "Waiting for VM \"$2\" to power on..."
    echo "VM \"$2\" has been successfully started." ;;
  controlvm)
    f=$(find_vm "$2") || exit 1
    read -r n s t < "$f"
    [ "$3" = acpipowerbutton ] && echo "$n running $((now + 3))" > "$f" ;;
  unregistervm)
    f=$(find_vm "$2") || exit 1
    rm -f "$f"
    echo "0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%" ;;
  *) echo "VBoxManage: error: stand-in does not know '$1'" >&2; exit 1 ;;
esac
