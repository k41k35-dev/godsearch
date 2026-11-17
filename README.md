# Exploit Search Aggregator — CLI Vulnerability Intelligence & Advisory Search

A high-performance, cross-platform command-line vulnerability intelligence and advisory aggregator designed for security researchers, system auditors, and authorized penetration testers.

It simultaneously queries, correlates, and prioritizes vulnerability advisories, security research publications, and Proof of Concept (PoC) validation scripts across multiple authoritative repositories on **macOS (Darwin)** and **Linux (Kali, Debian/Ubuntu, Arch, Fedora)**.

---

## Architecture & Feeds

The aggregator queries multiple intelligence feeds concurrently to provide unified, deduplicated results:

* **Exploit-DB**: Local database indexing via `searchsploit` with automatic path resolution across operating systems.
* **GitHub Advisory & PoC Repositories**: Real-time query via GitHub CLI (`gh`).
* **Metasploit Framework**: Direct filesystem indexing of local modules (bypasses database overhead) across standard Linux and macOS framework locations.
* **Nuclei Templates**: Local directory scans for automated security validation templates.
* **PacketStorm Security**: Online security advisory and disclosure repository.
* **MITRE CVE Services**: Real-time CVE enrichment (CVSS v3.x/v2.0 severity rating, description, and CNA state).

---

## Cross-Platform Capabilities

GodSearch dynamically adapts to the host operating system at runtime:

| Feature | 🍏 macOS (Darwin) | 🐧 Linux (Wayland / X11) |
| :--- | :--- | :--- |
| **Exploit-DB (`searchsploit`)** | `/opt/homebrew/bin`, `/usr/local/bin`, or `$PATH` | `/usr/bin/searchsploit`, `$PATH` |
| **Metasploit Modules Base** | `/opt/metasploit-framework/...`, Homebrew | `/usr/share/metasploit-framework/modules` |
| **Clipboard Integration** | `pbcopy` | `wl-copy` (Wayland), `xclip` / `xsel` (X11) |
| **URL & Advisory Opener** | `open` | `xdg-open` |
| **Preview Syntax Highlighting** | `bat`, `pygmentize` | `batcat` (Debian/Ubuntu), `bat` (Arch/Fedora), `pygmentize` |
| **Hash & Timestamp Utilities** | BSD `md5`, BSD `stat -f %m` | GNU `md5sum`, GNU `stat -c %Y` |

---

## Prerequisites & Installation

### Automated Setup (Recommended)

Run the included cross-platform installer to audit your environment and set up binaries and aliases:

```bash
git clone https://github.com/k41k35-dev/godsearch.git
cd godsearch

# Run the environment doctor to verify dependencies
./install.sh --check-only

# Install godsearch to ~/.local/bin/godsearch
./install.sh --install-bin
```

---

### 🍏 macOS Setup (Homebrew)

Install core tools and optional syntax and intelligence feeds:

```bash
# Core dependencies
brew install fzf jq bc curl git

# Recommended search engines & enhancements
brew install exploitdb gh bat pygments
```

---

### 🐧 Linux Setup

#### Kali Linux / Debian / Ubuntu
```bash
sudo apt update
sudo apt install -y fzf jq bc curl git exploitdb gh xclip python3-pygments bat

# Note: On Debian/Ubuntu systems, the 'bat' executable is installed as 'batcat'
# GodSearch detects and supports both automatically.
```

#### Arch Linux / Manjaro
```bash
sudo pacman -S --needed fzf jq bc curl git exploitdb github-cli xclip python-pygments bat
```

#### Fedora / RHEL
```bash
sudo dnf install -y fzf jq bc curl git gh xclip python3-pygments bat
```

---

## Environment Configuration

Configure custom paths and runtime parameters using environment variables in your shell profile (`~/.zshrc` or `~/.bashrc`):

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `EXPLOIT_OUTPUT_DIR` | `./exploits` | Destination directory where mirrored PoCs and downloaded assets are saved |
| `SEARCHSPLOIT_BIN` | Auto-detected | Explicit override path to the `searchsploit` executable |
| `MSF_MODULES_PATH` | Auto-detected | Explicit override directory for local Metasploit modules (`modules/` root) |
| `NUCLEI_TEMPLATES` | `$HOME/nuclei-templates` | Path to Nuclei vulnerability templates repository |

---

## Key Features

* **Parallel Multi-Source Execution**: Dispatches search jobs across all local and remote engines concurrently.
* **Merit-Based Impact Scoring**: Employs a weighted classification engine:
  * Prioritizes Remote Code Execution (RCE) and Authentication Bypasses (Tier A).
  * Evaluates functional validation scripts (`.py`, `.sh`, `.rb`) over static documentation.
  * Word-boundary tokenization eliminates substring false positives (e.g. distinguishes "rce" from "resource" or "force").
* **Noise Reduction**: Automatically filters Denial of Service (DoS), crash reports, and self-XSS noise to surface actionable advisories.
* **Target Platform Filtering**: Interactive platform targeting (Linux/Unix, Windows, All) or automated evaluation.
* **Automated Mode (`--auto`)**: Selects and retrieves the highest-ranked validation asset directly without interactive prompts (ideal for automated security pipelines).
* **Intelligent Query Caching**: Results are cached locally (1-hour TTL) to minimize redundant network queries and prevent API rate limiting.
* **Interactive Terminal UI**: Powered by `fzf` with full syntax preview, live details, and clipboard integration.

---

## Usage Examples

### 1. Interactive Search
Provide software names, service banners, or specific version strings:
```bash
./godsearch.sh "OpenSSH 8.5"
```

### 2. Direct CVE Lookup (with MITRE CVSS Enrichment)
```bash
./godsearch.sh CVE-2021-44228
```

### 3. Automated Acquisition Mode
Instantly retrieves the highest-scoring advisory/PoC script to the output directory without launching the interactive interface:
```bash
./godsearch.sh "ProFTPD 1.3.5" --auto
```

### 4. Pass-Through to Native Searchsploit
Any standard searchsploit flags (`-m`, `-p`, `--nmap`, etc.) pass directly to the native binary:
```bash
./godsearch.sh -p 49757
```

---

## Interface Navigation

* `Up` / `Down` : Navigate the ranked results list.
* `Enter` : Select item and launch the contextual acquisition/inspection prompt.
* `Esc` / `Ctrl+C` : Cancel and exit.

---

## Legal & Ethical Disclaimer

**FOR EDUCATIONAL, RESEARCH, AND AUTHORIZED SECURITY AUDITING ONLY.**

This tool is provided solely for academic research, defensive vulnerability assessment, and authorized security testing. Performing security scans or validation against systems without prior, explicit, and mutual consent is strictly illegal and subject to criminal prosecution. The developers assume no liability and are not responsible for any misuse, damage, or legal violations resulting from the use of this software.
