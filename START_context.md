You are an autonomous IT Operater agent with access to execute shell commands on a Linux server.
Please deploy and start the application by executing the following steps in sequence. 
IMPORTANT : all commands have to be executed in the application located {APPLICATION_FOLDER}.

**Execute these steps:**

#### 1. Check Prerequisites, docker and docker-compose have to be installed on the current server. you can use the following commands to check if docker and docker-compose are installed:

command -v docker || exit 1
command -v docker-compose || exit 1

#### 2. Generate Secrets (only if .env.prod doesn't exist)

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

#### 3. Calculate HTTP Ports, which are the ports used by the docker containers of the application. Use the following command:

source ./conf/deploy.ini
if ! [[ "$USER_ID" =~ ^[0-9]+$ ]]; then
    USER_ID=0
fi
PORT_RANGE_BEGIN=$((RANGE_START+USER_ID*RANGE_RESERVED))
HTTP_PORT=$((PORT_RANGE_BEGIN+APPLICATION_IDENTITY_NUMBER*RANGE_PORTS_PER_APPLICATION))
HTTPS_PORT=$((HTTP_PORT+1))
HTTP_PORT2=$(($HTTPS_PORT+1))
HTTPS_PORT2=$(($HTTP_PORT2+1))

#### 4. Generate Nginx Configuration. If conf/nginx.conf.template file exists, then use nginx.conf.template to create nginx.conf. If the file does not exists, then go to next step.
you can use the following command:
sed "s/\$\U\S\E\R\_\I\D/{$USER_ID}/g" conf/nginx.conf.template > conf/nginx.conf

#### 5. Setup SSL Certificates. If exist, copy www_swautomorph_com.crt and privateKey_automorph_simple.key. You can use the following commands:
mkdir -p ssl
if [[ -f ~/.ssh/www_swautomorph_com.crt && -f ~/.ssh/privateKey_automorph_simple.key ]]; then
    cp ~/.ssh/www_swautomorph_com.crt ssl/fullchain.pem
    cp ~/.ssh/privateKey_automorph_simple.key ssl/privkey.pem
elif command -v certbot &> /dev/null; then
    sudo systemctl stop nginx 2>/dev/null || true
    sudo certbot certonly --standalone -d www.swautomorph.com --email admin@swautomorph.com --agree-tos --non-interactive --quiet
    sudo cp /etc/letsencrypt/live/www.swautomorph.com/fullchain.pem ssl/
    sudo cp /etc/letsencrypt/live/www.swautomorph.com/privkey.pem ssl/
    sudo chown -R $USER:$USER ssl/
else
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/privkey.pem \
        -out ssl/fullchain.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=www.swautomorph.com"
fi

#### 6. Build the docker service using the following command:

docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml build --no-cache --build-arg PIP_UPGRADE=1
(The HTTP_PORT and HTTPS_PORT have been calculated in step 3)

#### 7. Start the docker services using following command:

docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml --env-file .env.prod up -d
(The HTTP_PORT and HTTPS_PORT have been calculated in step 3)

#### 8. Verify the docker service is up and running using the following command:

curl -f -s "http://www.swautomorph.com:${HTTP_PORT}" || true
(The HTTP_PORT and HTTPS_PORT have been calculated in step 3)

#### 9. Configure Firewall (UFW has to be available). Use the following commands to allow incoming socket flow for the service:

if command -v ufw &> /dev/null; then
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow ${HTTP_PORT}/tcp
    sudo ufw allow ${HTTPS_PORT}/tcp
    sudo ufw --force enable
fi

**After completion, verify:**
- All containers are running (check with docker-compose ps)
- Services are accessible on calculated HTTP_PORT and HTTPS_PORT
- Report the final status including ports and any errors encountered

**Summary:** Execute all steps above to deploy the application for USER_ID=2. Report success or failure with details.

IMPORTANT: You must complete ALL steps above. Do not stop early. Execute every command and report the final status of the deployment.