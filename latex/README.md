# Context

Everything here was compiled on Overleaf - An online latex editor, and this is the source code just for safety purposes

## Description

### Docker Escape: Attack and Detection
**OS & Cybersecurity Project Report | Semester 4 | GTU-SET**

Table of Contents
Chapter 1: Introduction
1.1 Project Overview
1.2 Objectives
1.3 Lab Environment Summary
1.4 Scope and Limitations
1.5 Ethical Disclaimer

Chapter 2: Operating System Foundations
2.1 The Linux Kernel and Its Role
2.2 System Calls (syscalls) - The Kernel Interface
2.3 Process Isolation and the Process Table
2.4 Linux Namespaces - The Core of Container Isolation

2.4.1 PID Namespace
2.4.2 Network Namespace
2.4.3 Mount Namespace
2.4.4 UTS Namespace
2.4.5 IPC Namespace
2.4.6 User Namespace
2.5 Control Groups (cgroups) - Resource Enforcement
2.6 Capabilities - Fine-Grained Privilege Model
2.7 Seccomp - Syscall Filtering
2.8 AppArmor and LSMs
2.9 The /proc Filesystem
2.10 How the Kernel Sees a Container vs a Process


Chapter 3: Docker - Architecture and Internals
3.1 What Docker Is (and Is Not)
3.2 Docker vs Traditional VMs - A Kernel-Level Comparison
3.3 The Docker Daemon (dockerd)
3.4 containerd and runc
3.5 The OCI Runtime Specification
3.6 How docker run Becomes a Process - Full Syscall Flow
3.7 Docker Images and Layers (OverlayFS)
3.8 Docker Networking Internals (bridge, iptables, veth pairs)
3.9 Docker Volumes and Bind Mounts
3.10 The Docker CLI and REST API

Chapter 4: The Docker Socket
4.1 What is a Unix Domain Socket
4.2 /var/run/docker.sock - What It Is and How It Works
4.3 Why Applications Mount the Socket (Legitimate Use Cases)

4.3.1 CI/CD Pipelines
4.3.2 Container Management UIs (Portainer, Watchtower)
4.3.3 Monitoring Agents
4.4 The Danger: What Socket Access Actually Grants
4.5 The Docker API Over the Socket - Curl Examples
4.6 Root Equivalence - Why Socket Access = Host Root


Chapter 5: The NetDiag Web Application
5.1 Application Purpose and Design
5.2 Flask and the WSGI Model
5.3 Route Structure and Request Handling
5.4 The Vulnerable /ping Route - Code Walkthrough
5.5 Why os.popen() is Dangerous
5.6 The HTML Template - UI Breakdown
5.7 Running as Root Inside the Container

Chapter 6: The Dockerfile and Container Configuration
6.1 Dockerfile Walkthrough Line by Line
6.2 Base Image Choice
6.3 Running as Root - Why This Matters
6.4 Port Exposure
6.5 The Intentional Misconfiguration in docker run

Chapter 7: Remote Code Execution (RCE)
7.1 What is RCE
7.2 Command Injection as a Class of Vulnerability
7.3 The Injection Point in NetDiag
7.4 Shell Metacharacters - How ; Breaks the Command
7.5 Confirming Execution via id
7.6 Why the Response Leaks to the Browser
7.7 OS-Level View - What Happens When the Shell Runs

Chapter 8: The Full Attack Chain
8.1 Overview of the Chain
8.2 Step 1 - Confirming RCE (8.8.8.8;id)
8.3 Step 2 - Establishing a Reverse Shell

8.3.1 What a Reverse Shell Is
8.3.2 The Bash TCP Redirect Technique
8.3.3 Netcat Listener Setup
8.3.4 Shell Stabilization with PTY
8.4 Step 3 - Enumerating the Container
8.5 Step 4 - Finding and Abusing docker.sock
8.6 Step 5 - Installing Docker CLI Inside the Container
8.7 Step 6 - Spawning a Privileged Container with Host Root Mounted
8.8 Step 7 - Writing to the Host Filesystem
8.9 Kernel-Level View of the Escape
8.10 Why This Is Not a Kernel Exploit


Chapter 9: Script Documentation
9.1 setup.sh - Full Walkthrough

9.1.1 Dependency Checks
9.1.2 Docker Build Flow
9.1.3 The Misconfigured docker run Command
9.2 attack.sh - Full Walkthrough
9.2.1 RCE Confirmation via curl
9.2.2 Reverse Shell Automation
9.2.3 Post-Exploitation Instruction Block
9.3 detect.sh - Full Walkthrough
9.3.1 Checking for the Escape Artifact
9.3.2 Inspecting Mounts with docker inspect
9.3.3 Setting Up auditd Rules
9.3.4 Parsing Audit Logs
9.3.5 Live Socket Monitoring with lsof


Chapter 10: Detection Techniques
10.1 Host-Based Indicators of Compromise
10.2 docker inspect for Mount Auditing
10.3 auditd - Architecture and Rule System
10.4 ausearch and Log Interpretation
10.5 lsof for Live Process Inspection
10.6 Falco - Rule-Based Runtime Detection
10.7 Building a Detection Checklist

Chapter 11: Mitigation and Hardening
11.1 Never Mount docker.sock in Production
11.2 Docker Socket Proxy (Tecnativa)
11.3 Rootless Docker
11.4 Podman as a Daemonless Alternative
11.5 Fixing the Code - subprocess.run() vs os.popen()
11.6 Input Validation and Allowlisting
11.7 Running Containers as Non-Root
11.8 Read-Only Filesystems
11.9 Seccomp and AppArmor Profiles for Docker
11.10 Network Segmentation

Chapter 12: Threat Modeling
12.1 STRIDE Analysis of the Lab Environment
12.2 Attack Surface Mapping
12.3 Risk Matrix

Chapter 13: Comparison with Real-World Incidents
13.1 Similar CVEs and Documented Escapes
13.2 Docker in CI/CD Pipelines - Why This Pattern Is Common
13.3 Cloud Metadata Abuse as a Related Vector

Chapter 14: Conclusion
14.1 What Was Demonstrated
14.2 Key Takeaways
14.3 Further Reading

Appendices
A. Full Source Code Listings
B. Glossary of Terms
C. References
