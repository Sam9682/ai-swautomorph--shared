#!/bin/bash
# Runtime + static test suite for the 12-port array-based deployApp.sh
set -u
D=/home/slepetre/workspace/forgejo/ai-swautomorph--shared/deployApp.sh
export USER_NAME=admin USER_EMAIL=t@e.com NAME_OF_APPLICATION=myapp
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); }
bad(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
RANGE_START=6000; RANGE_RESERVED=100; RANGE_PORTS_PER_APPLICATION=12
PORT_NAMES=(HTTP_PORT1 HTTPS_PORT1 HTTP_PORT2 HTTPS_PORT2 HTTP_PORT3 HTTPS_PORT3 HTTP_PORT4 HTTPS_PORT4 HTTP_PORT5 HTTPS_PORT5 HTTP_PORT HTTPS_PORT)
awk "/^calculate_ports\(\) \{/,/^\}/" "$D" > /tmp/c.sh
awk "/^port_env_prefix\(\) \{/,/^\}/" "$D" > /tmp/pe.sh
awk "/^show_environment\(\) \{/,/^\}/" "$D" > /tmp/sh.sh
awk "/^setup_firewall\(\) \{/,/^\}/" "$D" > /tmp/fw.sh
awk "/^check_status\(\) \{/,/^\}/" "$D" > /tmp/cs.sh
source /tmp/c.sh; source /tmp/pe.sh; source /tmp/sh.sh; source /tmp/fw.sh

# P1/P2: 12 consecutive ports, 150 random iters
echo "== 12-port calculation (150 iters) =="
for i in $(seq 1 150); do
  USER_ID=$((RANDOM%500)); APPLICATION_IDENTITY_NUMBER=$((RANDOM%50))
  calculate_ports
  base=$((6000 + USER_ID*100 + APPLICATION_IDENTITY_NUMBER*12))
  g=1
  [[ "$HTTP_PORT1" -eq $base ]] || { g=0; bad "HTTP_PORT1"; }
  [[ "$HTTP_PORT" -eq $((base+10)) ]] || { g=0; bad "HTTP_PORT got=$HTTP_PORT want=$((base+10))"; }
  [[ "$HTTPS_PORT" -eq $((base+11)) ]] || { g=0; bad "HTTPS_PORT got=$HTTPS_PORT want=$((base+11))"; }
  v=$(for n in "${PORT_NAMES[@]}"; do echo "${!n}"; done|sort -n|uniq|tr "\n" " ")
  w=$(seq $base $((base+11))|tr "\n" " ")
  [[ "$v" == "$w" ]] || { g=0; bad "12-set got=[$v]"; }
  [[ $g -eq 1 ]] && ok
done

# P3: show_environment lists 12
USER_ID=2; APPLICATION_IDENTITY_NUMBER=4; calculate_ports
o=$(show_environment ps); s=1
for n in "${PORT_NAMES[@]}"; do echo "$o"|grep -q "$n=${!n}"||{ s=0; bad "show_env $n"; }; done
[[ $s -eq 1 ]] && ok

# P4: env prefix has 12 + USER_ID
p=$(port_env_prefix); s=1
for n in "${PORT_NAMES[@]}"; do echo "$p"|grep -q "$n=${!n}"||{ s=0; bad "prefix $n"; }; done
echo "$p"|grep -q "USER_ID=2"||{ s=0; bad "prefix USER_ID"; }
[[ $s -eq 1 ]] && ok

# P5: firewall opens 12 non-empty, skips empty
ALLOWED=""
ufw(){ [[ "$1" == "allow" ]] && ALLOWED="$ALLOWED ${2%%/*}"; }
sudo(){ [[ "$1" == "ufw" ]] && { shift; ufw "$@"; }; }
command(){ [[ "${2:-}" == "ufw" ]] && return 0; builtin command "$@"; }
log_info(){ :; }; log_warn(){ :; }
setup_firewall
got=$(echo "$ALLOWED"|sed "s/^ //")
exp=""; for n in "${PORT_NAMES[@]}"; do exp="$exp ${!n}"; done; exp=$(echo "$exp"|sed "s/^ //")
[[ "$got" == "$exp" ]] && ok || bad "fw all got=[$got]"
ALLOWED=""; HTTPS_PORT=""; setup_firewall
g5=$(echo "$ALLOWED"|sed "s/^ //")
e5=""; for n in "${PORT_NAMES[@]}"; do [[ -n "${!n}" ]] && e5="$e5 ${!n}"; done; e5=$(echo "$e5"|sed "s/^ //")
[[ "$g5" == "$e5" ]] && ok || bad "fw empty got=[$g5]"

# check_status JSON has 12 ports + 15 keys
USER_ID=1; APPLICATION_IDENTITY_NUMBER=0; calculate_ports
docker(){ return 1; }; git(){ echo ""; }
source /tmp/cs.sh
j=$(check_status)
echo "$j"|jq -e ".environment_vars.HTTP_PORT">/dev/null && ok || bad "json HTTP_PORT"
echo "$j"|jq -e ".environment_vars.HTTPS_PORT">/dev/null && ok || bad "json HTTPS_PORT"
kc=$(echo "$j"|jq ".environment_vars|keys|length")
[[ "$kc" -eq 15 ]] && ok || bad "json key count=$kc want 15"

# static: RANGE=12 in script
grep -q "RANGE_PORTS_PER_APPLICATION=12" "$D" && ok || bad "RANGE=12 missing"
bash -n "$D" && ok || bad "syntax"

echo ""; echo "PASSED=$PASS FAILED=$FAIL"
[[ $FAIL -eq 0 ]]