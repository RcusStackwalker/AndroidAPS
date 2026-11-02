#!/usr/bin/env bash
set -euo pipefail
suite=${1:?Expected A, B, C, or modules}
if [[ "$suite" == modules ]]; then
  tasks=()
  while IFS= read -r source; do
    module=${source#./}; module=${module%/src/*}; module=${module//\//:}
    [[ "$module" == app ]] && continue
    grep -q "^include ':$module'" settings.gradle || continue
    if [[ "$source" == */androidDeviceTest ]]; then
      tasks+=(":$module:connectedAndroidDeviceTest")
    else
      tasks+=(":$module:connectedDebugAndroidTest")
    fi
  done < <(find . -type d \( -name androidTest -o -name androidDeviceTest \) -not -path '*/build/*' | sort)
  ((${#tasks[@]})) || { echo 'No device test modules found'; exit 1; }
  ./gradlew --console=plain --no-daemon --continue -Pcoverage "${tasks[@]}"
  exit
fi
case "$suite" in
  A|B) filter=(-e annotation "app.aaps.testcategories.Shard$suite") ;;
  C) filter=(-e notAnnotation "app.aaps.testcategories.ShardA,app.aaps.testcategories.ShardB") ;;
  *) echo "Unknown suite: $suite" >&2; exit 1 ;;
esac
pkg=info.nightscout.androidaps
covdir=app/build/outputs/code_coverage/fullDebugAndroidTest/connected
mkdir -p "$covdir" device-logs
for apk in app/build/outputs/apk/full/debug/app-full-debug.apk app/build/outputs/apk/androidTest/full/debug/app-full-debug-androidTest.apk; do
  output=$(adb install -r -d "$apk" 2>&1)
  echo "$output"
  [[ "$output" == *Success* ]] || exit 1
done
adb shell pm list instrumentation | grep -q "$pkg.test/app.aaps.runners.AapsTestRunner"
adb logcat -G 16M || true
for attempt in 1 2 3; do
  log="device-logs/shard-$suite-$attempt.txt"
  adb shell am force-stop "$pkg"
  adb shell run-as "$pkg" rm -f "cov-$suite.ec"
  adb logcat -c
  adb shell am instrument -w -r "${filter[@]}" -e coverage true \
    -e coverageFile "/data/data/$pkg/cov-$suite.ec" \
    "$pkg.test/app.aaps.runners.AapsTestRunner" > "$log" 2>&1 || true
  cat "$log"
  adb logcat -d -v time > "device-logs/logcat-$suite-$attempt.txt" || true
  adb exec-out run-as "$pkg" cat "cov-$suite.ec" > "$covdir/cov-$suite.ec" || true
  size=$(wc -c < "$covdir/cov-$suite.ec")
  if grep -qE 'Process crashed|INSTRUMENTATION_FAILED' "$log" || ((size < 50000)); then
    continue
  fi
  if grep -qE 'FAILURES!!!|INSTRUMENTATION_ABORTED' "$log"; then exit 1; fi
  grep -qE 'OK \([1-9][0-9]* tests?\)' "$log" && exit 0
  echo 'Instrumentation did not report successful test completion'
  exit 1
done
echo 'Shard failed after three attempts'
exit 1
