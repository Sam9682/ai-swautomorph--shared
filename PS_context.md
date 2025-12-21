Please check the status of running services and return detailed information in JSON format.

**Parameters:**
- USER_ID: {USER_ID}
- USER_NAME: {USER_NAME}
- USER_EMAIL: {USER_EMAIL}

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

#### 2. Check Docker Compose Status
```bash
docker_status="IS_NOT_RUNNING"
docker_ports="[]"

if HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
   docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml ps | grep -q "Up"; then
    docker_status="IS_RUNNING"
    
    # Extract all ports
    all_ports=$(HTTP_PORT=$HTTP_PORT HTTPS_PORT=$HTTPS_PORT USER_ID=$USER_ID \
                docker-compose -p "$NAME_OF_APPLICATION-$USER_ID-$HTTPS_PORT" -f docker-compose.yml ps | \
                grep "Up" | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2 | sort -n)
    
    if [[ -n "$all_ports" ]]; then
        docker_ports=$(echo "$all_ports" | jq -R . | jq -s .)
    fi
fi
```

#### 3. Get Git Remote URLs
```bash
git_remotes=$(git remote -v 2>/dev/null | awk '{print $2}' | sort -u | jq -R . | jq -s . 2>/dev/null || echo '[]')
```

#### 4. Output JSON
```bash
jq -n --arg user_id "$USER_ID" \
      --arg user_name "$USER_NAME" \
      --arg user_email "$USER_EMAIL" \
      --arg http_port "$HTTP_PORT" \
      --arg https_port "$HTTPS_PORT" \
      --arg docker_status "$docker_status" \
      --argjson docker_ports "$docker_ports" \
      --argjson git_remotes "$git_remotes" \
      '{
        "environment_vars": {
          "USER_ID": $user_id,
          "USER_NAME": $user_name,
          "USER_EMAIL": $user_email,
          "HTTP_PORT": $http_port,
          "HTTPS_PORT": $https_port
        },
        "docker_compose_ps": $docker_status,
        "docker_ports": $docker_ports,
        "git_remote": $git_remotes
      }'
```

**Expected JSON Output Format:**
```json
{
  "environment_vars": {
    "USER_ID": "...",
    "USER_NAME": "...",
    "USER_EMAIL": "...",
    "HTTP_PORT": "...",
    "HTTPS_PORT": "..."
  },
  "docker_compose_ps": "IS_RUNNING or IS_NOT_RUNNING",
  "docker_ports": [...],
  "git_remote": [...]
}
```

**Summary:** Execute the status check for USER_ID={USER_ID} and return the JSON output with all service information.
