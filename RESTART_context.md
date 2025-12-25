Please restart all running Docker containers for the specified user instance without rebuilding images.
IMPORTANT : all commands have to be executed in the application located {APPLICATION_FOLDER}.

#### 1. Calculate HTTP Ports, which are the ports used by the docker containers of the application. Use the following command:

source ./conf/deploy.ini
if ! [[ "$USER_ID" =~ ^[0-9]+$ ]]; then
    USER_ID=0
fi
PORT_RANGE_BEGIN = $RANGE_START + $USER_ID * $RANGE_RESERVED
HTTP_PORT = $PORT_RANGE_BEGIN + $APPLICATION_IDENTITY_NUMBER * $RANGE_PORTS_PER_APPLICATION
HTTPS_PORT = $HTTP_PORT + 1
HTTP_PORT2=$(($HTTPS_PORT + 1))
HTTPS_PORT2=$(($HTTP_PORT2 + 1))

#### 2. Restart Services
HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml restart


**After completion, verify:**
- All containers for USER_ID={USER_ID} are restarted successfully
- Services are running with existing configuration
- No images were rebuilt
- Report the final status

**Summary:** Execute the restart command for USER_ID={USER_ID} and confirm all services are running again.
