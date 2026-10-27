#!/bin/zsh
# Personal, first-install package for the public Xiaomi build. The upstream
# release installer requires private Siri helpers, which this fork does not use.
set -euo pipefail
ROOT="${0:A:h:h}"
APP="$ROOT/dist/SayAll.app"
DRIVER="$ROOT/dist/MiRemoteV2ch.driver"
OUTPUT="$ROOT/dist/Install SayAll Qianwen.pkg"
test -x "$APP/Contents/MacOS/RemoteMic"
test "$(plutil -extract SayAllLocalFork raw -o - "$APP/Contents/Info.plist")" = true
codesign --verify --deep --strict "$APP"
"$ROOT/scripts/verify-doubao-driver.sh" "$DRIVER" brand
# Build outside synced Documents folders: File Provider's FinderInfo metadata
# invalidates code signatures on bundles in those folders.
WORK="$(mktemp -d /private/tmp/sayall-qianwen-package.XXXXXX)"
mkdir -p "$WORK/root/Applications" "$WORK/root/Library/Audio/Plug-Ins/HAL" "$WORK/scripts"
ditto --norsrc --noextattr --noqtn --noacl "$APP" "$WORK/root/Applications/SayAll.app"
ditto --norsrc --noextattr --noqtn --noacl "$DRIVER" "$WORK/root/Library/Audio/Plug-Ins/HAL/MiRemoteV2ch.driver"
cat > "$WORK/scripts/preinstall" <<'PREINSTALL'
#!/bin/zsh
set -euo pipefail
[[ "${3:-/}" == / ]] || { print -u2 "Install on the startup disk only."; exit 1; }
[[ "$(sysctl -in hw.optional.arm64)" == 1 ]] || { print -u2 "This package requires Apple silicon."; exit 1; }
for destination in /Applications/SayAll.app /Library/Audio/Plug-Ins/HAL/MiRemoteV2ch.driver; do
  if [[ -e "$destination" || -L "$destination" ]]; then
    print -u2 "First-install package: refusing to replace $destination. Preserve the existing installation before updating."
    exit 1
  fi
done
PREINSTALL
cat > "$WORK/scripts/postinstall" <<'POSTINSTALL'
#!/bin/zsh
set -euo pipefail
codesign --verify --deep --strict /Applications/SayAll.app
codesign --verify --deep --strict /Library/Audio/Plug-Ins/HAL/MiRemoteV2ch.driver
if pgrep -qx coreaudiod; then
  killall coreaudiod || print "Restart your Mac to load the installed audio driver."
fi
print "Installed. Open /Applications/SayAll.app and choose Qianwen in setup."
POSTINSTALL
chmod 755 "$WORK/scripts/preinstall" "$WORK/scripts/postinstall"
pkgbuild --analyze --root "$WORK/root" "$WORK/components.plist"
python3 - "$WORK/components.plist" <<'PY'
import plistlib, sys
path = sys.argv[1]
with open(path, 'rb') as stream:
    components = plistlib.load(stream)
for component in components:
    component['BundleIsRelocatable'] = False
with open(path, 'wb') as stream:
    plistlib.dump(components, stream)
PY
pkgbuild --root "$WORK/root" --component-plist "$WORK/components.plist" \
  --scripts "$WORK/scripts" --identifier local.sayall.qianwen \
  --version 1.0 --install-location / "$OUTPUT"
print "Personal ad-hoc build, not notarized: $OUTPUT"
print "Retained package staging for inspection: $WORK"
