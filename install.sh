#!/bin/bash
# ============================================================
#  Cobalt Strike 4.7 一键安装脚本 (教学版 v3)
#  ------------------------------------------------------------
#  特点: 自动下载并配置到 /root 文件夹, 登录后直接:
#        ./teamserver <服务器IP> admin123   即可启动, 不用 cd
#  用法:
#    bash install.sh                 # 自动下载(默认GitHub直链)并安装
#    bash install.sh <下载直链>      # 自定义下载地址
#    bash install.sh                 # 本地已有 /root/cobaltstrike.tar.gz 时直接使用
#  支持系统: Ubuntu 24 / Debian / Kali / CentOS / Rocky
# ============================================================

# ---------- 可配置参数 ----------
CS_PASSWORD="admin123"                         # 登录密码(与教学一致)
CS_PORT="54321"                                # teamserver 端口
CS_EXTRA_PORTS="7771:7999"                     # 额外放行端口范围(TCP+UDP)
CS_INSTALL_DIR="${CS_INSTALL_DIR:-/root}"      # 安装目录(默认 /root, 登录即可用)
CS_ARCHIVE="/root/cobaltstrike.tar.gz"         # 本地压缩包路径
CS_DOWNLOAD_URL="${1:-https://github.com/scottorg/Cobaltstrike4.7CN-Auto-Install/releases/download/v1/CobaltStrike4.7.tar.gz}"   # 默认从 GitHub Release 下载, 也可用参数覆盖
# ------------------------------

set -e
G='\033[32m'; R='\033[31m'; Y='\033[33m'; N='\033[0m'
info(){ echo -e "${G}[*]${N} $1"; }
warn(){ echo -e "${Y}[!]${N} $1"; }
err(){  echo -e "${R}[x]${N} $1"; }

# ---------- 1. root 权限检查 ----------
[ "$(id -u)" -eq 0 ] || { err "请用 root 运行: sudo bash install.sh"; exit 1; }

# ---------- 2. 系统识别 ----------
[ -f /etc/os-release ] && . /etc/os-release
OS="${ID:-unknown}"
info "检测到系统: $PRETTY_NAME"
case "$OS" in
  ubuntu|debian|kali)                 PKG="apt" ;;
  centos|rhel|rocky|almalinux|fedora) PKG="yum" ;;
  *) warn "未知系统 $OS, 按 Debian 系处理"; PKG="apt" ;;
esac

# ---------- 3. 安装 Java 11 ----------
install_java(){
  if command -v java >/dev/null 2>&1; then
    JV=$(java -version 2>&1 | head -1)
    if echo "$JV" | grep -qE '"(11|1\.8)'; then
      info "Java 已就绪: $JV"
      return 0
    fi
    warn "当前 Java ($JV) 不是 11, 将安装 OpenJDK 11"
  fi
  if [ "$PKG" = "apt" ]; then
    # Ubuntu 24 官方源无 Java11, 使用 Adoptium(Temurin) 源
    apt-get update -y
    apt-get install -y wget curl gpg apt-transport-https
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/adoptium.gpg
    echo "deb https://packages.adoptium.net/artifactory/deb ${VERSION_CODENAME:-noble} main" > /etc/apt/sources.list.d/adoptium.list
    apt-get update -y
    apt-get install -y temurin-11-jdk
  else
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y java-11-openjdk-devel
    else
      yum install -y java-11-openjdk-devel
    fi
  fi
  hash -r
  info "Java 11 安装完成: $(java -version 2>&1 | head -1)"
}

# ---------- 4. 下载 CS 包(GitHub) ----------
download_cs(){
  if [ -f "$CS_ARCHIVE" ]; then
    info "使用本地压缩包: $CS_ARCHIVE"
  elif [ -n "$CS_DOWNLOAD_URL" ]; then
    info "从 GitHub 下载 CS, 请稍候..."
    info "URL: $CS_DOWNLOAD_URL"
    curl -L --fail --progress-bar -o "$CS_ARCHIVE" "$CS_DOWNLOAD_URL"
    [ -s "$CS_ARCHIVE" ] || { err "下载失败, 请检查链接"; exit 1; }
    info "下载完成: $CS_ARCHIVE"
  else
    warn "未提供下载链接, 本地也没有 $CS_ARCHIVE"
    err "用法: bash install.sh <GitHub下载直链>"
    exit 1
  fi
}

# ---------- 5. 解压部署到 /root (自动识别嵌套目录) ----------
find_cs_root(){
  local base="$1"
  [ -f "$base/teamserver" ] && { echo "$base"; return; }
  for d in "$base"/*/; do
    [ -f "$d/teamserver" ] && { echo "${d%/}"; return; }
  done
  echo ""
}

deploy_cs(){
  local csroot=""
  mkdir -p /tmp/cs_extract
  case "$CS_ARCHIVE" in
    *.zip) unzip -o -q "$CS_ARCHIVE" -d /tmp/cs_extract ;;
    *)     tar --no-xattrs -xzf "$CS_ARCHIVE" -C /tmp/cs_extract ;;
  esac
  csroot=$(find_cs_root /tmp/cs_extract)
  if [ -z "$csroot" ]; then
    rm -rf /tmp/cs_extract
    err "压缩包里没找到 teamserver 文件, 请确认包内容"
    exit 1
  fi
  # 平铺复制到安装目录(/root), 这样登录后直接 ./teamserver 即可
  cp -r "$csroot"/* "$CS_INSTALL_DIR/"
  rm -rf /tmp/cs_extract
  # 授予执行权限
  chmod +x "$CS_INSTALL_DIR"/teamserver "$CS_INSTALL_DIR"/TeamServerImage 2>/dev/null || true
  info "CS 已安装到 $CS_INSTALL_DIR"
}

# ---------- 6. 修改 teamserver 端口为 54321 ----------
set_port(){
  local ts="$CS_INSTALL_DIR/teamserver"
  if grep -q "^PORT=" "$ts" 2>/dev/null; then
    if grep -q "^PORT=$CS_PORT" "$ts"; then
      info "端口已是 $CS_PORT, 无需修改"
    else
      sed -i "s/^PORT=[0-9]*/PORT=$CS_PORT/" "$ts"
      info "端口已改为 $CS_PORT: $(grep '^PORT=' "$ts" | head -1)"
    fi
  elif grep -q "54321" "$ts" 2>/dev/null; then
    info "端口已是 $CS_PORT, 无需修改"
  else
    warn "teamserver 中未找到端口配置, 若启动端口不是 $CS_PORT 请自行检查"
  fi
}

# ---------- 7. 获取服务器公网IP(仅IPv4) ----------
get_ip(){
  local ip=""
  # 优先强制走 IPv4 获取公网IP
  if command -v curl >/dev/null 2>&1; then
    ip=$(curl -4 -s --max-time 5 ifconfig.me || curl -4 -s --max-time 5 ipv4.icanhazip.com || true)
  fi
  if [ -z "$ip" ]; then
    # 兜底: 取本机网卡的第一个 IPv4 地址
    ip=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | head -1)
  fi
  echo "$ip"
}

# ---------- 8. 放行防火墙端口(支持单端口和范围) ----------
open_port(){
  # $1=协议(tcp/udp)  $2=端口或范围(如 54321 或 7771:7999)
  local proto="$1" p="$2"
  local fw_syntax="${p//:/-}"   # firewalld 用 7771-7999 语法
  if [ "$PKG" = "apt" ]; then
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
      ufw allow "$p/$proto" >/dev/null 2>&1 && info "ufw 已放行 $p/$proto"
    else
      if [[ "$p" == *:* ]]; then
        iptables -I INPUT -p "$proto" -m multiport --dport "$p" -j ACCEPT 2>/dev/null && info "iptables 已放行 $p/$proto"
      else
        iptables -I INPUT -p "$proto" --dport "$p" -j ACCEPT 2>/dev/null && info "iptables 已放行 $p/$proto"
      fi
    fi
  else
    if systemctl is-active firewalld >/dev/null 2>&1; then
      firewall-cmd --permanent --add-port="$fw_syntax/$proto" >/dev/null 2>&1
      firewall-cmd --reload >/dev/null 2>&1
      info "firewalld 已放行 $fw_syntax/$proto"
    else
      if [[ "$p" == *:* ]]; then
        iptables -I INPUT -p "$proto" -m multiport --dport "$p" -j ACCEPT 2>/dev/null && info "iptables 已放行 $p/$proto"
      else
        iptables -I INPUT -p "$proto" --dport "$p" -j ACCEPT 2>/dev/null && info "iptables 已放行 $p/$proto"
      fi
    fi
  fi
}

# ================= 主流程 =================
info "========== Cobalt Strike 一键安装开始 =========="
install_java
download_cs
deploy_cs
set_port
IP=$(get_ip)
[ -z "$IP" ] && IP="<你的服务器IP>"
info "服务器公网IP: $IP"
open_port tcp "$CS_PORT"
open_port tcp "$CS_EXTRA_PORTS"
open_port udp "$CS_EXTRA_PORTS"

echo -e "\n${G}============================================================"
echo -e "  安装完成! 启动服务端（链接密码自己修改）:"
echo -e "------------------------------------------------------------"
echo -e "  ./teamserver $IP admin123"
echo -e "============================================================"
echo -e "  客户端连接信息(Windows客户端填写):"
echo -e "------------------------------------------------------------"
echo -e "  别名   : 自定义"
echo -e "  主机   : $IP"
echo -e "  端口   : $CS_PORT"
echo -e "  用户   : 自定义"
echo -e "  密码   : 上方启动服务端时输入的密码"
echo -e "============================================================${N}"
echo -e "${Y}[!] 提示: 若连不上, 到云服务器控制台安全组放行 TCP $CS_PORT 与 $CS_EXTRA_PORTS${N}"
