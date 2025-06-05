#!/bin/bash

set -euo pipefail
trap "echo 🔥 ERROR on line $LINENO" ERR

echo "📄 Checking .env file..."
if [ ! -f ".env" ]; then
    echo "📄 Copying .env.example to .env"
    cp .env.example .env
else
    echo "✅ .env already exists, skipping copy..."
fi

# echo "⚙️ Modifying .env for container environment..."
# sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/g" .env
# sed -i "s/DB_HOST=.*/DB_HOST=db/g" .env
# sed -i "s/DB_PORT=.*/DB_PORT=3306/g" .env
# sed -i "s/DB_DATABASE=.*/DB_DATABASE=laravel/g" .env
# sed -i "s/DB_USERNAME=.*/DB_USERNAME=user/g" .env
# sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=password/g" .env
echo "⚙️ Patching .env DB config..."

set_env() {
    key=$1
    value=$2

    # Kalau baris aktif udah ada → ganti
    if grep -q "^${key}=" .env; then
        sed -i "s|^${key}=.*|${key}=${value}|" .env

    # Kalau cuma versi komen yang ada → uncomment dan ubah
    elif grep -q "^#\s*${key}=" .env; then
        sed -i "s|^#\s*${key}=.*|${key}=${value}|" .env

    # Kalau gak ada dua-duanya → tambahkan ke akhir file
    else
        echo "${key}=${value}" >> .env
    fi
}

set_env "DB_CONNECTION" "mysql"
set_env "DB_HOST" "db"
set_env "DB_PORT" "3306"
set_env "DB_DATABASE" "laravel"
set_env "DB_USERNAME" "user"
set_env "DB_PASSWORD" "password"

# Load .env vars
export $(grep -v '^#' .env | xargs)

echo "🧪 DB_HOST: $DB_HOST"
echo "🧪 DB_USER: $DB_USERNAME"

# Install composer dependencies
if [ ! -d "vendor" ]; then
    echo "🔧 Installing composer dependencies..."
    composer install
fi

# Generate app key
if ! grep -q "APP_KEY=" .env || [[ -z "$(grep APP_KEY .env | cut -d '=' -f2)" ]]; then
    echo "🔐 Generating app key..."
    php artisan key:generate
fi

# Install & build frontend
if [ ! -d "node_modules" ]; then
    echo "📦 Installing NPM dependencies..."
    npm install
fi

if [ ! -d "public/build" ]; then
    echo "🛠️ Building frontend..."
    npm run build
fi

# Wait until DB is ready
echo "⏳ Waiting for MySQL to be ready..."
until mysql -h "$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" &> /dev/null; do
    echo "🔁 Waiting for MySQL..."
    sleep 2
done
echo "✅ MySQL is ready."

# Run migrations
echo "🚀 Running migrations..."
php artisan migrate --force

# Run seeders
echo "🌱 Seeding database..."
# php artisan db:seed --class=AdminSeeder --force
# php artisan db:seed --class=BrandSeeder --force
# php artisan db:seed --class=CategorySeeder --force
# php artisan db:seed --class=ProductSeeder --force

# Link storage
echo "🔗 Linking storage..."
php artisan storage:link

# Start queue workers
echo "🚀 Starting queue workers..."
# php artisan queue:work --daemon --sleep=3 --tries=3

# Start PHP-FPM
echo "✅ Starting PHP-FPM..."
exec php-fpm
