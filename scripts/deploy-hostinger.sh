#!/usr/bin/env bash
# Deploy Adikern LMS API onto the Hostinger account that already hosts WedPlan.
# WedPlan stays at https://marriageplan.site — LMS is served from /lms only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY="${HOSTINGER_SSH_KEY:-$HOME/.ssh/hostinger_marriageplan}"
HOST="${HOSTINGER_SSH_HOST:-u371865855@145.14.152.189}"
PORT="${HOSTINGER_SSH_PORT:-65002}"
REMOTE_BASE="${HOSTINGER_LMS_DIR:-/home/u371865855/domains/marriageplan.site/lms}"
REMOTE_PUBLIC="${HOSTINGER_LMS_PUBLIC:-/home/u371865855/domains/marriageplan.site/public_html/lms}"

SSH=(ssh -i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes -p "$PORT" "$HOST")
RSYNC=(rsync -az --delete
  --exclude='.env'
  --exclude='vendor/'
  --exclude='node_modules/'
  --exclude='storage/logs/*'
  --exclude='storage/framework/cache/data/*'
  --exclude='storage/framework/sessions/*'
  --exclude='storage/framework/views/*'
  --exclude='database/database.sqlite'
  --exclude='.phpunit.result.cache'
  -e "ssh -i $KEY -o IdentitiesOnly=yes -o BatchMode=yes -p $PORT"
)

echo "==> Syncing API to $REMOTE_BASE"
"${SSH[@]}" "mkdir -p '$REMOTE_BASE' '$REMOTE_PUBLIC'"
"${RSYNC[@]}" "$ROOT/backend/" "$HOST:$REMOTE_BASE/"

echo "==> Writing public entrypoint (does not modify WedPlan index.php)"
"${SSH[@]}" "bash -s" << REMOTE
set -euo pipefail
cat > '$REMOTE_PUBLIC/index.php' << 'PHP'
<?php

use Illuminate\Foundation\Application;
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

\$prefix = '/lms';
\$uri = \$_SERVER['REQUEST_URI'] ?? '/';
if (str_starts_with(\$uri, \$prefix)) {
    \$_SERVER['REQUEST_URI'] = substr(\$uri, strlen(\$prefix)) ?: '/';
}
\$_SERVER['SCRIPT_NAME'] = '/lms/index.php';

\$laravel = __DIR__.'/../../lms';

if (file_exists(\$maintenance = \$laravel.'/storage/framework/maintenance.php')) {
    require \$maintenance;
}

require \$laravel.'/vendor/autoload.php';

/** @var Application \$app */
\$app = require_once \$laravel.'/bootstrap/app.php';

\$app->handleRequest(Request::capture());
PHP

cat > '$REMOTE_PUBLIC/.htaccess' << 'HT'
<IfModule LiteSpeed>
    AddHandler application/x-httpd-lsphp84 .php
</IfModule>
<FilesMatch "\\.php\$">
    SetHandler application/x-lsphp84
</FilesMatch>

<IfModule mod_rewrite.c>
    <IfModule mod_negotiation.c>
        Options -MultiViews -Indexes
    </IfModule>

    RewriteEngine On

    RewriteCond %{HTTP:Authorization} .
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

    RewriteCond %{HTTP:x-xsrf-token} .
    RewriteRule .* - [E=HTTP_X_XSRF_TOKEN:%{HTTP:X-XSRF-Token}]

    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_URI} (.+)/\$
    RewriteRule ^ %1 [L,R=301]

    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]
</IfModule>
HT

cp '$REMOTE_BASE/public/robots.txt' '$REMOTE_PUBLIC/robots.txt' 2>/dev/null || true
ln -sfn ../../lms/storage/app/public '$REMOTE_PUBLIC/storage'
REMOTE

echo "==> Ensure production .env + sqlite"
"${SSH[@]}" "bash -s" << REMOTE
set -euo pipefail
APP='$REMOTE_BASE'
mkdir -p "\$APP/database" "\$APP/storage/framework/"{cache/data,sessions,views} "\$APP/storage/logs" "\$APP/bootstrap/cache" "\$APP/storage/app/public"
touch "\$APP/database/database.sqlite"
if [ ! -f "\$APP/.env" ]; then
  KEY=\$(/opt/alt/php84/usr/bin/php -r 'echo "base64:".base64_encode(random_bytes(32));')
  cat > "\$APP/.env" << ENV
APP_NAME="LMS"
APP_ENV=production
APP_KEY=\$KEY
APP_DEBUG=false
APP_URL=https://marriageplan.site/lms

APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US

APP_MAINTENANCE_DRIVER=file
BCRYPT_ROUNDS=12

LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=error

DB_CONNECTION=sqlite

SESSION_DRIVER=file
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
CACHE_STORE=file

MAIL_MAILER=log
MAIL_FROM_ADDRESS=noreply@marriageplan.site
MAIL_FROM_NAME="LMS"
ENV
  echo "wrote new .env"
else
  echo ".env already present"
fi
REMOTE

echo "==> Remote composer + migrate (PHP 8.4)"
"${SSH[@]}" "bash -s" << REMOTE
set -euo pipefail
PHP84=/opt/alt/php84/usr/bin/php
cd '$REMOTE_BASE'
if [ ! -f .env ]; then
  echo 'ERROR: .env missing on server. Create it before re-running.'
  exit 1
fi
\$PHP84 \$(which composer) install --no-dev --optimize-autoloader --no-interaction
\$PHP84 artisan storage:link 2>/dev/null || true
\$PHP84 artisan migrate --force
USERS=\$(\$PHP84 artisan tinker --execute='echo App\\Models\\User::query()->count();' | tail -n 1 | tr -dc '0-9')
echo "users=\$USERS"
if [ "\${USERS:-0}" = "0" ]; then
  \$PHP84 artisan db:seed --force
fi
\$PHP84 artisan config:clear
\$PHP84 artisan cache:clear
\$PHP84 artisan config:cache
\$PHP84 artisan route:cache
chmod -R 775 storage bootstrap/cache database
echo DONE
REMOTE

echo "==> Verify"
curl -sS "https://marriageplan.site/api/health" | /usr/bin/head -c 200; echo
curl -sS "https://marriageplan.site/lms/api/health" | /usr/bin/head -c 200; echo
curl -sS "https://marriageplan.site/lms/" | /usr/bin/head -c 200; echo
echo "==> Deploy finished"
