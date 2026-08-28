#!/usr/bin/env bash
# 安全重启 DSH web 守护脚本
# 用法: bash restart-web.sh
set -u
PORT="${1:-3080}"
PROF=~/.dsh/profiles/web
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP="$PROF/backup_$DATE"
LOGFILE="$PROF/restart_$DATE.log"
export PATH="/Users/wangchen/.nvm/versions/node/v22.23.2/bin:$PATH"

log(){ echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOGFILE"; }

# 1) 检测当前 web PID
OLD_PID=$(lsof -ti tcp:$PORT -sTCP:LISTEN 2>/dev/null | head -1)
log "port $PORT current PID: ${OLD_PID:-none}"

# 2) 备份 profile 配置
mkdir -p "$BACKUP"
cp "$PROF/package.json" "$BACKUP/package.json" 2>/dev/null
[ -f "$PROF/pnpm-workspace.yaml" ] && cp "$PROF/pnpm-workspace.yaml" "$BACKUP/" 2>/dev/null
log "backup -> $BACKUP"

# 3) kill 旧 web
if [ -n "${OLD_PID:-}" ]; then
  log "killing old web $OLD_PID"
  kill "$OLD_PID" 2>/dev/null
  sleep 3
  PGID=$(ps -o ppid= -p "$OLD_PID" 2>/dev/null | tr -d ' ')
  [ -n "$PGID" ] && kill "$PGID" 2>/dev/null
fi

# 4) 后台拉起新 web
log "starting new web on port $PORT ..."
nohup dsh --profile web >>"$LOGFILE" 2>&1 &
NEW_PID=$!
log "new web launched pid=$NEW_PID (wrapper)"

# 5) 健康检查 / 1 分钟未接管则回退
START=$(date +%s)
OK=0
while [ $(( $(date +%s) - START )) -lt 60 ]; do
  if lsof -ti tcp:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
    log "OK: port $PORT listening (took $(( $(date +%s) - START ))s)"
    OK=1; break
  fi
  sleep 3
done

if [ "$OK" != "1" ]; then
  log "FAIL: not listening within 60s -> ROLLBACK"
  # 回退：恢复备份的 profile 配置，再试一次
  cp "$BACKUP/package.json" "$PROF/package.json" 2>/dev/null
  kill "$NEW_PID" 2>/dev/null; sleep 2
  nohup dsh --profile web >>"$LOGFILE" 2>&1 &
  log "rolled back profile config and relaunched; check $LOGFILE"
  exit 1
fi
log "restart OK. Profile bundles preserved."
