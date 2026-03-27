#!/bin/bash
# =============================================================
#  detect.sh  -  Victim Machine (VM1 | 192.168.98.4)
#  Docker Escape Demo | GTU-SET Semester 4
#  Run AFTER the attack to demonstrate detection techniques.
# =============================================================

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

banner() { echo -e "\n${YELLOW}== $1 ==${NC}"; }
ok()     { echo -e "${GREEN}[+] $1${NC}"; }
warn()   { echo -e "${RED}[!] $1${NC}"; }
info()   { echo -e "${CYAN}    $1${NC}"; }

echo ""
echo -e "${CYAN}  Docker Escape Demo -- Detection${NC}"
echo -e "${CYAN}  VM1 (Host) | 192.168.98.4${NC}"
echo ""

# - CHECK 1: Proof of compromise ---------------
banner "CHECK 1 - Proof of Host Compromise"
info "Looking for /tmp/escaped.txt written from inside the container..."
echo ""

if [ -f /tmp/escaped.txt ]; then
    warn "HOST IS COMPROMISED"
    echo -e "    Contents of /tmp/escaped.txt: ${RED}$(cat /tmp/escaped.txt)${NC}"
else
    ok "No escape artifact found (attack may not have completed yet)"
fi

# - CHECK 2: Inspect mounts ------------------
banner "CHECK 2 - Inspect Container Mounts"
info "docker inspect netdiag-app | grep -A 5 Mounts"
echo ""

if docker inspect netdiag-app &>/dev/null; then
    MOUNTS=$(docker inspect netdiag-app | python3 -c "
import sys, json
data = json.load(sys.stdin)
mounts = data[0].get('Mounts', [])
for m in mounts:
    print('  Source :', m.get('Source'))
    print('  Dest   :', m.get('Destination'))
    print()
" 2>/dev/null)

    echo "$MOUNTS"

    if echo "$MOUNTS" | grep -q "docker.sock"; then
        warn "docker.sock IS mounted inside the container - critical misconfiguration!"
    else
        ok "docker.sock is NOT mounted (looks safe)"
    fi
else
    warn "Container 'netdiag-app' not found. Is it running?"
fi

# - CHECK 3: auditd ----------------------
banner "CHECK 3 - auditd: Monitor docker.sock Access"
info "Setting up audit rule for /var/run/docker.sock..."
echo ""

if ! command -v auditctl &>/dev/null; then
    info "auditd not installed. Installing..."
    apt-get install -y auditd -qq && systemctl enable --now auditd
fi

auditctl -w /var/run/docker.sock -p rwxa -k docker_sock 2>/dev/null && \
    ok "Audit rule set: any r/w/x/a on docker.sock will be logged with key 'docker_sock'"

echo ""
info "Searching existing audit logs for docker.sock access..."
echo ""
AUDIT_HITS=$(ausearch -k docker_sock 2>/dev/null | tail -20)

if [ -n "$AUDIT_HITS" ]; then
    warn "Audit hits found:"
    echo "$AUDIT_HITS"
else
    info "No past audit hits (rule was just added - future access will be logged)"
fi

# - CHECK 4: Running containers ----------------
banner "CHECK 4 - All Running Containers"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

# - CHECK 5: Suspicious docker.sock processes ---------
banner "CHECK 5 - Processes Accessing docker.sock Right Now"
echo ""
PROCS=$(lsof /var/run/docker.sock 2>/dev/null)
if [ -n "$PROCS" ]; then
    warn "These processes currently have docker.sock open:"
    echo "$PROCS"
else
    ok "No processes currently accessing docker.sock (besides dockerd itself)"
fi

# - Summary --------------------------
echo ""
echo -e "${YELLOW}======================================================${NC}"
echo -e "${YELLOW}  Detection Summary${NC}"
echo -e "${YELLOW}======================================================${NC}"
echo ""
echo -e "  ${CYAN}Tool       ${NC}| ${CYAN}What it caught${NC}"
echo    "  -----------|------------------------------------------"
echo    "  docker inspect | docker.sock bind-mount (misconfiguration)"
echo    "  auditd     | Any process touching docker.sock (ongoing)"
echo    "  lsof       | Live processes with socket handle open"
echo    "  Falco*     | 'Sensitive mount' + 'Container escape' rules"
echo ""
echo    "  * Falco not installed in this demo but recommended for prod."
echo ""
echo -e "${GREEN}  Mitigation: Remove -v /var/run/docker.sock from docker run${NC}"
echo -e "${GREEN}  and fix app.py to use subprocess.run() instead of os.popen()${NC}"
echo ""