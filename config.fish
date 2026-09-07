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
    if contains -- $argv[1] -h --help
        echo "Usage: ask-gemini \"your question here\""
        echo
        echo "Ask a question to the Gemini model and render the response."
        echo
        echo "Options:"
        echo "  -h, --help  Show this help"
        return 0
    end
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

# Resolve the primary editor explicitly (fish does not word-split $EDITOR,
# which may be "code --wait") and open the given path.
function _edit -a path
    if type -q code-insiders
        code-insiders --wait $path
    else if type -q nvim
        nvim $path
    else
        vi $path
    end
end

# Edit the live profile.
function ep
    _edit ~/.config/fish/config.fish
end

# Edit the project profile (git-tracked source of truth).
function epr
    _edit ~/Projects/Profile_Fish/config.fish
end

# Sync the project profile to the live location and reload the shell.
# Use -p/--push to also git commit + push (never automatic).
function go-live
    argparse 'p/push' 'm/message=' 'h/help' -- $argv
    or return

    if set -q _flag_help
        echo "Usage: go-live [-p|--push] [-m|--message MSG]"
        echo
        echo "Sync the project profile to the live location and reload the shell."
        echo
        echo "Options:"
        echo "  -p, --push         Also git commit + push (never automatic)"
        echo "  -m, --message MSG  Commit message for --push (default: \"Update fish profile\")"
        echo "  -h, --help         Show this help"
        return 0
    end

    set -l src ~/Projects/Profile_Fish/config.fish
    set -l dst ~/.config/fish/config.fish

    if not test -f $src
        echo "go-live: source not found: $src" >&2
        return 1
    end

    cp $src $dst
    or return 1

    if set -q _flag_push
        set -l msg $_flag_message
        if test -z "$msg"
            set msg "Update fish profile"
        end
        git -C ~/Projects/Profile_Fish add .
        git -C ~/Projects/Profile_Fish commit -m "$msg"
        git -C ~/Projects/Profile_Fish push
    end

    source $dst
    echo "Fish profile synced and reloaded."
end

# ==========================================
# 3. ALIASES: SYSTEM & MAINTENANCE
# ==========================================

alias vi="nvim"

# --- Dotfiles Version Control ---
# Bare-repo dotfiles manager (git over $HOME). Run `config init` once to set up.
function config
    if contains -- $argv[1] -h --help
        echo "Usage: config <git-command> [args]"
        echo "       config init"
        echo
        echo "Bare-repo dotfiles manager (git over \$HOME)."
        echo
        echo "Commands:"
        echo "  init  Initialize the dotfiles repo at ~/.dotfiles"
        echo
        echo "Any other arguments are passed to git over the dotfiles repo."
        return 0
    end
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
# Safely format a removable drive (requires explicit FORMAT confirmation).
function format-usb
    argparse 'f/force' 'y/yes' 'n/name=' 'h/help' -- $argv
    or return

    if set -q _flag_help
        echo "Usage: format-usb <device> [filesystem] [--name LABEL] [--force|--yes]"
        echo
        echo "Safely format a removable drive (requires FORMAT confirmation)."
        echo
        echo "Arguments:"
        echo "  <device>       Block device path (e.g. /dev/sdb)"
        echo "  [filesystem]   vfat (default), exfat, or ext4"
        echo
        echo "Options:"
        echo "  -n, --name LABEL  Set volume label"
        echo "  -f, --force       Skip removable-device check and confirmation"
        echo "  -y, --yes         Skip confirmation prompt"
        echo "  -h, --help        Show this help"
        echo
        echo "Examples:"
        echo "  format-usb /dev/sdb"
        echo "  format-usb /dev/sdb exfat --name MyDrive"
        return 0
    end

    set -l device $argv[1]
    set -l fs $argv[2]
    if not test -n "$fs"
        set fs vfat
    end

    if not test -n "$device"
        echo "Available block devices:" >&2
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL >&2
        echo >&2
        echo "Usage: format-usb <device> [filesystem] [--name LABEL] [--force|--yes]" >&2
        echo >&2
        echo "Safely format a removable drive (requires FORMAT confirmation)." >&2
        echo >&2
        echo "Arguments:" >&2
        echo "  <device>       Block device path (e.g. /dev/sdb)" >&2
        echo "  [filesystem]   vfat (default), exfat, or ext4" >&2
        echo >&2
        echo "Options:" >&2
        echo "  -n, --name LABEL  Set volume label" >&2
        echo "  -f, --force       Skip removable-device check and confirmation" >&2
        echo "  -y, --yes         Skip confirmation prompt" >&2
        echo "  -h, --help        Show this help" >&2
        echo >&2
        echo "Examples:" >&2
        echo "  format-usb /dev/sdb" >&2
        echo "  format-usb /dev/sdb exfat --name MyDrive" >&2
        return 1
    end

    if not string match -q '/dev/*' "$device"
        echo "format-usb: device must be an absolute path under /dev" >&2
        return 1
    end

    if not lsblk $device >/dev/null 2>&1
        echo "format-usb: device not found: $device" >&2
        return 1
    end

    set -l base (lsblk -ndo PKNAME $device)
    if test -z "$base"
        set base (basename $device)
    end
    if not test -f /sys/block/$base/removable
        echo "format-usb: cannot determine if $device is removable" >&2
        return 1
    end
    if not set -q _flag_force; and not set -q _flag_yes; and not test (cat /sys/block/$base/removable) -eq 1
        echo "format-usb: $device is not a removable device (use --force to override)" >&2
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
        case '*'
            echo "format-usb: unsupported filesystem '$fs' (vfat|exfat|ext4)" >&2
            return 1
    end

    set -l label $_flag_name
    if test -n "$label"
        switch $fs
            case ext4
                set -a mkfs -L $label
            case '*'
                set -a mkfs -n $label
        end
    end

    if not command -q $mkfs[1]
        echo "format-usb: $mkfs[1] not installed" >&2
        return 1
    end

    if not set -q _flag_force; and not set -q _flag_yes
        echo "WARNING: This will permanently ERASE all data on $device" >&2
        lsblk -o NAME,SIZE,MODEL $device >&2
        echo >&2
        read -P "Type FORMAT to confirm: " confirm
        if test "$confirm" != FORMAT
            echo "Aborted." >&2
            return 1
        end
    end

    sudo $mkfs $device
end

# --- Package Listing ---
# List every installed package with version, install date, and origin
# (official repo vs AUR). Reuses pacman's native/foreign split.
function list-packages
    echo "--- Official Repos (Pacman) ---"
    expac '%n\t%v\t%l' (pacman -Qqn) | column -t -s (printf '\t')
    echo
    echo "--- AUR (Paru) ---"
    expac '%n\t%v\t%l' (pacman -Qmq) | column -t -s (printf '\t')
end

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
function check-smtp
    if contains -- $argv[1] -h --help
        echo "Usage: check-smtp <host|alias> [port ...]"
        echo
        echo "Test SMTP connectivity and banner retrieval for a host or known alias."
        echo "Defaults to ports 25/587/465/2525."
        echo
        echo "Arguments:"
        echo "  <host|alias>  Hostname or known alias (e.g. smtp.gmail.com or gmail)"
        echo "  [port ...]    TCP ports to test (default: 25 587 465 2525)"
        echo
        echo "Options:"
        echo "  -h, --help  Show this help"
        return 0
    end
    if test (count $argv) -eq 0
        echo "Usage: check-smtp <host|alias> [port ...]" >&2
        echo "       e.g. check-smtp smtp.gmail.com   or   check-smtp gmail" >&2
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
alias cs='check-smtp'
alias testmail='check-smtp'
alias checkmail='check-smtp'

# 1. Major Providers
alias csgmail='check-smtp smtp.gmail.com'
alias cso365='check-smtp smtp.office365.com'
alias csoutlook='check-smtp smtp-mail.outlook.com'
alias csyahoo='check-smtp smtp.mail.yahoo.com'
alias csaol='check-smtp smtp.aol.com'
alias csicloud='check-smtp smtp.mail.me.com'
alias cszoho='check-smtp smtp.zoho.com'

# 2. Transactional / Dev
alias csgo='check-smtp smtp.smtp2go.com'
alias cssendgrid='check-smtp smtp.sendgrid.net'
alias csmailgun='check-smtp smtp.mailgun.org'
alias cspostmark='check-smtp smtp.postmarkapp.com'
alias csmandrill='check-smtp smtp.mandrillapp.com'
alias csbrevo='check-smtp smtp-relay.sendinblue.com'
alias csmailjet='check-smtp in-v3.mailjet.com'
alias csses='check-smtp email-smtp.us-east-1.amazonaws.com'

# 3. ISP / Telecom
alias cscomcast='check-smtp smtp.comcast.net'
alias csatt='check-smtp outbound.att.net'
alias csverizon='check-smtp smtp.verizon.net'
alias csspectrum='check-smtp mail.twc.com'
alias cscox='check-smtp smtp.cox.net'
alias cscentury='check-smtp smtp.centurylink.net'

# 4. Web Hosting
alias csgodaddy='check-smtp smtpout.secureserver.net'
alias csrackspace='check-smtp secure.emailsrvr.com'
alias csionos='check-smtp smtp.ionos.com'
alias csbluehost='check-smtp smtp.bluehost.com'

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
