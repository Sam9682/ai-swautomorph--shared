Please deploy and start the application by executing the following steps in sequence. Use the provided parameters and ensure all prerequisites are met before proceeding.

**Parameters:**
- USER_ID: {USER_ID}
- USER_NAME: {USER_NAME}
- USER_EMAIL: {USER_EMAIL}
- DESCRIPTION: {DESCRIPTION}

**Configuration:**
Load configuration from `./conf/deploy.ini` which contains:
- NAME_OF_APPLICATION
- RANGE_START
- RANGE_RESERVED
- APPLICATION_IDENTITY_NUMBER

**Port Calculation Formula:**
```
PORT_RANGE_BEGIN = RANGE_START + USER_ID * RANGE_RESERVED
HTTP_PORT = PORT_RANGE_BEGIN + APPLICATION_IDENTITY_NUMBER * 2
HTTPS_PORT = HTTP_PORT + 1
```

**Execute these steps:**

#### 1. Check Prerequisites
```bash
command -v docker || exit 1
command -v docker-compose || exit 1
```

#### 2. Generate Secrets (if .env.prod doesn't exist)
```bash
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

cat > .env.prod << EOF
DATABASE_URL=sqlite:///./data/ai_haccp.db
JWT_SECRET=$JWT_SECRET
DOMAIN=www.swautomorph.com
API_URL=https://www.swautomorph.com
SSL_EMAIL=admin@swautomorph.com
REACT_APP_API_URL=https://www.swautomorph.com
EOF

chmod 600 .env.prod
```

#### 3. Generate Nginx Configuration
```bash
sed "s/\${USER_ID}/$USER_ID/g" conf/nginx.conf.template > conf/nginx.conf
```

#### 4. Setup SSL Certificates
```bash
mkdir -p ssl

# Check for existing certificates
if [[ -f ~/.ssh/www_swautomorph_com.crt && -f ~/.ssh/privateKey_automorph_simple.key ]]; then
    cp ~/.ssh/www_swautomorph_com.crt ssl/fullchain.pem
    cp ~/.ssh/privateKey_automorph_simple.key ssl/privkey.pem
# Try certbot
elif command -v certbot &> /dev/null; then
    sudo systemctl stop nginx 2>/dev/null || true
    sudo certbot certonly --standalone -d www.swautomorph.com --email admin@swautomorph.com --agree-tos --non-interactive --quiet
    sudo cp /etc/letsencrypt/live/www.swautomorph.com/fullchain.pem ssl/
    sudo cp /etc/letsencrypt/live/www.swautomorph.com/privkey.pem ssl/
    sudo chown -R $USER:$USER ssl/
# Create self-signed
else
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/privkey.pem \
        -out ssl/fullchain.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=www.swautomorph.com"
fi
```

#### 5. Deploy Services
```bash
# Stop existing
HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml down 2>/dev/null || true

# Build
HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml build --no-cache --build-arg PIP_UPGRADE=1

# Start
HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml --env-file .env.prod up -d

# Wait
sleep 30
```

#### 6. Verify Deployment
```bash
docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml ps | grep -q "Up"
sleep 10
curl -f -s "http://www.swautomorph.com:${HTTP_PORT}/health" || true
```

#### 7. Configure Firewall (if UFW available)
```bash
if command -v ufw &> /dev/null; then
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow ${HTTP_PORT}/tcp
    sudo ufw allow ${HTTPS_PORT}/tcp
    sudo ufw --force enable
fi
```

#### 8. Create Backup Script
```bash
mkdir -p scripts
cat > ./scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/ai_haccp_backup_$DATE"
mkdir -p "$BACKUP_DIR"
HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml exec -T api cp /app/data/ai_haccp.db /tmp/backup.db
docker cp $(docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml ps -q api):/tmp/backup.db "$BACKUP_FILE.db"
ls -t "$BACKUP_DIR"/ai_haccp_backup_*.db | tail -n +8 | xargs -r rm
EOF
chmod +x ./scripts/backup.sh
```

**After completion, verify:**
- All containers are running (check with docker-compose ps)
- Services are accessible on calculated HTTP_PORT and HTTPS_PORT
- Report the final status including ports and any errors encountered

**Summary:** Execute all steps above to deploy the application for USER_ID={USER_ID}. Report success or failure with details.
