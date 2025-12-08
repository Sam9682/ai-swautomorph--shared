# Application Deployment Guide

This guide describes the deployment operations for the application. An AI agent can use these instructions to install, manage, and verify the application.

## Prerequisites

Before starting deployment, ensure the following are installed:
- Docker (check with `docker --version`)
- Docker Compose (check with `docker-compose --version`)
- OpenSSL for generating secrets
- curl for health checks
- jq for JSON processing

The script should NOT be run as root user.

## Configuration

The deployment script loads configuration from `./conf/deploy.ini` which should define:
- `NAME_OF_APPLICATION`: Application name
- `RANGE_START`: Starting port range
- `RANGE_RESERVED`: Number of ports reserved per user
- `APPLICATION_IDENTITY_NUMBER`: Application identifier for port calculation

Port calculation formula:
```
PORT_RANGE_BEGIN = RANGE_START + USER_ID * RANGE_RESERVED
HTTP_PORT = PORT_RANGE_BEGIN + APPLICATION_IDENTITY_NUMBER * 2
HTTPS_PORT = HTTP_PORT + 1
```

## Operation 1: Check Prerequisites

**Purpose**: Verify that Docker and Docker Compose are installed and accessible.

**Steps**:
1. Check if Docker is installed: `command -v docker`
2. Check if Docker Compose is installed: `command -v docker-compose`
3. Exit with error if either is missing

**Command**: This is part of the `start` operation.

## Operation 2: Generate Secrets and Configuration

**Purpose**: Create secure environment file and nginx configuration.

**Steps for Secrets**:
1. Check if `.env.prod` file exists
2. If not exists:
   - Generate secure DB password: `openssl rand -base64 32 | tr -d "=+/" | cut -c1-25`
   - Generate JWT secret: `openssl rand -base64 32 | tr -d "=+/" | cut -c1-32`
   - Create `.env.prod` with DATABASE_URL, JWT_SECRET, DOMAIN, API_URL, SSL_EMAIL, REACT_APP_API_URL
   - Set file permissions to 600

**Steps for Nginx Config**:
1. Check if `conf/nginx.conf.template` exists
2. Replace `${USER_ID}` placeholder with actual USER_ID value
3. Save as `conf/nginx.conf`

**Command**: This is part of the `start` operation.

## Operation 3: Setup SSL Certificates

**Purpose**: Configure SSL certificates for HTTPS access.

**Steps**:
1. Create `ssl/` directory if it doesn't exist
2. Check for existing certificates in `~/.ssh/`:
   - If `~/.ssh/www_swautomorph_com.crt` AND `~/.ssh/privateKey_automorph_simple.key` exist:
     - Copy to `ssl/fullchain.pem` and `ssl/privkey.pem`
3. Else if certbot is installed:
   - Stop nginx if running: `sudo systemctl stop nginx`
   - Obtain certificate: `sudo certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive --quiet`
   - Copy certificates from `/etc/letsencrypt/live/$DOMAIN/` to `ssl/`
4. Else create self-signed certificate:
   - `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/privkey.pem -out ssl/fullchain.pem -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"`

**Command**: This is part of the `start` operation.

## Operation 4: Deploy Services

**Purpose**: Build and start Docker containers with proper configuration.

**Steps**:
1. Stop existing services:
   ```bash
   HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
   docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml down
   ```

2. Build Docker images:
   ```bash
   HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
   docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml build --no-cache --build-arg PIP_UPGRADE=1
   ```

3. Start services:
   ```bash
   HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
   docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml --env-file .env.prod up -d
   ```

4. Wait 30 seconds for services to initialize

5. Check if services are running:
   ```bash
   docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml ps | grep -q "Up"
   ```

**Command**: `./deployApp.sh start [USER_ID] [USER_NAME] [USER_EMAIL] [DESCRIPTION]`

## Operation 5: Verify Deployment

**Purpose**: Confirm services are running and accessible.

**Steps**:
1. Check docker-compose status:
   ```bash
   docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml ps | grep -q "Up"
   ```

2. Wait 10 seconds

3. Test API health endpoint:
   ```bash
   curl -f -s "http://www.swautomorph.com:${HTTP_PORT}/health"
   ```

4. Return success if services are running (health check is optional)

**Command**: This is part of the `start` operation, or check status with `./deployApp.sh ps [USER_ID]`

## Additional Operations

### Check Status
**Command**: `./deployApp.sh ps [USER_ID]`

Returns JSON with:
- Environment variables (USER_ID, USER_NAME, USER_EMAIL, HTTP_PORT, HTTPS_PORT)
- Docker compose status (IS_RUNNING or IS_NOT_RUNNING)
- Active ports
- Git remote URLs

### Stop Services
**Command**: `./deployApp.sh stop [USER_ID]`

Stops all running containers for the specified user.

### Restart Services
**Command**: `./deployApp.sh restart [USER_ID]`

Restarts all containers without rebuilding.

### View Logs
**Command**: `./deployApp.sh logs [USER_ID]`

Shows real-time logs from all containers.

## Example Usage

```bash
# Deploy application for user ID 1
./deployApp.sh start 1 john john@example.com "John's Instance"

# Check status
./deployApp.sh ps 1

# View logs
./deployApp.sh logs 1

# Stop services
./deployApp.sh stop 1
```

## Firewall Configuration (Optional)

If UFW is available, the deployment configures:
- Reset firewall rules
- Deny incoming by default
- Allow outgoing by default
- Allow SSH
- Allow HTTP_PORT/tcp
- Allow HTTPS_PORT/tcp

## Backup

A backup script is created at `./scripts/backup.sh` that:
- Backs up the SQLite database
- Keeps last 7 backups
- Can be run manually or via cron
