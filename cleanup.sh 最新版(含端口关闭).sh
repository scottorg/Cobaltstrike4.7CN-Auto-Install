#!/bin/bash
# ============================================================
#  Cobalt Strike 一键恢复脚本 (还原服务器初始状态)
#  ------------------------------------------------------------
#  删除内容:
#    1. 运行中的 CS 进程
#    2. /root 下的所有 CS 文件(teamserver、TeamServerImage、jar等)
#    3. 下载的压缩包 + 安装脚本(包括本脚本自己)
#    4. Java 11 (Temurin) + Adoptium 软件源
#    5. 防火墙规则 (54321 + 7771:7999)
#  用法: bash cleanup.sh
# ============================================================

set -e
G='\033[32m'; R='\033[31m'; Y='\033[33m'; N='\033[0m'
info(){ echo -e "${G}[*]${N} $1"; }
warn(){ echo -e "${Y}[!]${N} $1"; }

[ "$(id -u)" -eq 0 ] || { echo -e "${R}[x]${N} 请用 root 运行"; exit 1; }

# 安装目录(默认 /root, 与 install.sh 保持一致)
HOME_DIR="${HOME_DIR:-/root}"

# ---------- 1. 停止 CS 进程 ----------
info "停止 CS 进程..."
pkill -f "teamserver" 2>/dev/null && info "已停止 teamserver" || warn "没有运行中的 teamserver"
pkill -f "TeamServerImage" 2>/dev/null || true

# ---------- 2. 删除 /root 下的 CS 文件 ----------
info "删除 CS 文件..."
CS_FILES="teamserver TeamServerImage TeamServerImage_* cobaltstrike cobaltstrike.jar cobaltstrike-client.jar cobaltstrike.bat cobaltstrike.sh cobaltstrike.auth cobaltstrike.store CSAgent.jar CSAgent.properties CobaltStrike.vbs TeamServer.prop agscript c2lint keytool logparse peclone resources scripts third-party aggressor data includes help docs updates .cobaltstrike.beacon_keys favicon.ico icon.ico .DS_Store"
for f in $CS_FILES; do
  rm -rf "$HOME_DIR/$f" 2>/dev/null || true
done
info "CS 文件已删除"

# ---------- 3. 删除压缩包和脚本 ----------
rm -f "$HOME_DIR/cobaltstrike.tar.gz" "$HOME_DIR/cobaltstrike-slim.tar.gz" "$HOME_DIR/install.sh" "$HOME_DIR/cleanup.sh" 2>/dev/null || true
info "已删除压缩包和安装脚本"

# ---------- 4. 卸载 Java 11 (Temurin) ----------
info "卸载 Java 11..."
if command -v apt-get >/dev/null 2>&1; then
  apt purge -y temurin-11-jdk 2>/dev/null || true
  apt autoremove -y 2>/dev/null || true
else
  yum remove -y java-11-openjdk-devel 2>/dev/null || dnf remove -y java-11-openjdk-devel 2>/dev/null || true
fi
rm -f /etc/apt/sources.list.d/adoptium.list /etc/apt/trusted.gpg.d/adoptium.gpg 2>/dev/null || true
hash -r
if command -v java >/dev/null 2>&1; then
  warn "Java 仍存在: $(java -version 2>&1 | head -1), 请手动卸载"
else
  info "Java 已卸载"
fi

# ---------- 5. 删除防火墙规则 (54321 + 7771:7999) ----------
delete_rule(){
  # $1=协议(tcp/udp)  $2=端口或范围(如 54321 或 7771:7999)
  local proto="$1" p="$2"
  local fw_syntax="${p//:/-}"
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw delete allow "$p/$proto" >/dev/null 2>&1 && info "ufw 已删除 $p/$proto" || true
  elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
    firewall-cmd --permanent --remove-port="$fw_syntax/$proto" >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
    info "firewalld 已删除 $fw_syntax/$proto"
  else
    if [[ "$p" == *:* ]]; then
      iptables -D INPUT -p "$proto" -m multiport --dport "$p" -j ACCEPT 2>/dev/null && info "iptables 已删除 $p/$proto" || true
    else
      iptables -D INPUT -p "$proto" --dport "$p" -j ACCEPT 2>/dev/null && info "iptables 已删除 $p/$proto" || true
    fi
  fi
}
delete_rule tcp 54321
delete_rule tcp 7771:7999
delete_rule udp 7771:7999

echo -e "\n${G}============================================================"
echo -e "  恢复完成! 服务器已回到初始状态"
echo -e "============================================================${N}"
