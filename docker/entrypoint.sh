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

echo "⚙️ Modifying .env for container environment..."
sed -i "s/DB_HOST=.*/DB_HOST=db/g" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=laravel/g" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=user/g" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=password/g" .env

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

# Install & build frontend (npm)
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
# Load .env variables into shell
export $(grep -v '^#' .env | xargs)

until mysql -h "$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" &> /dev/null
do
    echo "🔁 Waiting for MySQL..."
    sleep 2
done
echo "✅ MySQL is ready."

# Run migrations
echo "🚀 Running migrations..."
php artisan migrate --force

# Run seeders
echo "🌱 Seeding database..."
php artisan db:seed --class=AdminSeeder --force
php artisan db:seed --class=BrandSeeder --force
php artisan db:seed --class=CategorySeeder --force
php artisan db:seed --class=ProductSeeder --force

# Start PHP-FPM
echo "✅ Starting PHP-FPM..."
exec php-fpm
