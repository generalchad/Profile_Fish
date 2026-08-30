# ==========================================
# 1. CACHYOS DEFAULTS & INITIALIZATION
# ==========================================

source /usr/share/cachyos-fish-config/cachyos-config.fish

# Set Default Gemini Model
set -gx GEMINI_MODEL gemini-3.5-flash

# Overwrite greeting (Disables fastfetch on launch if empty)
function fish_greeting
    # Add custom greeting here if desired
end

# --- Terminal Query Fix ---
# fish (>=4.1) queries the terminal for its background color via `ESC]11;?`
# on startup. Under some terminals/multiplexers (e.g. Yakuake + Zellij) the
# reply can race the first prompt and get typed onto the command line as
# "11;rgb:1e1e/2323/2626". Disabling the `query-term` feature flag stops all
# such startup queries (background color, cursor position, etc.).
# Feature flags are only read at startup from a universal/exported variable,
# so this takes effect on the next shell.
if not contains no-query-term $fish_features
    set -Ua fish_features no-query-term
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

# Edit this profile in the primary editor. Resolves the editor explicitly
# because fish does not word-split $EDITOR (which may be "code --wait").
function ep
    if type -q code-insiders
        code-insiders --wait ~/.config/fish/config.fish
    else if type -q nvim
        nvim ~/.config/fish/config.fish
    else
        vi ~/.config/fish/config.fish
    end
end

# ==========================================
# 3. ALIASES: SYSTEM & MAINTENANCE
# ==========================================

alias vi="nvim"

# --- Dotfiles Version Control ---
# Bare-repo dotfiles manager (git over $HOME). Run `config init` once to set up.
function config
    if test "$argv[1]" = init
        git init --bare $HOME/.dotfiles
        /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME config --local status.showUntrackedFiles no
        echo "Dotfiles repo initialized at ~/.dotfiles"
        return
    end
    if not test -d $HOME/.dotfiles
        echo "config: dotfiles repo not initialized." >&2
        echo "  Run 'config init' to create ~/.dotfiles" >&2
        return 1
    end
    /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME $argv
end

# --- Shell Management ---
alias cls='clear'
alias reload-fish='source ~/.config/fish/config.fish && echo "Fish config reloaded."'

# --- Hardware & Utilities ---
# Safely format a USB/removable drive (requires explicit FORMAT confirmation).
function formatusb -a device
    set -l fs $argv[2]
    if not test -n "$fs"
        set fs vfat
    end

    if not test -n "$device"
        echo "Available block devices:" >&2
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL >&2
        echo >&2
        echo "Usage: formatusb <device> [filesystem]" >&2
        echo "  e.g. formatusb /dev/sdb vfat   (vfat|exfat|ext4|ntfs)" >&2
        return 1
    end

    if not string match -q '/dev/*' "$device"
        echo "formatusb: device must be an absolute path under /dev" >&2
        return 1
    end

    if not lsblk $device >/dev/null 2>&1
        echo "formatusb: device not found: $device" >&2
        return 1
    end

    set -l mkfs
    switch $fs
        case vfat fat32 fat
            set mkfs mkfs.fat -F32
        case exfat
            set mkfs mkfs.exfat
        case ext4
            set mkfs mkfs.ext4
        case ntfs
            set mkfs mkfs.ntfs
        case '*'
            echo "formatusb: unsupported filesystem '$fs' (vfat|exfat|ext4|ntfs)" >&2
            return 1
    end

    echo "WARNING: This will permanently ERASE all data on $device" >&2
    lsblk -o NAME,SIZE,MODEL $device >&2
    echo >&2
    read -P "Type FORMAT to confirm: " confirm
    if test "$confirm" != FORMAT
        echo "Aborted." >&2
        return 1
    end

    sudo $mkfs $device
end

alias format-usb='formatusb'

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
alias ll="eza -l --icons --group-directories-first"
alias la="eza -la --icons --group-directories-first"

# --- Traversal ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias bd='cd -' # Fish equivalent of returning to previous directory

# --- Bookmarks ---
alias desk='cd ~/Desktop'
alias docs='cd ~/Documents'
alias dl='cd ~/Downloads'
alias apache='cd /etc/apache2'
alias web='cd /var/www/html'

# ==========================================
# 5. ALIASES: NETWORK & DIAGNOSTICS
# ==========================================

# Test SMTP connectivity and banner retrieval for a host or known alias.
# Defaults to ports 25/587/465/2525. Parity with Test-SmtpRelay.
function checksmtp
    if test (count $argv) -eq 0
        echo "Usage: checksmtp <host|alias> [port ...]"
        echo "       e.g. checksmtp smtp.gmail.com   or   checksmtp gmail"
        return 1
    end

    set -l host $argv[1]
    set -l ports $argv[2..-1]
    if test (count $ports) -eq 0
        set ports 25 587 465 2525
    end

    # --- Alias mapping (parity with Test-SmtpRelay) ---
    switch $host
        case gmail google gsuite workspace
            set host smtp.gmail.com
        case office o365 outlook hotmail live msn microsoft m365 exchange
            set host smtp.office365.com
        case yahoo ymail rocketmail sbcglobal
            set host smtp.mail.yahoo.com
        case icloud apple
            set host smtp.mail.me.com
        case aws ses amazonses
            set host email-smtp.us-east-1.amazonaws.com
        case aol
            set host smtp.aol.com
        case sendgrid
            set host smtp.sendgrid.net
        case mailgun
            set host smtp.mailgun.org
        case postmark
            set host smtp.postmarkapp.com
        case smtp2go
            set host mail.smtp2go.com
        case mandrill mailchimp
            set host smtp.mandrillapp.com
        case brevo sendinblue
            set host smtp-relay.brevo.com
        case mailjet
            set host in-v3.mailjet.com
        case zoho
            set host smtp.zoho.com
        case godaddy
            set host smtpout.secureserver.net
        case rackspace
            set host secure.emailsrvr.com
        case ionos 1and1
            set host smtp.ionos.com
        case comcast xfinity
            set host smtp.comcast.net
        case verizon
            set host smtp.verizon.net
        case spectrum charter
            set host mobile.charter.net
        case cox
            set host smtp.cox.net
    end

    echo "--- Testing SMTP Connectivity for $host ---"

    echo -n "Resolving DNS... "
    set -l ips (getent ahosts $host 2>/dev/null | awk '{print $1}' | sort -u)
    if test (count $ips) -eq 0
        echo "[FAILED]"
        echo "  ! TIP: Check the system has valid DNS servers and gateway."
        return 1
    end
    echo "[OK]"
    for ip in $ips
        echo "   -> $ip"
    end
    echo

    echo "Testing Ports..."
    for port in $ports
        echo -n "   Checking TCP Port $port... "
        set -l banner
        if test $port -eq 465
            set banner (timeout 6 openssl s_client -connect $host:$port -servername $host -quiet 2>/dev/null </dev/null | grep -m1 '^220')
        else
            set banner (printf 'QUIT\r\n' | timeout 6 ncat -4 -w 3 $host $port 2>/dev/null | grep -m1 '^220')
        end

        if test -n "$banner"
            echo "[OPEN]  "(string trim $banner)
        else
            echo "[FAILED]"
        end
    end
end

# --- Core Networking ---
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
# 6. GIT SHORTCUTS
# ==========================================

function gs
    git status
end

function ga
    git add .
end

function gp
    git push
end

function gcom
    set -l msg (string join ' ' $argv)
    git add .
    git commit -m "$msg"
end

function lazyg
    set -l msg (string join ' ' $argv)
    git add .
    git commit -m "$msg"
    git push
end

function g
    z Github
end

# ==========================================
# 7. CLIPBOARD
# ==========================================

function cpy
    set -l text (string join ' ' $argv)
    if type -q wl-copy
        printf '%s' $text | wl-copy
    else if type -q xclip
        printf '%s' $text | xclip -selection clipboard
    else
        echo "cpy: install wl-clipboard (or xclip)" >&2
        return 1
    end
end

function pst
    if type -q wl-paste
        wl-paste
    else if type -q xclip
        xclip -selection clipboard -o
    else
        echo "pst: install wl-clipboard (or xclip)" >&2
        return 1
    end
end

function clearclip
    if type -q wl-copy
        printf '' | wl-copy
    else if type -q xclip
        printf '' | xclip -selection clipboard
    end
end

# ==========================================
# 8. UTILITY FUNCTIONS (parity with PowerShell profile)
# ==========================================

function myip
    echo "Public IP: "(curl -s --max-time 5 https://ifconfig.me 2>/dev/null)
    echo "Local IPv4:"
    ip -4 -o addr show scope global 2>/dev/null | awk '{print "  " $2 ": " $4}'
end

function publicip
    curl -s --max-time 5 https://ifconfig.me
end

function speed
    if type -q librespeed-cli
        command librespeed-cli $argv
    else if type -q speedtest
        command speedtest $argv
    else
        echo "speed: install librespeed-cli or speedtest-cli" >&2
        return 1
    end
end

function up
    uptime -p
    echo "Boot time: "(uptime -s)
end

function hb -a file
    if not test -f $file
        echo "hb: file not found: $file" >&2
        return 1
    end
    set -l key (curl -s -X POST --data-binary @$file https://bin.christitus.com/documents | string match -r -g '"key":"([^"]+)"')
    if test -z "$key"
        echo "hb: upload failed" >&2
        return 1
    end
    echo "https://bin.christitus.com/$key"
end

function mkcd -a dir
    mkdir -p $dir
    cd $dir
end

function extract -a archive
    if not test -f $archive
        echo "extract: file not found: $archive" >&2
        return 1
    end
    switch $archive
        case '*.tar.gz' '*.tgz'
            tar -xzvf $archive
        case '*.tar.bz2' '*.tbz2'
            tar -xjvf $archive
        case '*.tar.xz' '*.txz'
            tar -xJvf $archive
        case '*.tar'
            tar -xvf $archive
        case '*.zip'
            command unzip $archive
        case '*.7z' '*.rar'
            7z x $archive
        case '*'
            echo "extract: unsupported format: $archive" >&2
            return 1
    end
end

function ff -a name
    if type -q fd
        fd --hidden "$name"
    else
        find . -name "*$name*" 2>/dev/null
    end
end

function nf -a path
    touch $path
end

function sysinfo
    if type -q fastfetch
        fastfetch
    else
        echo "sysinfo: install fastfetch or neofetch" >&2
        return 1
    end
end

function py
    if type -q python
        python $argv
    else
        echo "py: Python not found" >&2
        return 1
    end
end

# ==========================================
# 9. EXTERNAL TOOLS INITIALIZATION
# ==========================================

if type -q zoxide
    zoxide init fish | source
end

# ==========================================
# 10. SESSION MANAGEMENT
# ==========================================

# Capture the parent terminal shell's PID before launching Zellij
if not set -q ZELLIJ
    set -gx HOST_FISH_PID $fish_pid
end

# Auto-start Zellij on interactive shells (skipped inside Zellij and VS Code).
# Honors ZELLIJ_AUTO_ATTACH / ZELLIJ_AUTO_EXIT when set.
if status is-interactive
    and test "$TERM_PROGRAM" != vscode
    and not set -q ZELLIJ
    eval (zellij setup --generate-auto-start fish | string collect)
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
