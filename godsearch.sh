#!/usr/bin/env bash

# =============================================================================
# Exploit Search Aggregator — CLI Vulnerability Intelligence & Advisory Search
# Unified multi-source vulnerability intelligence search engine:
# MSF | Nuclei | GitHub PoCs | Exploit-DB | PacketStorm | CVE Enrichment
# Cross-Platform: macOS (Darwin) & Linux (Debian/Kali/Ubuntu, Arch, Fedora)
# =============================================================================

QUERY=""
AUTO_MODE=0

# ─── PLATFORM & BINARY RESOLUTION ───────────────────────────────────────────
OS_TYPE="$(uname -s)"

# 1. Exploit-DB / searchsploit resolution
REAL_SEARCHSPLOIT=""
if [[ -n "$SEARCHSPLOIT_BIN" ]] && (command -v "$SEARCHSPLOIT_BIN" >/dev/null 2>&1 || [[ -x "$SEARCHSPLOIT_BIN" ]]); then
    REAL_SEARCHSPLOIT="$SEARCHSPLOIT_BIN"
elif command -v searchsploit >/dev/null 2>&1; then
    REAL_SEARCHSPLOIT="$(command -v searchsploit)"
elif [[ -x "/opt/homebrew/bin/searchsploit" ]]; then
    REAL_SEARCHSPLOIT="/opt/homebrew/bin/searchsploit"
elif [[ -x "/usr/local/bin/searchsploit" ]]; then
    REAL_SEARCHSPLOIT="/usr/local/bin/searchsploit"
elif [[ -x "/usr/bin/searchsploit" ]]; then
    REAL_SEARCHSPLOIT="/usr/bin/searchsploit"
else
    REAL_SEARCHSPLOIT="searchsploit"
fi

# 2. Metasploit Framework Modules directory resolution
MSF_MODULES_BASE=""
if [[ -n "$MSF_MODULES_PATH" && -d "$MSF_MODULES_PATH" ]]; then
    MSF_MODULES_BASE="$MSF_MODULES_PATH"
elif [[ -d "/usr/share/metasploit-framework/modules" ]]; then
    # Standard Linux / Kali / Debian
    MSF_MODULES_BASE="/usr/share/metasploit-framework/modules"
elif [[ -d "/opt/metasploit-framework/embedded/framework/modules" ]]; then
    # Omnibus package installer (macOS & Linux)
    MSF_MODULES_BASE="/opt/metasploit-framework/embedded/framework/modules"
elif [[ -d "/opt/homebrew/opt/metasploit-framework/embedded/framework/modules" ]]; then
    # Homebrew macOS (Apple Silicon)
    MSF_MODULES_BASE="/opt/homebrew/opt/metasploit-framework/embedded/framework/modules"
elif [[ -d "/usr/local/opt/metasploit-framework/embedded/framework/modules" ]]; then
    # Homebrew macOS (Intel)
    MSF_MODULES_BASE="/usr/local/opt/metasploit-framework/embedded/framework/modules"
fi

# 3. Nuclei Templates path
NUCLEI_TEMPLATES="${NUCLEI_TEMPLATES:-$HOME/nuclei-templates}"

# 4. Syntax Highlighting in fzf preview
BAT_CMD=""
if command -v batcat >/dev/null 2>&1; then
    BAT_CMD="batcat --color=always --style=plain"
elif command -v bat >/dev/null 2>&1; then
    BAT_CMD="bat --color=always --style=plain"
elif command -v pygmentize >/dev/null 2>&1; then
    BAT_CMD="pygmentize -g"
else
    BAT_CMD="cat"
fi

# 5. Output directory
EXPLOIT_DIR="${EXPLOIT_OUTPUT_DIR:-./exploits}"

# Parse flags: extract --auto before building QUERY
for arg in "$@"; do
    if [[ "$arg" == "--auto" ]]; then
        AUTO_MODE=1
    else
        QUERY="$QUERY $arg"
    fi
done
QUERY=$(echo "$QUERY" | xargs)  # Trim leading/trailing whitespace

# Pass-through for searchsploit native flags (e.g. -m, -p, --nmap, etc.)
if [[ "$1" == -* && "$1" != "--auto" ]]; then
    if command -v "$REAL_SEARCHSPLOIT" >/dev/null 2>&1 || [[ -x "$REAL_SEARCHSPLOIT" ]]; then
        exec "$REAL_SEARCHSPLOIT" "$@"
    else
        echo "Error: searchsploit binary not found ($REAL_SEARCHSPLOIT)" >&2
        exit 1
    fi
fi

# Non-TTY pass-through only if not in auto mode. In --auto we skip fzf and output plain text.
if [[ ! -t 1 && "$AUTO_MODE" == 0 ]]; then
    if command -v "$REAL_SEARCHSPLOIT" >/dev/null 2>&1 || [[ -x "$REAL_SEARCHSPLOIT" ]]; then
        exec "$REAL_SEARCHSPLOIT" "$@"
    else
        echo "Error: searchsploit binary not found for non-interactive pass-through" >&2
        exit 1
    fi
fi

# ─── THEME & VISUAL ICONS ───────────────────────────────────────────────────
MAGENTA='\033[1;35m'; CYAN='\033[1;36m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; GREEN='\033[1;32m'; BOLD='\033[1m'; NC='\033[0m'; D='\033[1;30m'
ICON_LOCAL="💀"; ICON_GITHUB="🐙"; ICON_NUCLEI="🧬"; ICON_MSF="💣"; ICON_RCE="🔥"; ICON_POC="🎯"; ICON_AUTH="🔐"; ICON_PKST="📡"

# ─── CROSS-PLATFORM SYSTEM UTILITIES ─────────────────────────────────────────

copy_to_clipboard() {
    local text="$1"
    if command -v pbcopy >/dev/null 2>&1; then
        echo -n "$text" | pbcopy
        return 0
    elif [[ -n "$WAYLAND_DISPLAY" ]] && command -v wl-copy >/dev/null 2>&1; then
        echo -n "$text" | wl-copy
        return 0
    elif command -v wl-copy >/dev/null 2>&1; then
        echo -n "$text" | wl-copy
        return 0
    elif command -v xclip >/dev/null 2>&1; then
        echo -n "$text" | xclip -selection clipboard
        return 0
    elif command -v xsel >/dev/null 2>&1; then
        echo -n "$text" | xsel --clipboard --input
        return 0
    else
        echo -e "${YELLOW}⚠ No clipboard utility found (pbcopy, wl-copy, xclip, xsel).${NC}"
        return 1
    fi
}

copy_clipboard() {
    copy_to_clipboard "$@"
}

open_url() {
    local url="$1"
    if command -v open >/dev/null 2>&1 && [[ "$OS_TYPE" == "Darwin" ]]; then
        open "$url" >/dev/null 2>&1 && return 0
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 && return 0
    elif command -v open >/dev/null 2>&1; then
        open "$url" >/dev/null 2>&1 && return 0
    elif command -v python3 >/dev/null 2>&1; then
        python3 -m webbrowser "$url" >/dev/null 2>&1 && return 0
    fi
    echo -e "${YELLOW}Open manually: ${CYAN}$url${NC}"
    return 1
}

if [ -z "$QUERY" ]; then 
    echo -e "${MAGENTA}Exploit Search Aggregator — Vulnerability Intelligence${NC}"
    echo -e "Usage: $(basename "$0") <query> [--auto]"
    echo -e "  ${D}--auto${NC}  Automatically fetch highest-scored advisory/PoC (non-interactive)"
    exit 0; 
fi

# ─── CACHING SYSTEM ─────────────────────────────────────────────────────────
CACHE_TTL=3600
CACHE_HASH=$( (echo -n "$QUERY" | md5sum 2>/dev/null || echo -n "$QUERY" | md5 2>/dev/null || echo -n "$QUERY" | shasum 2>/dev/null) | awk '{print $1}' )
CACHE_FILE="/tmp/godsearch_cache_${CACHE_HASH}.json"
CACHE_HIT=0

if [[ -f "$CACHE_FILE" ]]; then
    CACHE_MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    CACHE_AGE=$(( $(date +%s) - CACHE_MTIME ))
    if [[ "$CACHE_AGE" -ge 0 && "$CACHE_AGE" -lt "$CACHE_TTL" ]]; then
        CACHE_HIT=1
    else
        rm -f "$CACHE_FILE" 2>/dev/null
    fi
fi

# ─── CVE ENRICHMENT ──────────────────────────────────────────────────────────
CVE_FULL=$(echo "$QUERY" | grep -oEi "CVE-[0-9]{4}-[0-9]{4,}" | head -1)
CVE_HEADER=""
if [[ -n "$CVE_FULL" ]]; then
    CVE_INFO=$(curl -s --max-time 5 "https://cveawg.mitre.org/api/cve/${CVE_FULL}" 2>/dev/null)
    if [[ -n "$CVE_INFO" ]]; then
        CVE_DESC=$(echo "$CVE_INFO" | jq -r '.containers.cna.descriptions[0].value // empty' 2>/dev/null | head -c 200)
        # Try multiple CVSS paths (v3.1 first, then v3.0, then v2)
        CVE_CVSS=$(echo "$CVE_INFO" | jq -r '
            (.containers.cna.metrics[]? | .cvssV3_1.baseScore // .cvssV3_0.baseScore // .cvssV2_0.baseScore // empty) // empty
        ' 2>/dev/null | head -1)
        CVE_STATE=$(echo "$CVE_INFO" | jq -r '.cveMetadata.state // empty' 2>/dev/null)

        if [[ -n "$CVE_CVSS" ]]; then
            # Color-code CVSS score
            CVSS_COLOR="$GREEN"
            if command -v bc >/dev/null 2>&1; then
                if (( $(echo "$CVE_CVSS >= 9.0" | bc -l 2>/dev/null || echo 0) )); then CVSS_COLOR="$RED"
                elif (( $(echo "$CVE_CVSS >= 7.0" | bc -l 2>/dev/null || echo 0) )); then CVSS_COLOR='\033[1;33m'
                elif (( $(echo "$CVE_CVSS >= 4.0" | bc -l 2>/dev/null || echo 0) )); then CVSS_COLOR="$YELLOW"
                fi
            fi
            CVE_HEADER="  🛡️  ${CYAN}${CVE_FULL}${NC} │ CVSS: ${CVSS_COLOR}${CVE_CVSS}${NC} │ State: ${GREEN}${CVE_STATE}${NC}"
        fi
        if [[ -n "$CVE_DESC" ]]; then
            CVE_HEADER="${CVE_HEADER}\n  ${D}${CVE_DESC}${NC}"
        fi
    fi
fi

# PLATFORM SELECTION (skip in auto mode — default to linux)
if [[ "$AUTO_MODE" == 1 ]]; then
    PLATFORM_REQ="linux"; PLATFORM_LABEL="linux"
else
    echo -e "${MAGENTA}Target Platform Selection${NC}"
    echo -e "  ${D}[1]${NC} 🐧 Linux/Unix (Default)"
    echo -e "  ${D}[2]${NC} 🪟 Windows"
    echo -e "  ${D}[3]${NC} 🌎 All (No Filter)"
    echo -ne "\n${YELLOW}❯ Selection [1]: ${NC}"
    read -r choice

    case "$choice" in
        2) PLATFORM_REQ="windows"; PLATFORM_LABEL="windows" ;;
        3) PLATFORM_REQ="all"; PLATFORM_LABEL="all" ;;
        *) PLATFORM_REQ="linux"; PLATFORM_LABEL="linux" ;;
    esac
fi

clear
echo -e "${MAGENTA}Auditing attack surface for: ${BOLD}$QUERY${NC} [Smart Filter: ${CYAN}$PLATFORM_LABEL${NC}]..."
# Display CVE enrichment header if available
[[ -n "$CVE_HEADER" ]] && echo -e "$CVE_HEADER"

TMP_DIR="/tmp/godsearch_$$"
mkdir -p "$TMP_DIR" "$EXPLOIT_DIR" 2>/dev/null
COMBINED_RAW="$TMP_DIR/combined.raw"
touch "$COMBINED_RAW"

QUERY_CLEAN=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
CVE_PATTERN=$(echo "$QUERY" | grep -oE "[0-9]{4}-[0-9]{4,}")
VARIATIONS=$(echo -e "$QUERY_CLEAN\n${QUERY_CLEAN// /}\n${QUERY_CLEAN// /_}" | sort -u)

calculate_merit() {
    local t=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local s="$2"
    local p=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    local v="$4"
    local sc=0; local r="D"; local pl="multi"

    # Normalization for full-word matching
    local tn=" $(echo "$t" | tr -c 'a-z0-9' ' ') "
    local pn=" $(echo "$p" | tr -c 'a-z0-9.' ' ') "
    has() { [[ "$tn" == *" $1 "* ]]; }
    hasp() { [[ "$pn" == *"$1"* ]]; }

    # Noise reduction
    if has dos || has denial || has crash; then echo "0|SUP|none"; return; fi
    if has "self xss" || [[ "$tn" == *" self-xss "* ]]; then echo "0|SUP|none"; return; fi

    # Impact scoring tiers
    if has rce || has "remote code execution" || has "code execution" || has "command execution" || has "command injection" || has r015; then
        sc=9000; r="A"
    elif has "auth bypass" || has "authentication bypass" || has authbypass || has unauthenticated || has unauth || has unauthorized || has "auth bypass"; then
        sc=8000; r="A"
    elif has "file upload" || has fileupload || has upload || has sqli || has "sql injection" || has injection; then
        sc=6000; r="B"
    elif has privesc || has "privilege escalation" || has "local privilege escalation" || has lpe || has root; then
        sc=5000; r="C"
    elif has lfi || has rfi || has inclusion || has traversal || has "directory traversal"; then
        sc=4000; r="C"
    elif has info || has disclosure || has leak || has "information disclosure"; then
        sc=2000; r="D"
    else
        sc=1000; r="D"
    fi

    # Quality & reliability boosts
    if [[ -n "$CVE_PATTERN" && "$tn" == *" $CVE_PATTERN "* ]]; then ((sc += 900)); fi
    { [[ "$v" == "1" ]] || has verified; } && ((sc += 300))
    if has critical; then ((sc += 400)); elif has high; then ((sc += 200)); fi
    if hasp .py || hasp .sh || hasp .rb; then ((sc += 700))
    elif hasp .php || hasp .pl || hasp .js || hasp .c || hasp .yaml; then ((sc += 300)); fi

    # Platform detection
    local is_win=0; local is_lin=0; local is_web=0; local is_mac=0
    if hasp .php || hasp .js || hasp .aspx || hasp .asp || hasp .jsp || hasp .html || hasp .txt \
       || has wordpress || has joomla || has drupal || has web || has http \
       || has "sql injection" || has xss || has lfi || has rfi || has upload; then is_web=1; fi
    if hasp .exe || hasp .dll || hasp .msi || hasp .ps1 || hasp .vbs || hasp .bat \
       || has windows || has win32 || has win64 || has "ms-sql" || has iis || has csharp \
       || has "active directory" || has smb || has rdp || has powershell || has bluekeep \
       || has eternalblue || has winrm || has system32 || has ntlm || has kerberos \
       || has mimikatz || has mssql; then is_win=1; fi
    if hasp .sh || hasp .bash || has linux || has unix || has solaris || has bsd \
       || has debian || has ubuntu || has centos || has fedora || has redhat \
       || has kernel || has sudo || has cron || has apache || has nginx || has bash \
       || has ssh || has suid || has systemd || has polkit || has pkexec; then is_lin=1; fi
    if has macos || has osx || has darwin || has apple || has xcode || has launchd || has dylib; then is_mac=1; fi

    if ((is_win == 1 && is_lin == 0 && is_mac == 0)); then pl="windows"
    elif ((is_lin == 1 && is_win == 0)); then pl="linux"
    elif ((is_mac == 1 && is_win == 0)); then pl="macos"
    elif ((is_web == 1)); then pl="web"
    else pl="multi"
    fi

    # Permissive filtering
    if [[ "$is_web" == 0 ]]; then
        if [[ "$PLATFORM_REQ" == "linux" && "$pl" == "windows" ]]; then { echo "0|SUP|windows"; return; }; fi
        if [[ "$PLATFORM_REQ" == "windows" && "$pl" == "linux" ]]; then { echo "0|SUP|linux"; return; }; fi
    fi

    if [[ "$pl" == "$PLATFORM_REQ" ]]; then ((sc += 200))
    elif [[ "$pl" == "web" || "$pl" == "multi" ]]; then ((sc += 100))
    fi

    echo "$sc|$r|$pl"
}

search_local() {
    echo -ne "${CYAN}[i] local.db...   ${NC}"
    if ! command -v "$REAL_SEARCHSPLOIT" >/dev/null 2>&1 && ! [[ -x "$REAL_SEARCHSPLOIT" ]]; then
        echo -e "${YELLOW}SKIP (searchsploit not found)${NC}"
        return
    fi
    for var in $VARIATIONS; do
        "$REAL_SEARCHSPLOIT" -j "$var" --exclude="(/dos/|/papers/)" 2>/dev/null | jq -c '.RESULTS_EXPLOIT[]' 2>/dev/null | while read -r row; do
            T=$(echo "$row" | jq -r '.Title' 2>/dev/null); I=$(echo "$row" | jq -r '.["EDB-ID"]' 2>/dev/null); P=$(echo "$row" | jq -r '.Path' 2>/dev/null)
            V=$(echo "$row" | jq -r '.Verified' 2>/dev/null); C=$(echo "$row" | jq -r '.Codes' 2>/dev/null)
            M=$(calculate_merit "$T" "LOCAL" "$P" "$V")
            S=$(echo "$M" | cut -d'|' -f1); R=$(echo "$M" | cut -d'|' -f2); PL=$(echo "$M" | cut -d'|' -f3)
            if [ "$S" -gt 0 ] 2>/dev/null; then echo "$S|$R|LOC|$T|$I|$P|$V|$C|$PL" >> "$COMBINED_RAW"; fi
        done
    done
    echo -e "${GREEN}OK${NC}"
}

search_github() {
    echo -ne "${CYAN}[i] github...     ${NC}"
    if command -v gh >/dev/null 2>&1; then
        gh search repos "$QUERY" --limit 10 --json fullName,url,description 2>/dev/null | jq -c '.[]' 2>/dev/null | while read -r row; do
            N=$(echo "$row" | jq -r '.fullName' 2>/dev/null); U=$(echo "$row" | jq -r '.url' 2>/dev/null); D=$(echo "$row" | jq -r '.description' 2>/dev/null)
            M=$(calculate_merit "$N $D" "GITH" "$U" "0")
            S=$(echo "$M" | cut -d'|' -f1); R=$(echo "$M" | cut -d'|' -f2); PL=$(echo "$M" | cut -d'|' -f3)
            if [ "$S" -gt 0 ] 2>/dev/null; then echo "$S|$R|GITH|$N|$U|$U|$D||$PL" >> "$COMBINED_RAW"; fi
        done
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}SKIP (gh cli not found)${NC}"
    fi
}

search_msf() {
    echo -ne "${CYAN}[i] metasploit... ${NC}"
    if [[ -n "$MSF_MODULES_BASE" && -d "$MSF_MODULES_BASE" ]]; then
        grep -rliE "$QUERY" "$MSF_MODULES_BASE" --include="*.rb" 2>/dev/null | head -n 25 | while read -r module_path; do
            REL_NAME=$(echo "$module_path" | sed "s|$MSF_MODULES_BASE/||" | sed 's/\.rb$//')
            REL_NAME=$(echo "$REL_NAME" | sed -E 's|^exploits/|exploit/|; s|^payloads/|payload/|; s|^encoders/|encoder/|; s|^nops/|nop/|')
            
            DESC=$(grep -m 1 "'Name'" "$module_path" 2>/dev/null | awk -F"=>" '{print $2}' | sed -E "s/^[[:space:]]*['\"](.*)['\"],?/\1/" | xargs 2>/dev/null)
            [[ -z "$DESC" ]] && DESC=$(grep -m 1 '"Name"' "$module_path" 2>/dev/null | awk -F"=>" '{print $2}' | sed -E "s/^[[:space:]]*['\"](.*)['\"],?/\1/" | xargs 2>/dev/null)
            
            M=$(calculate_merit "$REL_NAME $DESC" "MSF" "$REL_NAME" "0")
            S=$(echo "$M" | cut -d'|' -f1); R=$(echo "$M" | cut -d'|' -f2); PL=$(echo "$M" | cut -d'|' -f3)
            if [ "$S" -gt 0 ] 2>/dev/null; then echo "$S|$R|MSF|$REL_NAME|$REL_NAME|$REL_NAME|$DESC||$PL" >> "$COMBINED_RAW"; fi
        done
        echo -e "${GREEN}OK${NC}"
    elif command -v msfconsole >/dev/null 2>&1; then
        local timeout_cmd=""
        if command -v timeout >/dev/null 2>&1; then
            timeout_cmd="timeout 10"
        elif command -v gtimeout >/dev/null 2>&1; then
            timeout_cmd="gtimeout 10"
        fi
        msf_res=$($timeout_cmd msfconsole -q -x "search type:exploit $QUERY; exit" 2>/dev/null | grep -E "^exploit/")
        while read -r line; do
            [ -z "$line" ] && continue
            T=$(echo "$line" | awk '{print $1}'); D=$(echo "$line" | cut -c 50-)
            M=$(calculate_merit "$T $D" "MSF" "$T" "0")
            S=$(echo "$M" | cut -d'|' -f1); R=$(echo "$M" | cut -d'|' -f2); PL=$(echo "$M" | cut -d'|' -f3)
            if [ "$S" -gt 0 ] 2>/dev/null; then echo "$S|$R|MSF|$T|$T|$T|$D||$PL" >> "$COMBINED_RAW"; fi
        done <<< "$msf_res"
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}SKIP (modules not found)${NC}"
    fi
}

search_nuclei() {
    echo -ne "${CYAN}[i] nuclei...     ${NC}"
    if [[ -d "$NUCLEI_TEMPLATES" ]]; then
        grep -rliE "$QUERY" "$NUCLEI_TEMPLATES" --include="*.yaml" 2>/dev/null | head -n 25 | while read -r template; do
            T=$(basename "$template" .yaml); P="$template"
            DESC=$(grep -m 1 "name:" "$template" 2>/dev/null | cut -d':' -f2- | xargs 2>/dev/null)
            SEV=$(grep -m 1 "severity:" "$template" 2>/dev/null | cut -d':' -f2- | xargs 2>/dev/null | tr '[:lower:]' '[:upper:]')
            M=$(calculate_merit "$T $DESC $SEV" "NUCL" "$P" "0")
            S=$(echo "$M" | cut -d'|' -f1); R=$(echo "$M" | cut -d'|' -f2); PL=$(echo "$M" | cut -d'|' -f3)
            if [ "$S" -gt 0 ] 2>/dev/null; then echo "$S|$R|NUCL|$T|$T|$P|$DESC ($SEV)||$PL" >> "$COMBINED_RAW"; fi
        done
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}SKIP (templates not found)${NC}"
    fi
}

search_packetstorm() {
    echo -ne "${CYAN}[i] packetstorm.. ${NC}"
    local ENCODED_QUERY
    if command -v python3 >/dev/null 2>&1; then
        ENCODED_QUERY=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY" 2>/dev/null || echo "$QUERY")
    else
        ENCODED_QUERY="$QUERY"
    fi
    local PKST_HTML
    PKST_HTML=$(curl -s --max-time 8 "https://packetstormsecurity.com/search/?q=${ENCODED_QUERY}" 2>/dev/null)
    
    if [[ -n "$PKST_HTML" ]]; then
        echo "$PKST_HTML" | grep -oE 'href="/files/[0-9]+/[^"]+\.html"' 2>/dev/null | head -10 | while read -r href_match; do
            local PKST_PATH=$(echo "$href_match" | sed 's/href="//;s/"$//')
            local PKST_URL="https://packetstormsecurity.com${PKST_PATH}"
            local PKST_TITLE=$(echo "$PKST_PATH" | sed 's|/files/[0-9]*/||;s|\.html$||' | tr '-' ' ' | tr '.' ' ')
            local PKST_ID=$(echo "$PKST_PATH" | grep -oE '[0-9]+' | head -1)
            
            M=$(calculate_merit "$PKST_TITLE" "PKST" "$PKST_URL" "0")
            S=$(echo "$M" | cut -d'|' -f1); R=$(echo "$M" | cut -d'|' -f2); PL=$(echo "$M" | cut -d'|' -f3)
            if [ "$S" -gt 0 ] 2>/dev/null; then echo "$S|$R|PKST|$PKST_TITLE|$PKST_ID|$PKST_URL|||$PL" >> "$COMBINED_RAW"; fi
        done
    fi
    echo -e "${GREEN}OK${NC}"
}

# ─── SEARCH EXECUTION ───────────────────────────────────────────────────────
if [[ "$CACHE_HIT" == 1 ]]; then
    echo -e "${GREEN}[⚡] Cache hit!${NC} Using cached results (age: ${CACHE_AGE}s / TTL: ${CACHE_TTL}s)"
    cp "$CACHE_FILE" "$COMBINED_RAW"
else
    search_local; search_github & search_msf & search_nuclei & search_packetstorm & wait
    if [[ -s "$COMBINED_RAW" ]]; then
        cp "$COMBINED_RAW" "$CACHE_FILE" 2>/dev/null
    fi
fi

if [ ! -s "$COMBINED_RAW" ]; then echo -e "${RED}✘ Nothing found.${NC}"; rm -rf "$TMP_DIR"; exit 1; fi

# ─── COUNT RESULTS BY SOURCE ────────────────────────────────────────────────
TOTAL_RESULTS=$(wc -l < "$COMBINED_RAW" | xargs)
LOC_COUNT=$(grep -c '|LOC|' "$COMBINED_RAW" 2>/dev/null || true); [[ -z "$LOC_COUNT" ]] && LOC_COUNT=0
GITH_COUNT=$(grep -c '|GITH|' "$COMBINED_RAW" 2>/dev/null || true); [[ -z "$GITH_COUNT" ]] && GITH_COUNT=0
MSF_COUNT=$(grep -c '|MSF|' "$COMBINED_RAW" 2>/dev/null || true); [[ -z "$MSF_COUNT" ]] && MSF_COUNT=0
NUCL_COUNT=$(grep -c '|NUCL|' "$COMBINED_RAW" 2>/dev/null || true); [[ -z "$NUCL_COUNT" ]] && NUCL_COUNT=0
PKST_COUNT=$(grep -c '|PKST|' "$COMBINED_RAW" 2>/dev/null || true); [[ -z "$PKST_COUNT" ]] && PKST_COUNT=0
echo -e "${D}── ${NC}${BOLD}${TOTAL_RESULTS}${NC} results ${D}│${NC} ${ICON_LOCAL} LOC:${LOC_COUNT} ${ICON_GITHUB} GH:${GITH_COUNT} ${ICON_MSF} MSF:${MSF_COUNT} ${ICON_NUCLEI} NUC:${NUCL_COUNT} ${ICON_PKST} PKT:${PKST_COUNT}"

# ─── AUTO MODE: Skip fzf, pick top result ────────────────────────────────────
if [[ "$AUTO_MODE" == 1 ]]; then
    TOP_LINE=$(sort -t'|' -k1 -nr "$COMBINED_RAW" | head -n 1)
    SOURCE=$(echo "$TOP_LINE" | awk -F'|' '{print $3}')
    TITLE=$(echo "$TOP_LINE" | awk -F'|' '{print $4}')
    ID=$(echo "$TOP_LINE" | awk -F'|' '{print $5}')
    PATH_VAL=$(echo "$TOP_LINE" | awk -F'|' '{print $6}')
    SCORE=$(echo "$TOP_LINE" | awk -F'|' '{print $1}')
    RANK=$(echo "$TOP_LINE" | awk -F'|' '{print $2}')

    echo -e "\n${MAGENTA}AUTO-SELECT${NC} │ Score: ${BOLD}$SCORE${NC} │ Rank: ${BOLD}$RANK${NC}"
    echo -e "   ${CYAN}$TITLE${NC} [${SOURCE}]"

    case "$SOURCE" in
        LOC)
            cd "$EXPLOIT_DIR" || exit
            if command -v "$REAL_SEARCHSPLOIT" >/dev/null 2>&1 || [[ -x "$REAL_SEARCHSPLOIT" ]]; then
                "$REAL_SEARCHSPLOIT" -m "$ID" > /dev/null 2>&1
            elif [[ -f "$PATH_VAL" ]]; then
                cp "$PATH_VAL" "$EXPLOIT_DIR/" 2>/dev/null
            fi
            echo -e "${GREEN}✔ [AUTO] Exploit $ID mirrored to $EXPLOIT_DIR${NC}"
            ;;
        GITH)
            cd "$EXPLOIT_DIR" || exit
            if [[ "$PATH_VAL" =~ \.(py|sh|rb|php|js)$ ]]; then
                RAW_URL=$(echo "$PATH_VAL" | sed 's/github.com/raw.githubusercontent.com/' | sed 's|/blob/|/|')
                curl -sO "$RAW_URL" 2>/dev/null
            else
                git clone "$PATH_VAL" --quiet 2>/dev/null
            fi
            echo -e "${GREEN}✔ [AUTO] GitHub repository cloned to $EXPLOIT_DIR${NC}"
            ;;
        MSF)
            echo -e "${YELLOW}[AUTO] MSF module: use $PATH_VAL${NC}"
            echo -e "${D}Run: msfconsole -q -x 'use $PATH_VAL'${NC}"
            ;;
        NUCL)
            echo -e "${YELLOW}[AUTO] Nuclei template: $PATH_VAL${NC}"
            echo -e "${D}Run: nuclei -t $PATH_VAL -u <target>${NC}"
            ;;
        PKST)
            echo -e "${YELLOW}[AUTO] PacketStorm advisory: $PATH_VAL${NC}"
            echo -e "${D}Advisory: $PATH_VAL${NC}"
            ;;
    esac
    rm -rf "$TMP_DIR"
    exit 0
fi

# ─── FZF INTERACTIVE DISPLAY ────────────────────────────────────────────────
SELECTED=$(sort -t'|' -k1 -nr "$COMBINED_RAW" | uniq | awk -F'|' -v iloc="$ICON_LOCAL" -v igh="$ICON_GITHUB" -v imsf="$ICON_MSF" -v irce="$ICON_RCE" -v ipoc="$ICON_POC" -v iaut="$ICON_AUTH" -v inuc="$ICON_NUCLEI" -v ipkst="$ICON_PKST" '{
    score=$1; rank=$2; src=$3; title=$4; id=$5; path=$6; pl=$9;
    if (src=="LOC") si=iloc; else if (src=="GITH") si=igh; else if (src=="MSF") si=imsf; else if (src=="PKST") si=ipkst; else si=inuc;
    ii="📄";
    if (title ~ /[Ee]xploit/ || title ~ /[Pp][Oo][Cc]/ || path ~ /\.(sh|bash|py|rb|php|js)$/) ii=ipoc;
    else if (rank=="A") ii=irce; else if (rank=="B") ii=iaut;
    pli="🌐"; if (pl=="windows") pli="🪟"; else if (pl=="linux") pli="🐧"; else if (pl=="web") pli="🌍"; else if (pl=="macos") pli="🍎";
    color="\033[1;37m"; if (rank=="A") color="\033[1;31m"; else if (rank=="B") color="\033[1;33m"; else if (rank=="C") color="\033[1;36m";
    printf "%s %s %s %-4s %s %-80s \033[1;37m[%s]\033[0m\n", color, pli, si, src, ii, title, id;
}' | fzf --ansi --reverse --height=85% --border=rounded --inline-info --header="Vulnerability Intelligence Search" --preview-window="right:45%:wrap" --preview="
    ID=\$(echo {} | grep -o '\[.*\]' | tr -d '[]');
    LINE=\$(grep -F \"|\$ID|\" $COMBINED_RAW | head -n 1);
    SRC=\$(echo \"\$LINE\" | awk -F'|' '{print \$3}');
    TITLE=\$(echo \"\$LINE\" | awk -F'|' '{print \$4}');
    FILE=\$(echo \"\$LINE\" | awk -F'|' '{print \$6}');
    DESC=\$(echo \"\$LINE\" | awk -F'|' '{print \$7}');

    echo -e \"\033[1;35m==> \$TITLE\033[0m\";
    echo -e \"\033[1;30mSource: \$SRC | ID: \$ID\033[0m\";
    if [[ -n \"\$DESC\" ]]; then
        echo -e \"\033[1;36mDescription: \$DESC\033[0m\";
    fi
    echo -e \"--------------------------------------------------\";

    if [[ -f \"\$FILE\" ]]; then
        $BAT_CMD \"\$FILE\" 2>/dev/null || cat \"\$FILE\"
    elif [[ \"\$SRC\" == \"MSF\" && -n \"$MSF_MODULES_BASE\" ]]; then
        FS_PATH=\$(echo \"\$FILE\" | sed -E 's|^exploit/|exploits/|; s|^payload/|payloads/|; s|^encoder/|encoders/|; s|^nop/|nops/|');
        MSF_FILE=\"$MSF_MODULES_BASE/\${FS_PATH}.rb\";
        if [[ -f \"\$MSF_FILE\" ]]; then
            $BAT_CMD \"\$MSF_FILE\" 2>/dev/null || cat \"\$MSF_FILE\"
        else
            echo -e \"\033[1;33mMetasploit Module: \$FILE\033[0m\";
            echo -e \"\033[1;30mModule path not found in local modules directory.\033[0m\";
        fi
    elif [[ \"\$FILE\" == http* ]]; then
        echo -e \"\033[1;34mURL:\033[0m \$FILE\";
        if [[ \"\$SRC\" == \"GITH\" ]]; then
            echo -e \"\n\033[1;32m🐙 GitHub PoC / Advisory Repository\033[0m\";
        elif [[ \"\$SRC\" == \"PKST\" ]]; then
            echo -e \"\n\033[1;32m📡 PacketStorm Security Advisory\033[0m\";
        fi
    else
        echo -e \"\033[1;37mReference:\033[0m \$FILE\";
    fi
")

if [[ -n "$SELECTED" ]]; then
    ID=$(echo "$SELECTED" | grep -o '\[.*\]' | tr -d '[]' | xargs)
    LINE=$(grep -F "|$ID|" "$COMBINED_RAW" | head -n 1)
    SOURCE=$(echo "$LINE" | awk -F'|' '{print $3}')
    TITLE=$(echo "$LINE" | awk -F'|' '{print $4}')
    PATH_VAL=$(echo "$LINE" | awk -F'|' '{print $6}')

    clear
    echo -e "${MAGENTA}ACQUISITION PROTOCOL${NC}\n==================================================\nTARGET : ${BOLD}$TITLE${NC}\n=================================================="

    if [[ "$SOURCE" == "MSF" ]]; then
        echo -e "\n${YELLOW}MSF Module detected. Select action:${NC}"
        echo -e "  ${D}[1]${NC} 🚀 Launch Metasploit and use module"
        echo -e "  ${D}[2]${NC} 📥 Download source (.rb) to $EXPLOIT_DIR"
        echo -ne "\n${YELLOW}❯ Selection [1]: ${NC}"; read -r msf_choice
        if [[ "$msf_choice" == "2" ]]; then
            if [[ -n "$MSF_MODULES_BASE" && -d "$MSF_MODULES_BASE" ]]; then
                FS_PATH=$(echo "$PATH_VAL" | sed -E 's|^exploit/|exploits/|; s|^payload/|payloads/|; s|^encoder/|encoders/|; s|^nop/|nops/|')
                FULL_MSF_PATH="$MSF_MODULES_BASE/${FS_PATH}.rb"
                if [[ -f "$FULL_MSF_PATH" ]]; then
                    cp "$FULL_MSF_PATH" "$EXPLOIT_DIR/" 2>/dev/null && echo -e "\n${GREEN}✔ MSF Module harvested to $EXPLOIT_DIR.${NC}" || echo -e "\n${RED}✘ Error copying module.${NC}"
                else
                    echo -e "\n${RED}✘ Module file not found: $FULL_MSF_PATH${NC}"
                fi
            else
                echo -e "\n${YELLOW}MSF modules directory not available locally.${NC}"
            fi
        else
            if command -v msfconsole >/dev/null 2>&1; then
                msfconsole -q -x "use $PATH_VAL"
            else
                echo -e "\n${YELLOW}msfconsole not found in PATH. Run manually:${NC}\nmsfconsole -q -x 'use $PATH_VAL'"
            fi
        fi
    elif [[ "$SOURCE" == "NUCL" ]]; then
        echo -e "\n${YELLOW}Nuclei Template detected:${NC}\n 📄 Path: $PATH_VAL"
        echo -e "\n${CYAN}To run this template:${NC}\n nuclei -t $PATH_VAL -u <target>"
        echo -ne "\n${YELLOW}Copy path to clipboard? (y/n) [Y]: ${NC}"; read -r copy_path
        if [[ "$copy_path" != "n" && "$copy_path" != "N" ]]; then
            if copy_to_clipboard "$PATH_VAL"; then
                echo -e "${GREEN}✔ Copied to clipboard.${NC}"
            fi
        fi
    elif [[ "$SOURCE" == "PKST" ]]; then
        echo -e "\n${YELLOW}📡 PacketStorm advisory detected:${NC}"
        echo -e "  🌐 URL: ${CYAN}$PATH_VAL${NC}"
        echo -e "\n  ${D}[1]${NC} 🌐 Open in browser"
        echo -e "  ${D}[2]${NC} 📋 Copy URL to clipboard"
        echo -ne "\n${YELLOW}❯ Selection [1]: ${NC}"; read -r pkst_choice
        case "$pkst_choice" in
            2) 
                if copy_to_clipboard "$PATH_VAL"; then
                    echo -e "\n${GREEN}✔ URL copied to clipboard.${NC}"
                fi
                ;;
            *) 
                if open_url "$PATH_VAL"; then
                    echo -e "\n${GREEN}✔ Opened in browser.${NC}"
                fi
                ;;
        esac
    else
        echo -ne "\n${YELLOW}Confirm download to $EXPLOIT_DIR? (y/n) [Y]: ${NC}"; read -r confirm
        if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
            cd "$EXPLOIT_DIR" || exit
            case "$SOURCE" in 
                LOC) 
                    if command -v "$REAL_SEARCHSPLOIT" >/dev/null 2>&1 || [[ -x "$REAL_SEARCHSPLOIT" ]]; then
                        "$REAL_SEARCHSPLOIT" -m "$ID" > /dev/null 2>&1
                    elif [[ -f "$PATH_VAL" ]]; then
                        cp "$PATH_VAL" "$EXPLOIT_DIR/" 2>/dev/null
                    fi
                    ;; 
                GITH) 
                    if [[ "$PATH_VAL" =~ \.(py|sh|rb|php|js)$ ]]; then 
                        RAW_URL=$(echo "$PATH_VAL" | sed 's/github.com/raw.githubusercontent.com/' | sed 's|/blob/|/|')
                        curl -s -O "$RAW_URL" 2>/dev/null
                    else 
                        git clone "$PATH_VAL" --quiet 2>/dev/null
                    fi 
                    ;; 
            esac
            echo -e "\n${GREEN}✔ Asset successfully deployed.${NC}"; sleep 1
        fi
    fi
fi

rm -rf "$TMP_DIR"
