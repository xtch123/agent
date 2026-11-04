#!/bin/sh
# Unofficial extra-architecture installer for xtch123/agent.
# Does NOT alter the official Hub or its signature verification.
set -eu
PATH="$PATH:/usr/sbin:/sbin"
ROOT=/opt/monitor
BIN="$ROOT/monitor-agent"
WRAPPER="$ROOT/run-agent.sh"
ENVFILE="$ROOT/agent.env"
MARKER="$ROOT/.extra-agent"
PIDFILE="$ROOT/.extra-agent.pid"
UNIT=/etc/systemd/system/monitor-agent.service
RC=/etc/init.d/monitor-agent
LOG=/var/log/monitor-agent.log

REPO=xtch123/agent
SERVER=""
TOKEN=""
IFACE=""
INTERVAL=""
TARGET=""
UPGRADE=0
INSECURE=0

usage() {
  cat <<'EOF'
Install:
  sh install-extra.sh --server https://HUB --token NODE_TOKEN [--iface eth0] [--interval 5]
Upgrade (reuse token and settings):
  sh install-extra.sh --upgrade
Options:
  --repo OWNER/REPO  alternate GitHub Fork (default xtch123/agent)
  --target TRIPLE    override architecture auto detection
  --insecure         allow http:// Hub (plaintext token)
The upstream Linux x86_64/aarch64 Agent should use the official Hub installer.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --server|--token|--iface|--interval|--target|--repo)
      [ "$#" -ge 2 ] || { echo "Missing value: $1" >&2; exit 2; }
      case "$1" in
        --server) SERVER=$2 ;;
        --token) TOKEN=$2 ;;
        --iface) IFACE=$2 ;;
        --interval) INTERVAL=$2 ;;
        --target) TARGET=$2 ;;
        --repo) REPO=$2 ;;
      esac
      shift 2 ;;
    --upgrade) UPGRADE=1; shift ;;
    --insecure) INSECURE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ "$(id -u)" = 0 ] || { echo "Run as root" >&2; exit 1; }
case "$REPO" in
  */*) case "$REPO" in *[!A-Za-z0-9._/-]*|/*|*/|*..*) echo "Bad --repo" >&2; exit 2 ;; esac ;;
  *) echo "Bad --repo" >&2; exit 2 ;;
esac
for cmd in curl sha256sum install awk grep; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing command: $cmd" >&2; exit 1; }
done

read_env() {
  [ -f "$ENVFILE" ] || return 0
  sed -n "s/^$1=//p" "$ENVFILE" | tail -n 1
}
if [ "$UPGRADE" = 1 ]; then
  [ -f "$MARKER" ] || { echo "Refusing to replace an official/unknown Agent (marker missing)" >&2; exit 1; }
  SERVER=$(read_env MONITOR_SERVER)
  TOKEN=$(read_env MONITOR_TOKEN)
  [ -n "$IFACE" ] || IFACE=$(read_env MONITOR_IFACE)
  [ -n "$INTERVAL" ] || INTERVAL=$(read_env MONITOR_INTERVAL)
  [ "$INSECURE" = 1 ] || INSECURE=$(read_env MONITOR_INSECURE)
else
  [ ! -e "$BIN" ] && [ ! -e "$ENVFILE" ] || { echo "Agent exists; this installer refuses to overwrite it" >&2; exit 1; }
fi

[ -n "$SERVER" ] && [ -n "$TOKEN" ] || { echo "Missing --server/--token (or saved config)" >&2; exit 2; }
case "$SERVER" in
  https://*) : ;;
  http://*) [ "$INSECURE" = 1 ] || { echo "HTTP requires --insecure" >&2; exit 2; } ;;
  *) echo "Hub must use https:// (or explicit insecure http://)" >&2; exit 2 ;;
esac
# Config is sourced by a root-owned script; reject shell metacharacters.
case "$SERVER" in *[!A-Za-z0-9._:/%+-]*|'') echo "Unsupported Hub URL characters" >&2; exit 2 ;; esac
case "$TOKEN" in *[!A-Za-z0-9._~+/-]*|'') echo "Unsupported token characters" >&2; exit 2 ;; esac
[ -n "$INTERVAL" ] || INTERVAL=1
case "$INTERVAL" in ''|*[!0-9]*) echo "Bad interval" >&2; exit 2 ;; esac
[ "$INTERVAL" -ge 1 ] && [ "$INTERVAL" -le 3600 ] || { echo "Interval must be 1..3600" >&2; exit 2; }
case "$IFACE" in *[!A-Za-z0-9._,-]*) echo "Bad interface list" >&2; exit 2 ;; esac

if [ -z "$TARGET" ]; then
  case "$(uname -m)" in
    armv7*|armv7l) TARGET=armv7-unknown-linux-musleabihf ;;
    armv6*|armv6l) TARGET=arm-unknown-linux-musleabihf ;;
    armv5*) TARGET=armv5te-unknown-linux-musleabi ;;
    i386|i486|i586) TARGET=i586-unknown-linux-musl ;;
    i686) TARGET=i686-unknown-linux-musl ;;
    riscv64) TARGET=riscv64gc-unknown-linux-musl ;;
    loongarch64) TARGET=loongarch64-unknown-linux-musl ;;
    ppc64le) TARGET=powerpc64le-unknown-linux-musl ;;
    ppc64) TARGET=powerpc64-unknown-linux-musl ;;
    mips) TARGET=mips-unknown-linux-musl ;;
    mipsel) TARGET=mipsel-unknown-linux-musl ;;
    mips64) TARGET=mips64-unknown-linux-muslabi64 ;;
    mips64el) TARGET=mips64el-unknown-linux-muslabi64 ;;
    s390x) TARGET=s390x-unknown-linux-musl ;;
    x86_64|aarch64|arm64) echo "Already officially supported; use Hub install.sh" >&2; exit 2 ;;
    *) echo "Unknown architecture; pass --target if a build exists" >&2; exit 2 ;;
  esac
fi
case "$TARGET" in
  armv7-unknown-linux-musleabihf|armv7-unknown-linux-musleabi|\
  arm-unknown-linux-musleabihf|arm-unknown-linux-musleabi|\
  armv5te-unknown-linux-musleabi|i686-unknown-linux-musl|\
  i586-unknown-linux-musl|riscv64gc-unknown-linux-musl|\
  loongarch64-unknown-linux-musl|powerpc64le-unknown-linux-musl|\
  powerpc64-unknown-linux-musl|mips-unknown-linux-musl|\
  mipsel-unknown-linux-musl|mips64-unknown-linux-muslabi64|\
  mips64el-unknown-linux-muslabi64|s390x-unknown-linux-musl) : ;;
  *) echo "Not a listed extra build: $TARGET" >&2; exit 2 ;;
esac

# Download and verify before stopping the current process.
filename="monitor-agent-$TARGET"
base="https://github.com/$REPO/releases/latest/download"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl -fLSs --retry 3 --connect-timeout 10 --max-time 240 \
  -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"
expected=$(awk -v f="$filename" '$2 == f {print $1}' "$tmp/SHA256SUMS")
[ -n "$expected" ] || { echo "Release lacks $filename. Check Actions." >&2; exit 1; }
curl -fLSs --retry 3 --connect-timeout 10 --max-time 240 \
  -o "$tmp/$filename" "$base/$filename"
printf '%s  %s\n' "$expected" "$tmp/$filename" | sha256sum -c - >/dev/null
chmod 755 "$tmp/$filename"
("$tmp/$filename" --help 2>&1 || :) | grep -q 'monitor-agent' || {
  echo "Binary not executable on this CPU/ABI" >&2
  exit 1
}
echo "Verified $filename"

init=manual
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
  init=systemd
elif command -v rc-service >/dev/null 2>&1 && command -v rc-status >/dev/null 2>&1 && rc-status --runlevel >/dev/null 2>&1; then
  init=openrc
fi

if [ "$init" != manual ] && ! id -u monitor-agent >/dev/null 2>&1; then
  if command -v useradd >/dev/null 2>&1; then
    useradd --system --user-group --no-create-home --shell /usr/sbin/nologin monitor-agent
  else
    addgroup -S monitor-agent 2>/dev/null || :
    adduser -S -D -H -G monitor-agent -s /sbin/nologin monitor-agent
  fi
fi
if [ "$init" != manual ]; then
  id -Gn monitor-agent | tr ' ' '\n' | grep -qx monitor-agent || {
    echo "Service account must belong to monitor-agent group" >&2; exit 1;
  }
fi

install -d -m 0755 "$ROOT"
install -m 0755 "$tmp/$filename" "$ROOT/.monitor-agent-new.$$"

# Stop only our manual process, if a PID file identifies the monitor-agent executable.
if [ "$init" = manual ] && [ -f "$PIDFILE" ]; then
  oldpid=$(cat "$PIDFILE")
  case "$oldpid" in ''|*[!0-9]*) oldpid=0 ;; esac
  if [ "$oldpid" -gt 1 ] && [ -e "/proc/$oldpid/exe" ]; then
    exe=$(readlink "/proc/$oldpid/exe" || :)
    case "$exe" in "$BIN"|"$BIN (deleted)") kill "$oldpid" 2>/dev/null || : ;; esac
  fi
fi
if [ "$init" = systemd ]; then systemctl stop monitor-agent 2>/dev/null || :; fi
if [ "$init" = openrc ]; then rc-service monitor-agent stop 2>/dev/null || :; fi
[ ! -e "$BIN" ] || cp "$BIN" "$BIN.old"
mv -f "$ROOT/.monitor-agent-new.$$" "$BIN"

cat > "$WRAPPER" <<'EOF'
#!/bin/sh
set -eu
. /opt/monitor/agent.env
export MONITOR_SERVER MONITOR_TOKEN MONITOR_IFACE
set -- --interval "$MONITOR_INTERVAL"
[ "$MONITOR_INSECURE" = 1 ] && set -- "$@" --insecure
exec /opt/monitor/monitor-agent "$@"
EOF
chmod 0755 "$WRAPPER"
(
  umask 077
  {
    printf 'MONITOR_SERVER=%s\n' "$SERVER"
    printf 'MONITOR_TOKEN=%s\n' "$TOKEN"
    printf 'MONITOR_IFACE=%s\n' "$IFACE"
    printf 'MONITOR_INTERVAL=%s\n' "$INTERVAL"
    printf 'MONITOR_INSECURE=%s\n' "$INSECURE"
  } > "$ENVFILE"
)
if [ "$init" != manual ]; then
  chown root:monitor-agent "$ENVFILE"
  chmod 0640 "$ENVFILE"
fi
printf '%s\n' "$TARGET" > "$MARKER"

start_manual() {
  nohup "$WRAPPER" >>"$LOG" 2>&1 </dev/null &
  echo $! > "$PIDFILE"
  sleep 3
  kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

rollback() {
  echo "Agent failed to start; restoring old binary if present" >&2
  if [ -e "$BIN.old" ]; then
    mv -f "$BIN.old" "$BIN"
    if [ "$init" = systemd ]; then systemctl restart monitor-agent 2>/dev/null || :; fi
    if [ "$init" = openrc ]; then rc-service monitor-agent restart 2>/dev/null || :; fi
    if [ "$init" = manual ]; then start_manual || :; fi
  fi
  exit 1
}

if [ "$init" = systemd ]; then
  cat > "$UNIT" <<'EOF'
[Unit]
Description=monitor agent (extra architectures)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=monitor-agent
ExecStart=/opt/monitor/run-agent.sh
Restart=always
RestartSec=5
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable monitor-agent >/dev/null
  systemctl restart monitor-agent || rollback
  sleep 3
  systemctl is-active --quiet monitor-agent || rollback
  echo "Agent active: systemctl status monitor-agent"
elif [ "$init" = openrc ]; then
  cat > "$RC" <<'EOF'
#!/sbin/openrc-run
description="monitor agent (extra architectures)"
command="/opt/monitor/run-agent.sh"
command_user="monitor-agent"
supervisor="supervise-daemon"
respawn_delay=5
output_log="/var/log/monitor-agent.log"
error_log="/var/log/monitor-agent.log"
depend() { need net; }
start_pre() { checkpath --file --owner monitor-agent --mode 0600 /var/log/monitor-agent.log; }
EOF
  chmod 0755 "$RC"
  rc-update add monitor-agent default >/dev/null
  rc-service monitor-agent restart || rollback
  sleep 3
  pidof monitor-agent >/dev/null 2>&1 || rollback
  echo "Agent active: rc-service monitor-agent status"
else
  start_manual || rollback
  echo "Agent started manually (PID $(cat "$PIDFILE"))."
  echo "IMPORTANT: configure container startup to run $WRAPPER after reboot."
fi
rm -f "$BIN.old"
echo "Installed $TARGET. Hub and node token preserved on upgrades."
