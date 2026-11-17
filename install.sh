#!/usr/bin/env bash

# =============================================================================
# GodSearch Installer & Environment Doctor (macOS & Linux)
# Cross-platform dependency verifier and installation helper for GodSearch
# =============================================================================

set -e

# Visual colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
BOLD='\033[1m'
D='\033[1;30m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN_DIR="$HOME/.local/bin"
TARGET_LINK="$TARGET_BIN_DIR/godsearch"

CHECK_ONLY=0
INSTALL_BIN=0
SETUP_ALIAS=0

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --check-only) CHECK_ONLY=1; shift ;;
        --install-bin) INSTALL_BIN=1; shift ;;
        --alias) SETUP_ALIAS=1; shift ;;
        -h|--help)
            echo -e "${MAGENTA}GodSearch Multi-Platform Installer & Doctor${NC}"
            echo -e "Usage: $(basename "$0") [OPTIONS]"
            echo -e "  ${BOLD}--check-only${NC}    Check environment and dependencies without making changes"
            echo -e "  ${BOLD}--install-bin${NC}   Install godsearch binary to ~/.local/bin/godsearch"
            echo -e "  ${BOLD}--alias${NC}         Configure shell aliases in ~/.zshrc or ~/.bashrc"
            echo -e "  ${BOLD}-h, --help${NC}      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

echo -e "${MAGENTA}=====================================================${NC}"
echo -e "${BOLD} GodSearch Cross-Platform Setup & Environment Doctor ${NC}"
echo -e "${MAGENTA}=====================================================${NC}\n"

# ─── 1. OS & ENVIRONMENT DETECTION ──────────────────────────────────────────
OS_TYPE="$(uname -s)"
DISTRO="Unknown"
PKG_MGR="unknown"

if [[ "$OS_TYPE" == "Darwin" ]]; then
    DISTRO="macOS ($(uname -m))"
    PKG_MGR="brew"
elif [[ "$OS_TYPE" == "Linux" ]]; then
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        DISTRO="${NAME:-Linux}"
        case "${ID:-linux}" in
            kali|debian|ubuntu|pop|mint)
                PKG_MGR="apt"
                ;;
            arch|manjaro|endeavouros)
                PKG_MGR="pacman"
                ;;
            fedora|rhel|centos|rocky|almalinux)
                PKG_MGR="dnf"
                ;;
            *)
                if [[ "${ID_LIKE:-}" == *"debian"* ]]; then PKG_MGR="apt";
                elif [[ "${ID_LIKE:-}" == *"arch"* ]]; then PKG_MGR="pacman";
                elif [[ "${ID_LIKE:-}" == *"rhel"* ]] || [[ "${ID_LIKE:-}" == *"fedora"* ]]; then PKG_MGR="dnf";
                else PKG_MGR="generic"; fi
                ;;
        esac
    else
        DISTRO="Generic Linux"
        PKG_MGR="generic"
    fi
fi

echo -e "  ${CYAN}Platform:${NC}     $OS_TYPE"
echo -e "  ${CYAN}Distribution:${NC} $DISTRO"
echo -e "  ${CYAN}Package Mgr:${NC}  $PKG_MGR\n"

# ─── 2. DEPENDENCY AUDIT ───────────────────────────────────────────────────
echo -e "${YELLOW}Checking Core Dependencies:${NC}"

MISSING_CORE=0
MISSING_INTEGRATIONS=0

check_dep() {
    local name="$1"
    local bin="$2"
    local required="$3" # 1=required, 0=optional
    
    if command -v "$bin" >/dev/null 2>&1; then
        local path
        path=$(command -v "$bin")
        echo -e "  [${GREEN}✔${NC}] $name ${D}($path)${NC}"
        return 0
    else
        if [[ "$required" -eq 1 ]]; then
            echo -e "  [${RED}✘${NC}] $name ${RED}(REQUIRED - Not Found)${NC}"
            MISSING_CORE=1
        else
            echo -e "  [${YELLOW}○${NC}] $name ${D}(Optional - Not Found)${NC}"
            MISSING_INTEGRATIONS=1
        fi
        return 1
    fi
}

# Core utilities
check_dep "Bash (v4+ recommended)" "bash" 1
check_dep "cURL (HTTP Client)" "curl" 1
check_dep "jq (JSON Processor)" "jq" 1
check_dep "fzf (Fuzzy Finder)" "fzf" 1
check_dep "bc (Calculator / CVSS)" "bc" 1
check_dep "Git (Version Control)" "git" 1

echo -e "\n${YELLOW}Checking Search Engines & Integrations:${NC}"
check_dep "searchsploit (Exploit-DB)" "searchsploit" 0
check_dep "gh (GitHub CLI)" "gh" 0
check_dep "metasploit-framework" "msfconsole" 0
check_dep "nuclei (Vulnerability Scanner)" "nuclei" 0

echo -e "\n${YELLOW}Checking UI & Terminal Enhancements:${NC}"

# Syntax highlighter detection
HAS_SYNTAX=0
if command -v bat >/dev/null 2>&1; then
    echo -e "  [${GREEN}✔${NC}] Syntax Highlighter ${D}(bat: $(command -v bat))${NC}"
    HAS_SYNTAX=1
elif command -v batcat >/dev/null 2>&1; then
    echo -e "  [${GREEN}✔${NC}] Syntax Highlighter ${D}(batcat: $(command -v batcat))${NC}"
    HAS_SYNTAX=1
elif command -v pygmentize >/dev/null 2>&1; then
    echo -e "  [${GREEN}✔${NC}] Syntax Highlighter ${D}(pygmentize: $(command -v pygmentize))${NC}"
    HAS_SYNTAX=1
else
    echo -e "  [${YELLOW}○${NC}] Syntax Highlighter ${D}(bat/batcat/pygmentize - Optional)${NC}"
fi

# Clipboard utility detection
HAS_CLIPBOARD=0
if command -v pbcopy >/dev/null 2>&1; then
    echo -e "  [${GREEN}✔${NC}] Clipboard Integration ${D}(pbcopy)${NC}"
    HAS_CLIPBOARD=1
elif command -v wl-copy >/dev/null 2>&1; then
    echo -e "  [${GREEN}✔${NC}] Clipboard Integration ${D}(wl-copy)${NC}"
    HAS_CLIPBOARD=1
elif command -v xclip >/dev/null 2>&1; then
    echo -e "  [${GREEN}✔${NC}] Clipboard Integration ${D}(xclip)${NC}"
    HAS_CLIPBOARD=1
elif command -v xsel >/dev/null 2>&1; then
    echo -e "  [${GREEN}✔${NC}] Clipboard Integration ${D}(xsel)${NC}"
    HAS_CLIPBOARD=1
else
    echo -e "  [${YELLOW}○${NC}] Clipboard Integration ${D}(pbcopy/wl-copy/xclip/xsel - Optional)${NC}"
fi

# ─── 3. INSTALLATION INSTRUCTIONS FOR MISSING PACKAGES ─────────────────────
if [[ "$MISSING_CORE" -eq 1 || "$MISSING_INTEGRATIONS" -eq 1 || "$HAS_SYNTAX" -eq 0 || "$HAS_CLIPBOARD" -eq 0 ]]; then
    echo -e "\n${YELLOW}Recommended Installation Commands for your OS:${NC}"
    case "$PKG_MGR" in
        brew)
            echo -e "  ${BOLD}brew update && brew install fzf jq bat pygments bc gh exploitdb${NC}"
            ;;
        apt)
            echo -e "  ${BOLD}sudo apt update && sudo apt install -y fzf jq bat python3-pygments xclip bc gh exploitdb${NC}"
            ;;
        pacman)
            echo -e "  ${BOLD}sudo pacman -S --needed fzf jq bat python-pygments xclip bc github-cli exploitdb${NC}"
            ;;
        dnf)
            echo -e "  ${BOLD}sudo dnf install -y fzf jq bat python3-pygments xclip bc gh${NC}"
            ;;
        *)
            echo -e "  Install the missing tools using your system package manager."
            ;;
    esac
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
    echo -e "\n${GREEN}Check completed.${NC}"
    exit 0
fi

# ─── 4. BINARY INSTALLATION & SYMLINKING ─────────────────────────────────────
echo -e "\n${MAGENTA}-----------------------------------------------------${NC}"
echo -e "${BOLD}Binary Deployment (~/.local/bin/godsearch)${NC}"
echo -e "${MAGENTA}-----------------------------------------------------${NC}"

DO_INSTALL=0
if [[ "$INSTALL_BIN" -eq 1 ]]; then
    DO_INSTALL=1
else
    echo -ne "Install godsearch command to ${CYAN}$TARGET_LINK${NC}? (y/n) [Y]: "
    read -r install_resp
    if [[ "$install_resp" != "n" && "$install_resp" != "N" ]]; then
        DO_INSTALL=1
    fi
fi

if [[ "$DO_INSTALL" -eq 1 ]]; then
    mkdir -p "$TARGET_BIN_DIR" 2>/dev/null
    ln -sf "$SCRIPT_DIR/godsearch.sh" "$TARGET_LINK"
    chmod +x "$SCRIPT_DIR/godsearch.sh" "$TARGET_LINK"
    echo -e "${GREEN}✔ Installed symlink:${NC} $TARGET_LINK -> $SCRIPT_DIR/godsearch.sh"

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$TARGET_BIN_DIR:"* ]]; then
        echo -e "${YELLOW}Notice:${NC} $TARGET_BIN_DIR is not currently in your \$PATH."
        echo -e "Add the following line to your shell profile (~/.zshrc or ~/.bashrc):"
        echo -e "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    fi
fi

# ─── 5. SHELL ALIAS CONFIGURATION ────────────────────────────────────────────
echo -e "\n${MAGENTA}-----------------------------------------------------${NC}"
echo -e "${BOLD}Shell Alias Configuration${NC}"
echo -e "${MAGENTA}-----------------------------------------------------${NC}"

SHELL_RC=""
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    if [[ "$OS_TYPE" == "Darwin" && -f "$HOME/.bash_profile" ]]; then
        SHELL_RC="$HOME/.bash_profile"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
fi

DO_ALIAS=0
if [[ "$SETUP_ALIAS" -eq 1 ]]; then
    DO_ALIAS=1
else
    echo -ne "Configure searchsploit alias override in ${CYAN}${SHELL_RC:-your shell}${NC}? (y/n) [N]: "
    read -r alias_resp
    if [[ "$alias_resp" == "y" || "$alias_resp" == "Y" ]]; then
        DO_ALIAS=1
    fi
fi

if [[ "$DO_ALIAS" -eq 1 && -n "$SHELL_RC" ]]; then
    ALIAS_LINE="alias searchsploit=\"$TARGET_LINK\""
    if grep -Fq "$ALIAS_LINE" "$SHELL_RC" 2>/dev/null; then
        echo -e "${CYAN}i Alias already present in $SHELL_RC${NC}"
    else
        echo -e "\n# GodSearch Alias Override" >> "$SHELL_RC"
        echo "$ALIAS_LINE" >> "$SHELL_RC"
        echo -e "${GREEN}✔ Added to $SHELL_RC:${NC} $ALIAS_LINE"
        echo -e "Run ${BOLD}source $SHELL_RC${NC} to apply changes immediately."
    fi
fi

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN} GodSearch Setup Complete! Ready for Operations.     ${NC}"
echo -e "${GREEN}=====================================================${NC}\n"
