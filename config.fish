# ==========================================
# 1. CACHYOS DEFAULTS & INITIALIZATION
# ==========================================

source /usr/share/cachyos-fish-config/cachyos-config.fish

# Set Default Gemini Model
set -Ux GEMINI_MODEL gemini-3.5-flash

# Overwrite greeting (Disables fastfetch on launch if empty)
function fish_greeting
    # Add custom greeting here if desired
end

# --- PATH Construction ---
fish_add_path $HOME/bin
fish_add_path $HOME/.local/bin
fish_add_path /usr/local/bin
fish_add_path /usr/local/go/bin
fish_add_path /snap/bin

# --- Editor Selection Strategy ---
if type -q code-insiders
    set -gx EDITOR "code --wait"
else if type -q nvim
    set -gx EDITOR nvim
else
    set -gx EDITOR vi
end

# ==========================================
# 2. MICRO FUNCTIONS & UTILITIES
# ==========================================

function ask-gemini
    if test (count $argv) -eq 0
        echo "Usage: ask-gemini \"your question here\""
        return 1
    end

    gemini -p "$argv" | mdcat
end

function explore
    # If no argument is provided, default to current directory
    if test (count $argv) -eq 0
        dolphin . >/dev/null 2>&1 & disown
    else
        dolphin $argv >/dev/null 2>&1 & disown
    end
end

function cheat
    clear; and curl cheat.sh/"$argv[1]"
end

function weather
    clear; and curl wttr.in/"$argv[1]"
end

# ==========================================
# 3. ALIASES: SYSTEM & MAINTENANCE
# ==========================================

alias vi="nvim"

# --- Dotfiles Version Control ---
alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# --- Shell Management ---
alias cls='clear'
alias reload-fish='source ~/.config/fish/config.fish && echo "Fish config reloaded."'
alias ep='$EDITOR ~/.config/fish/config.fish'

# --- Hardware & Utilities ---
alias formatusb='sudo $HOME/bin/formatusb.sh'
alias format-usb='sudo $HOME/bin/formatusb.sh'

# --- Process Management ---
alias p='ps aux | grep -v grep'
alias ps='ps auxf'
alias top='htop'
alias topcpu='/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10'

# ==========================================
# 4. ALIASES: NAVIGATION & DIRECTORIES
# ==========================================

# --- Modern Listing (EZA) ---
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first"
alias la="eza -la --icons --group-directories-first"

# --- Traversal ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias bd='cd -' # Fish equivalent of returning to previous directory
alias z..='zoxide query ..'
alias z="zoxide"

# --- Bookmarks ---
alias desk='cd ~/Desktop'
alias docs='cd ~/Documents'
alias dl='cd ~/Downloads'
alias apache='cd /etc/apache2'
alias web='cd /var/www/html'

# ==========================================
# 5. ALIASES: NETWORK & DIAGNOSTICS
# ==========================================

alias checksmtp='$HOME/bin/checksmtp.sh'

# --- Core Networking ---
alias myip='whatsmyip'
alias pingg='ping 8.8.8.8'
alias pinggw='ping (ip route show | grep default | awk \'{print $3}\' | head -n 1)'
alias flushdns='sudo resolvectl flush-caches && echo "DNS Caches Flushed"'

# --- SMTP Connectivity Tools ---
alias cs='checksmtp'
alias testmail='checksmtp'
alias checkmail='checksmtp'

# 1. Major Providers
alias csgmail='checksmtp smtp.gmail.com'
alias cso365='checksmtp smtp.office365.com'
alias csoutlook='checksmtp smtp-mail.outlook.com'
alias csyahoo='checksmtp smtp.mail.yahoo.com'
alias csaol='checksmtp smtp.aol.com'
alias csicloud='checksmtp smtp.mail.me.com'
alias cszoho='checksmtp smtp.zoho.com'

# 2. Transactional / Dev
alias csgo='checksmtp smtp.smtp2go.com'
alias cssendgrid='checksmtp smtp.sendgrid.net'
alias csmailgun='checksmtp smtp.mailgun.org'
alias cspostmark='checksmtp smtp.postmarkapp.com'
alias csmandrill='checksmtp smtp.mandrillapp.com'
alias csbrevo='checksmtp smtp-relay.sendinblue.com'
alias csmailjet='checksmtp in-v3.mailjet.com'
alias csses='checksmtp email-smtp.us-east-1.amazonaws.com'

# 3. ISP / Telecom
alias cscomcast='checksmtp smtp.comcast.net'
alias csatt='checksmtp outbound.att.net'
alias csverizon='checksmtp smtp.verizon.net'
alias csspectrum='checksmtp mail.twc.com'
alias cscox='checksmtp smtp.cox.net'
alias cscentury='checksmtp smtp.centurylink.net'

# 4. Web Hosting
alias csgodaddy='checksmtp smtpout.secureserver.net'
alias csrackspace='checksmtp secure.emailsrvr.com'
alias csionos='checksmtp smtp.ionos.com'
alias csbluehost='checksmtp smtp.bluehost.com'

# ==========================================
# 6. EXTERNAL TOOLS INITIALIZATION
# ==========================================

if type -q zoxide
    zoxide init fish | source
end

# ==========================================
# 7. SESSION MANAGEMENT
# ==========================================

# Capture the parent terminal shell's PID before launching Zellij
if not set -q ZELLIJ
    set -gx HOST_FISH_PID $fish_pid
end

if status is-interactive
    and test "$TERM_PROGRAM" != vscode
    and not set -q ZELLIJ
    eval (zellij setup --generate-auto-start fish | string collect)
end

if status is-interactive
    if not set -q ZELLIJ
        # Start a brand new session
        zellij

        # Intentionally blank below. When Zellij closes, you drop to the parent Fish shell.
    end
end

# Set Yakuake tab title automatically
function fish_title
    # If a command is currently running, set the title to the command name
    if set -q argv[1]
        echo $argv[1]
    else
        # Default title when idling at the prompt (e.g., current directory name)
        basename (prompt_pwd)
    end
end
