Please stop all running Docker containers for the specified user instance by executing the following steps.

**Parameters:**
- USER_ID: {USER_ID}

**Configuration:**
Load configuration from `./conf/deploy.ini` which contains:
- NAME_OF_APPLICATION
- RANGE_START
- RANGE_RESERVED
- APPLICATION_IDENTITY_NUMBER
- RANGE_PORTS_PER_APPLICATION

**Port Calculation Formula:**
```
PORT_RANGE_BEGIN = RANGE_START + USER_ID * RANGE_RESERVED
HTTP_PORT = PORT_RANGE_BEGIN + APPLICATION_IDENTITY_NUMBER * RANGE_PORTS_PER_APPLICATION
HTTPS_PORT = HTTP_PORT + 1
HTTP_PORT2=$((HTTPS_PORT + 1))
HTTPS_PORT2=$((HTTP_PORT2 + 1))
```

**Execute these steps:**

#### 1. Calculate HTTP Ports, which are the ports used by the docker containers of the application
Use the following command to calculate the docker ports of the running application to stop:
```bash
# Load configuration
source ./conf/deploy.ini
# Ensure USER_ID is numeric
if ! [[ "$USER_ID" =~ ^[0-9]+$ ]]; then
    USER_ID=0
fi
# Calculate ports
PORT_RANGE_BEGIN = RANGE_START + USER_ID * RANGE_RESERVED
HTTP_PORT = PORT_RANGE_BEGIN + APPLICATION_IDENTITY_NUMBER * RANGE_PORTS_PER_APPLICATION
HTTPS_PORT = HTTP_PORT + 1
HTTP_PORT2=$((HTTPS_PORT + 1))
HTTPS_PORT2=$((HTTP_PORT2 + 1))
```

#### 2. Stop the running application
Use the following commands to stop the application, based on the ports calculated during step 1:
```bash
HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml down
```

**After completion, verify:**
- All containers for USER_ID={USER_ID} are stopped and removed
- Networks are removed
- Volumes are preserved
- Report the final status

**Summary:** Execute the stop command for USER_ID={USER_ID} and confirm all services are stopped.
