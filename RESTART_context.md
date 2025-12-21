Please restart all running Docker containers for the specified user instance without rebuilding images.

**Parameters:**
- USER_ID: {USER_ID}

**Configuration:**
Load configuration from `./conf/deploy.ini` which contains:
- NAME_OF_APPLICATION
- RANGE_START
- RANGE_RESERVED
- APPLICATION_IDENTITY_NUMBER

**Port Calculation Formula:**
```
PORT_RANGE_BEGIN = RANGE_START + USER_ID * RANGE_RESERVED
HTTP_PORT = PORT_RANGE_BEGIN + APPLICATION_IDENTITY_NUMBER * RANGE_PORTS_PER_APPLICATION
HTTPS_PORT = HTTP_PORT + 1
```

**Execute these steps:**

#### 1. Calculate Ports
```bash
# Load configuration
source ./conf/deploy.ini

# Ensure USER_ID is numeric
if ! [[ "$USER_ID" =~ ^[0-9]+$ ]]; then
    USER_ID=0
fi

# Calculate ports
PORT_RANGE_BEGIN=$((RANGE_START + USER_ID * RANGE_RESERVED))
HTTP_PORT=$((PORT_RANGE_BEGIN + APPLICATION_IDENTITY_NUMBER * RANGE_PORTS_PER_APPLICATION))
HTTPS_PORT=$((HTTP_PORT + 1))
```

#### 2. Restart Services
```bash
HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml restart
```

**After completion, verify:**
- All containers for USER_ID={USER_ID} are restarted successfully
- Services are running with existing configuration
- No images were rebuilt
- Report the final status

**Summary:** Execute the restart command for USER_ID={USER_ID} and confirm all services are running again.
