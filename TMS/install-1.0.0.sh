#!/usr/bin/env bash
set -Eeuo pipefail

# ToMinerSystem TMS Ubuntu x86_64 二进制安装器。
# 默认从 TMS/linux 目录读取 tms-local-linux-x86_64。
# 也可将 TMS_DOWNLOAD_BASE_URL 设为 GitHub 项目根目录的 raw 地址。

readonly SERVICE_NAME="tominersystem-tms"
readonly SERVICE_USER="tominersystem-tms"
readonly INSTALL_DIR="${TMS_LOCAL_INSTALL_DIR:-/opt/tominersystem-tms}"
readonly CONFIG_DIR="${TMS_LOCAL_CONFIG_DIR:-/etc/tominersystem-tms}"
readonly CONFIG_FILE="${CONFIG_DIR}/local-relay.toml"
readonly WEB_PORT_FILE="${CONFIG_DIR}/web-port"
readonly BINARY_NAME="tms-local-linux-x86_64-1.0.0"
readonly EXPECTED_SHA256="97ca7411cabd605af5d2fd64b1ed589ee14d3798c3c268c0fe4fb8fb11a13fd7"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DOWNLOAD_BASE_URL="${TMS_DOWNLOAD_BASE_URL:-https://github.com/ToMinerSystem/ToMinerSystem/raw/main/1.0.0/TMS/linux}"
readonly WEB_PORT_MIN=52347
readonly WEB_PORT_MAX=61892

temporary_binary=""
source_binary=""

cleanup() {
  if [[ -n "${temporary_binary}" && -f "${temporary_binary}" ]]; then
    rm -f -- "${temporary_binary}"
  fi
}
trap cleanup EXIT

fail() {
  echo "错误：$*" >&2
  exit 1
}

require_root_ubuntu_x86_64() {
  [[ "${EUID}" -eq 0 ]] || fail "请使用 root 权限运行：sudo bash install-tms.sh ${1:-install}"
  [[ -r /etc/os-release ]] || fail "无法识别操作系统"
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || fail "仅支持 Ubuntu，当前系统为 ${PRETTY_NAME:-unknown}"
  [[ "$(uname -m)" == "x86_64" ]] || fail "当前发布包仅支持 x86_64，检测到 $(uname -m)"
  command -v systemctl >/dev/null 2>&1 || fail "当前环境没有 systemd"
}

port_is_listening() {
  local port="$1"
  ss -H -ltn 2>/dev/null | awk -v expected="${port}" '
    { value=$4; sub(/^.*:/, "", value); if (value == expected) found=1 }
    END { exit(found ? 0 : 1) }
  '
}

random_web_port() {
  local random_value candidate
  for _ in $(seq 1 256); do
    random_value="$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')"
    candidate=$((WEB_PORT_MIN + random_value % (WEB_PORT_MAX - WEB_PORT_MIN + 1)))
    if ! port_is_listening "${candidate}"; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

local_ip() {
  local detected
  detected="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"
  if [[ -z "${detected}" ]]; then
    detected="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  echo "${detected:-127.0.0.1}"
}

obtain_binary() {
  local local_binary="${SCRIPT_DIR}/linux/${BINARY_NAME}"
  if [[ -f "${local_binary}" ]]; then
    source_binary="${local_binary}"
    return 0
  fi
  [[ -n "${DOWNLOAD_BASE_URL}" ]] || fail \
    "未找到 TMS/linux/${BINARY_NAME}。请下载完整项目目录，或设置 TMS_DOWNLOAD_BASE_URL"
  temporary_binary="$(mktemp)"
  curl --fail --location --proto '=https' --tlsv1.2 \
    "${DOWNLOAD_BASE_URL%/}/TMS/linux/${BINARY_NAME}" \
    --output "${temporary_binary}"
  source_binary="${temporary_binary}"
}

verify_elf() {
  local binary="$1" magic actual_sha256
  magic="$(od -An -N4 -tx1 "${binary}" | tr -d ' \n')"
  [[ "${magic}" == "7f454c46" ]] || fail "${BINARY_NAME} 不是 Linux ELF 程序"
  actual_sha256="$(sha256sum "${binary}" | awk '{print $1}')"
  [[ "${actual_sha256}" == "${EXPECTED_SHA256}" ]] \
    || fail "${BINARY_NAME} SHA-256 校验失败"
}

install_tms() {
  local web_port detected_ip
  require_root_ubuntu_x86_64 install

  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl iproute2

  obtain_binary
  verify_elf "${source_binary}"

  if ! getent group "${SERVICE_USER}" >/dev/null 2>&1; then
    groupadd --system "${SERVICE_USER}"
  fi
  if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
    useradd --system --gid "${SERVICE_USER}" --home-dir "${CONFIG_DIR}" \
      --no-create-home --shell /usr/sbin/nologin "${SERVICE_USER}"
  fi
  install -d -o root -g root -m 0755 "${INSTALL_DIR}" "${INSTALL_DIR}/bin"
  install -d -o "${SERVICE_USER}" -g "${SERVICE_USER}" -m 0750 "${CONFIG_DIR}"
  install -o root -g root -m 0755 "${source_binary}" \
    "${INSTALL_DIR}/bin/tms-local.new"
  mv -f -- "${INSTALL_DIR}/bin/tms-local.new" "${INSTALL_DIR}/bin/tms-local"

  if [[ -r "${WEB_PORT_FILE}" ]]; then
    web_port="$(tr -dc '0-9' < "${WEB_PORT_FILE}")"
  else
    web_port="$(random_web_port)" || fail "无法找到空闲 Web 端口"
    printf '%s\n' "${web_port}" > "${WEB_PORT_FILE}"
  fi
  if [[ ! "${web_port}" =~ ^[0-9]{5}$ ]] \
    || (( 10#${web_port} < WEB_PORT_MIN || 10#${web_port} > WEB_PORT_MAX )); then
    fail "保存的 Web 端口无效：${web_port}"
  fi

  if [[ ! -f "${CONFIG_FILE}" ]]; then
    cat > "${CONFIG_FILE}" <<'EOF'
log_level = "info"
web_identity = ""
identity_confirmed = false
routes = []
EOF
  else
    echo "保留已保存的 TMS 识别码和线路配置：${CONFIG_FILE}"
  fi
  chown -R "${SERVICE_USER}:${SERVICE_USER}" "${CONFIG_DIR}"
  chmod 0750 "${CONFIG_DIR}"
  chmod 0640 "${CONFIG_FILE}" "${WEB_PORT_FILE}"

  "${INSTALL_DIR}/bin/tms-local" --config "${CONFIG_FILE}" --check

  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=ToMinerSystem local encrypted TMS relay
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${CONFIG_DIR}
ExecStart=${INSTALL_DIR}/bin/tms-local --headless --web-listen 127.0.0.1:${web_port} --config ${CONFIG_FILE}
Restart=always
RestartSec=3s
TimeoutStopSec=20s
LimitNOFILE=65535
UMask=0027
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=${CONFIG_DIR}

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}.service"
  sleep 2
  systemctl is-active --quiet "${SERVICE_NAME}.service" || {
    systemctl status "${SERVICE_NAME}.service" --no-pager --full || true
    journalctl -u "${SERVICE_NAME}.service" -n 100 --no-pager || true
    fail "TMS 服务启动失败"
  }
  curl --fail --silent --show-error "http://127.0.0.1:${web_port}/api/status" >/dev/null \
    || fail "TMS Web 健康检查失败"

  detected_ip="$(local_ip)"
  echo ""
  echo "TMS 安装完成并已设置开机自启动。"
  echo "Web 端口：${web_port}"
  echo "本机访问：http://127.0.0.1:${web_port}/"
  echo "远程访问：ssh -L ${web_port}:127.0.0.1:${web_port} <用户>@${detected_ip}"
  echo "打开 Web 后输入 ToMinerSystem 管理端生成的 TMS 配对码；识别码会自动保存并连接。"
  echo "配置文件：${CONFIG_FILE}"
  echo "查看日志：journalctl -u ${SERVICE_NAME} -f"
}

uninstall_tms() {
  require_root_ubuntu_x86_64 uninstall
  systemctl disable --now "${SERVICE_NAME}.service" 2>/dev/null || true
  rm -f -- "/etc/systemd/system/${SERVICE_NAME}.service"
  systemctl daemon-reload
  rm -f -- "${INSTALL_DIR}/bin/tms-local"
  rmdir -- "${INSTALL_DIR}/bin" "${INSTALL_DIR}" 2>/dev/null || true
  echo "TMS 程序已卸载；识别码和线路配置保留在 ${CONFIG_DIR}。"
}

command_name="${1:-install}"
case "${command_name}" in
  install) install_tms ;;
  start|stop|restart)
    require_root_ubuntu_x86_64 "${command_name}"
    systemctl "${command_name}" "${SERVICE_NAME}.service"
    systemctl status "${SERVICE_NAME}.service" --no-pager --full
    ;;
  status)
    require_root_ubuntu_x86_64 status
    systemctl status "${SERVICE_NAME}.service" --no-pager --full
    ;;
  web-port)
    require_root_ubuntu_x86_64 web-port
    cat "${WEB_PORT_FILE}"
    ;;
  uninstall) uninstall_tms ;;
  *)
    echo "用法：sudo bash install-tms.sh {install|start|stop|restart|status|web-port|uninstall}" >&2
    exit 2
    ;;
esac
