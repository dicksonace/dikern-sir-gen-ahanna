#!/usr/bin/env bash
# Deploy the API, the admin website, and the APK to sirgenahanna.com (Hostinger).
#   API     -> ~/domains/sirgenahanna.com/api-backend   (https://api.sirgenahanna.com)
#   Admin   -> ~/domains/sirgenahanna.com/public_html/admin   (https://admin.sirgenahanna.com)
#   APK     -> ~/domains/sirgenahanna.com/public_html/app/Sir-Gen-Ahanna.apk
#
# Usage: SIR_SSH_PASS='...' scripts/deploy-sirgenahanna.sh
# The password is read from the environment only. It is never written to disk.
set -euo pipefail

: "${SIR_SSH_PASS:?Set SIR_SSH_PASS to the Hostinger SSH password}"
export SIR_SSH_PASS

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="u774243561@82.29.185.77"
PORT=65002
HOME_DIR=/home/u774243561
SITE="$HOME_DIR/domains/sirgenahanna.com"
API="$SITE/api-backend"
PHP=/opt/alt/php84/usr/bin/php
APK="$ROOT/mobile/build/app/outputs/flutter-apk/app-release.apk"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

with_password() {
  expect -c '
    set timeout 300
    spawn {*}$argv
    expect {
      -re "(?i)password:" { send -- "$env(SIR_SSH_PASS)\r"; exp_continue }
      eof
    }
    lassign [wait] pid spawnid os_error value
    exit $value
  ' -- "$@"
}
remote() { with_password ssh -o StrictHostKeyChecking=accept-new -o PreferredAuthentications=password -o PubkeyAuthentication=no -p "$PORT" "$HOST" "$1"; }
upload() { with_password scp -o StrictHostKeyChecking=accept-new -o PreferredAuthentications=password -o PubkeyAuthentication=no -P "$PORT" "$@" "$HOST:$HOME_DIR/"; }

echo "==> Building admin website"
(cd "$ROOT/web" && VITE_API_URL=https://api.sirgenahanna.com npm run build -- --base /)

echo "==> Packing"
export COPYFILE_DISABLE=1
tar -C "$ROOT/backend" -czf "$WORK/sir-api.tgz" app bootstrap/app.php bootstrap/providers.php config database/migrations database/seeders routes resources
tar -C "$ROOT/web" -czf "$WORK/sir-admin.tgz" dist
FILES=("$WORK/sir-api.tgz" "$WORK/sir-admin.tgz")
if [ -f "$APK" ]; then
  cp "$APK" "$WORK/Sir-Gen-Ahanna.apk"
  FILES+=("$WORK/Sir-Gen-Ahanna.apk")
else
  echo "    No APK at $APK. Skipping the app upload."
fi

echo "==> Uploading"
upload "${FILES[@]}"

echo "==> Installing"
remote "set -e
tar -xzf $HOME_DIR/sir-api.tgz -C $API 2>/dev/null
rm -rf $HOME_DIR/admin-new && mkdir -p $HOME_DIR/admin-new
tar -xzf $HOME_DIR/sir-admin.tgz -C $HOME_DIR/admin-new 2>/dev/null
cp -R $HOME_DIR/admin-new/dist/. $SITE/public_html/admin/
if [ -f $HOME_DIR/Sir-Gen-Ahanna.apk ]; then mkdir -p $SITE/public_html/app && mv $HOME_DIR/Sir-Gen-Ahanna.apk $SITE/public_html/app/Sir-Gen-Ahanna.apk; fi
printf 'upload_max_filesize = 110M\npost_max_size = 120M\nmax_execution_time = 300\nmax_input_time = 300\nmemory_limit = 256M\n' > $API/public/.user.ini
rm -rf $HOME_DIR/admin-new $HOME_DIR/sir-api.tgz $HOME_DIR/sir-admin.tgz
cd $API
$PHP artisan migrate --force
$PHP artisan optimize:clear
echo INSTALLED"

echo "==> Checking"
curl -sS https://api.sirgenahanna.com/api/health; echo
curl -sS -o /dev/null -w 'admin %{http_code}\n' https://admin.sirgenahanna.com/
curl -sS -o /dev/null -w 'apk %{http_code} %{size_download}\n' -r 0-0 https://sirgenahanna.com/app/Sir-Gen-Ahanna.apk
echo "==> Done"
