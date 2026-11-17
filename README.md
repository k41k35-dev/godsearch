# Exploit Search Aggregator — CLI Vulnerability Intelligence & Advisory Search

A high-performance command-line vulnerability intelligence and advisory aggregator designed for security researchers, system auditors, and authorized penetration testers.

It simultaneously queries, correlates, and prioritizes vulnerability advisories, security research publications, and Proof of Concept (PoC) validation scripts across multiple authoritative repositories.

---

## Architecture & Sources

The aggregator queries multiple intelligence feeds concurrently to provide unified, deduplicated results:

* **Exploit-DB**: Local database indexing via `searchsploit`.
* **GitHub Advisory & PoC Repositories**: Real-time query via GitHub CLI (`gh`).
* **Metasploit Framework**: Direct filesystem indexing of local modules (bypasses database overhead).
* **Nuclei Templates**: Local directory scans for automated security validation templates.
* **PacketStorm Security**: Online security advisory and disclosure repository.
* **MITRE CVE Services**: Real-time CVE enrichment (CVSS v3.x/v2.0 severity rating, description, and CNA state).

---

## Key Features

* **Parallel Multi-Source Execution**: Dispatches search jobs across all local and remote engines concurrently.
* **Merit-Based Impact Scoring**: Employs a weighted classification engine:
  * Prioritizes Remote Code Execution (RCE) and Authentication Bypasses (Tier A).
  * Evaluates functional validation scripts (`.py`, `.sh`, `.rb`) over static documentation.
  * Word-boundary tokenization eliminates substring false positives (e.g. distinguishes "rce" from "resource" or "force").
* **Noise Reduction**: Automatically filters Denial of Service (DoS), crash reports, and self-XSS noise to surface actionable advisories.
* **Target Platform Filtering**: Interactive platform targeting (Linux/Unix, Windows, All) or automated evaluation.
* **Automated Mode (`--auto`)**: Selects and retrieves the highest-ranked validation asset directly without interactive prompts (ideal for scripting and assessment workflows).
* **Intelligent Query Caching**: Results are cached locally (1-hour TTL) to minimize redundant network queries and prevent API rate limiting.
* **Interactive Terminal UI**: Powered by `fzf` with full syntax preview, live details, and clipboard integration.

---

## Prerequisites

Ensure the following tools are installed and available in your `PATH`:

* `bash` (4.0+)
* `curl` & `jq`
* `bc` (for CVSS calculation)
* `fzf` (command-line fuzzy finder)

### Optional Integrations

* `searchsploit` — Exploit-DB command-line search utility.
* `gh` — GitHub CLI (requires active session via `gh auth login`).
* `nuclei` & `nuclei-templates` — For Nuclei template detection.
* `metasploit-framework` — Local Metasploit module base.
* `xclip` / `pbcopy` / `wl-copy` — Clipboard integration across Linux (X11/Wayland) and macOS.

---

## Environment Configuration

Configure the aggregator behavior through environment variables:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `EXPLOIT_OUTPUT_DIR` | `./exploits` | Target directory where PoCs and modules are mirrored/cloned |
| `SEARCHSPLOIT_BIN` | `searchsploit` | Path to the local `searchsploit` binary |
| `MSF_MODULES_PATH` | `/opt/metasploit-framework/embedded/framework/modules` | Root directory for local Metasploit modules |
| `NUCLEI_TEMPLATES` | `$HOME/nuclei-templates` | Path to Nuclei vulnerability templates repository |

---

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/k41k35-dev/godsearch.git
   cd godsearch
   ```

2. Make the script executable:
   ```bash
   chmod +x godsearch.sh
   ```

3. (Optional) Set a persistent alias in your shell configuration (`~/.zshrc` or `~/.bashrc`):
   ```bash
   alias godsearch="/path/to/godsearch.sh"
   ```

---

## Usage Examples

### Interactive Search
Provide software names, service banners, or specific version strings:
```bash
./godsearch.sh "OpenSSH 8.5"
```

### Direct CVE Lookup (with MITRE CVSS Enrichment)
```bash
./godsearch.sh CVE-2021-44228
```

### Automated Acquisition Mode
Instantly retrieves the highest-scoring advisory/PoC script to the output directory without launching the interactive interface:
```bash
./godsearch.sh "ProFTPD 1.3.5" --auto
```

### Pass-Through to Native Searchsploit
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
