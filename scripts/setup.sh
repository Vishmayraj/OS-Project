#!/bin/bash
# =============================================================
#  setup.sh  --  Victim Machine (VM1 | 192.168.98.4)
#  Docker Escape Demo | GTU-SET Semester 4
#  Run this ONCE from the repo root after cloning.
# =============================================================

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

banner() { echo -e "\n${YELLOW}[*] $1${NC}"; }
ok()     { echo -e "${GREEN}[+] $1${NC}"; }
err()    { echo -e "${RED}[-] $1${NC}"; exit 1; }

echo ""
echo -e "${YELLOW}  Docker Escape Demo -- Host Setup${NC}"
echo -e "${YELLOW}  VM1 (Victim) | 192.168.98.4${NC}"
echo ""

# -- 1. Check required files -----------------------------------
banner "Checking for required files..."

[ -f "./host/app.py" ]     || err "host/app.py not found. Are you running this from the repo root?"
[ -f "./host/Dockerfile" ] || err "host/Dockerfile not found. Are you running this from the repo root?"

ok "app.py found"
ok "Dockerfile found"

# -- 2. Check Docker -------------------------------------------
banner "Checking Docker..."

if ! command -v docker &>/dev/null; then
    banner "Docker not found -- installing..."
    apt-get update -qq && apt-get install -y docker.io
    systemctl enable --now docker
    ok "Docker installed and started"
else
    ok "Docker already installed: $(docker --version)"
fi

# -- 3. Build the vulnerable image -----------------------------
banner "Building NetDiag Docker image..."
docker build -t netdiag ./host/ && ok "Image 'netdiag' built successfully"

# -- 4. Stop any old container ---------------------------------
if docker ps -a --format '{{.Names}}' | grep -q "^netdiag-app$"; then
    banner "Removing old netdiag-app container..."
    docker rm -f netdiag-app
fi

# -- 5. Run with the intentional misconfiguration --------------
banner "Starting NetDiag container (with docker.sock mount)..."
docker run -d \
    -p 5000:5000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --name netdiag-app \
    netdiag

ok "Container running!"

# -- 6. Done ---------------------------------------------------
echo ""
echo -e "${GREEN}Setup complete. NetDiag is LIVE.${NC}"
echo ""
echo -e "  App URL  : ${YELLOW}http://192.168.98.4:5000${NC}"
echo -e "  Vuln URL : ${YELLOW}http://192.168.98.4:5000/ping?host=8.8.8.8;id${NC}"
echo ""
echo -e "  Attacker should now run ${YELLOW}attack.sh${NC} on VM2."
echo ""