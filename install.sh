#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.0.0"

# Customer customization: change this block for white-label builds.
APP_NAME="ToMinerSystem"
APP_ID="tominersystem"
DOWNLOAD_HOST="https://github.com/ToMinerSystem/ToMinerSystem/raw/main/linux"

SERVICE_NAME="tominersystem"

# ToMinerSystem Ubuntu/Debian/CentOS x86_64 二进制安装器。
# 默认从项目的 linux 目录读取 tominersystem-server-linux-x86_64。
# 远程下载目录统一在上方 DOWNLOAD_HOST 中修改。
# TMS_DOWNLOAD_BASE_URL 环境变量仍可在单次安装时覆盖该地址。

readonly VERSION APP_NAME APP_ID DOWNLOAD_HOST SERVICE_NAME
readonly SERVICE_USER="${APP_ID}"
readonly INSTALL_DIR="${TMS_INSTALL_DIR:-/opt/${APP_ID}}"
readonly CONFIG_DIR="${TMS_CONFIG_DIR:-/etc/${APP_ID}}"
readonly CONFIG_FILE="${CONFIG_DIR}/config.toml"
readonly WEB_PORT_FILE="${CONFIG_DIR}/web-port"
readonly BOOTSTRAP_PORT_FILE="${CONFIG_DIR}/bootstrap-listener-port"
readonly INSTALLED_VERSION_FILE="${CONFIG_DIR}/installed-version"
readonly BINARY_NAME="ToMinerSystem-1.0.0"
readonly EXPECTED_SHA256="a5ac6e9a8c5583bf4dec64d134dea945a7051a9d99c2522fb723e5685ebe3741"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly DOWNLOAD_BASE_URL="${TMS_DOWNLOAD_BASE_URL:-${DOWNLOAD_HOST}}"
readonly RELEASE_RAW_ROOT="https://github.com/ToMinerSystem/ToMinerSystem/raw/main"
readonly RELEASE_API_URL="https://api.github.com/repos/ToMinerSystem/ToMinerSystem/contents?ref=main"
readonly WEB_PORT_MIN=52347
readonly WEB_PORT_MAX=61892
readonly BOOTSTRAP_PORT_MIN=30000
readonly BOOTSTRAP_PORT_MAX=49151

OS_ID=""
OS_PRETTY_NAME=""
PACKAGE_FAMILY=""
NOLOGIN_SHELL="/sbin/nologin"
SYSTEMD_PROTECT_SYSTEM="strict"
SYSTEMD_WRITE_DIRECTIVE="ReadWritePaths"

temporary_binary=""
temporary_installer=""
source_binary=""

cleanup() {
  if [[ -n "${temporary_binary}" && -f "${temporary_binary}" ]]; then
    rm -f -- "${temporary_binary}"
  fi
  if [[ -n "${temporary_installer}" && -f "${temporary_installer}" ]]; then
    rm -f -- "${temporary_installer}"
  fi
}
trap cleanup EXIT

fail() {
  echo "错误：$*" >&2
  exit 1
}

detect_supported_linux() {
  local systemd_version
  [[ "${EUID}" -eq 0 ]] || fail "请使用 root 权限运行：sudo bash install-server.sh ${1:-install}"
  [[ -r /etc/os-release ]] || fail "无法识别操作系统"
  # /etc/os-release 也定义 VERSION，不 source，避免覆盖脚本版本变量。
  OS_ID="$(awk -F= '$1 == "ID" { value=$2; gsub(/^"|"$/, "", value); print tolower(value); exit }' /etc/os-release)"
  OS_PRETTY_NAME="$(awk -F= '$1 == "PRETTY_NAME" { value=substr($0, index($0, "=") + 1); gsub(/^"|"$/, "", value); print value; exit }' /etc/os-release)"
  case "${OS_ID}" in
    ubuntu|debian) PACKAGE_FAMILY="debian" ;;
    centos) PACKAGE_FAMILY="centos" ;;
    *) fail "仅支持 Ubuntu、Debian 和 CentOS，当前系统为 ${OS_PRETTY_NAME:-unknown}" ;;
  esac
  [[ "$(uname -m)" == "x86_64" ]] || fail "当前发布包仅支持 x86_64，检测到 $(uname -m)"
  command -v systemctl >/dev/null 2>&1 || fail "当前环境没有 systemd"
  if command -v nologin >/dev/null 2>&1; then
    NOLOGIN_SHELL="$(command -v nologin)"
  fi
  systemd_version="$(systemctl --version | awk 'NR == 1 { print $2; exit }')"
  if [[ "${systemd_version}" =~ ^[0-9]+$ ]] && (( systemd_version < 231 )); then
    # CentOS 7 的 systemd 219 使用旧指令名称。
    SYSTEMD_PROTECT_SYSTEM="full"
    SYSTEMD_WRITE_DIRECTIVE="ReadWriteDirectories"
  fi
}

install_dependencies() {
  case "${PACKAGE_FAMILY}" in
    debian)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y --no-install-recommends \
        ca-certificates curl iproute2 openssl
      ;;
    centos)
      if command -v dnf >/dev/null 2>&1; then
        dnf install -y ca-certificates curl iproute openssl shadow-utils
      elif command -v yum >/dev/null 2>&1; then
        yum install -y ca-certificates curl iproute openssl shadow-utils
      else
        fail "CentOS 系统中未找到 dnf 或 yum"
      fi
      update-ca-trust 2>/dev/null || true
      ;;
    *) fail "未初始化系统包管理器" ;;
  esac
}

port_is_listening() {
  local port="$1"
  ss -H -ltn 2>/dev/null | awk -v expected="${port}" '
    { value=$4; sub(/^.*:/, "", value); if (value == expected) found=1 }
    END { exit(found ? 0 : 1) }
  '
}

random_available_port() {
  local minimum="$1" maximum="$2" random_value candidate
  for _ in $(seq 1 256); do
    random_value="$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')"
    candidate=$((minimum + random_value % (maximum - minimum + 1)))
    if ! port_is_listening "${candidate}"; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

server_ip() {
  local detected="${TMS_SERVER_IP:-}"
  if [[ -z "${detected}" ]]; then
    detected="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"
  fi
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
    "未找到 linux/${BINARY_NAME}。请下载完整项目目录，或在脚本开头设置 DOWNLOAD_HOST"
  temporary_binary="$(mktemp)"
  curl --fail --location --proto '=https' --tlsv1.2 \
    "${DOWNLOAD_BASE_URL%/}/${BINARY_NAME}" \
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

create_default_config() {
  local web_port="$1" detected_ip="$2" bootstrap_port="$3"
  cat > "${CONFIG_FILE}" <<EOF
[server]
metrics_listen = "0.0.0.0:${web_port}"
admin_state_path = "${CONFIG_DIR}/admin.toml"
session_ttl_secs = 28800
max_connections = 10000
connect_timeout_secs = 10
idle_timeout_secs = 300
max_line_bytes = 1048576

[transport_security]
certificate_path = "${CONFIG_DIR}/tls/server-cert.pem"
private_key_path = "${CONFIG_DIR}/tls/server-key.pem"
server_names = ["localhost", "127.0.0.1", "${detected_ip}"]

# 用于初始化管理页面的本地 BTC 监听。请在 Web 端创建实际使用的端口代理。
[[coins]]
symbol = "BTC"
algorithm = "sha256d"
listen = "127.0.0.1:${bootstrap_port}"
fallback_pools = []
[coins.primary_pool]
address = "127.0.0.1:9"
protocol = "tcp"
[coins.fee]
rate_basis_points = 0
[coins.identity]
worker_suffix_from_peer = false

[logging]
format = "pretty"
level = "info"
log_payloads = false
directory = "${CONFIG_DIR}/logs"
state_directory = "${CONFIG_DIR}/state"
api_max_lines = 500

[smoothing]
ewma_half_life_seconds = 300
minimum_residency_seconds = 60
minimum_switch_interval_seconds = 300
job_drain_timeout_seconds = 10
pause_on_reject_ratio = 0.03
pause_on_stale_ratio = 0.02
pause_on_hashrate_change_ratio = 0.15
controller_kp = 0.8
controller_ki = 0.05
EOF
}

install_server() {
  local web_port bootstrap_port detected_ip initial_password
  detect_supported_linux install
  install_dependencies

  obtain_binary
  verify_elf "${source_binary}"
  detected_ip="$(server_ip)"

  if ! getent group "${SERVICE_USER}" >/dev/null 2>&1; then
    groupadd --system "${SERVICE_USER}"
  fi
  if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
    useradd --system --gid "${SERVICE_USER}" --home-dir "${CONFIG_DIR}" \
      --no-create-home --shell "${NOLOGIN_SHELL}" "${SERVICE_USER}"
  fi
  install -d -o root -g root -m 0755 "${INSTALL_DIR}" "${INSTALL_DIR}/bin"
  install -d -o "${SERVICE_USER}" -g "${SERVICE_USER}" -m 0750 \
    "${CONFIG_DIR}" "${CONFIG_DIR}/tls" "${CONFIG_DIR}/logs" "${CONFIG_DIR}/state"
  install -o root -g root -m 0755 "${source_binary}" \
    "${INSTALL_DIR}/bin/${APP_ID}-server.new"
  mv -f -- "${INSTALL_DIR}/bin/${APP_ID}-server.new" \
    "${INSTALL_DIR}/bin/${APP_ID}-server"

  if [[ -r "${WEB_PORT_FILE}" ]]; then
    web_port="$(tr -dc '0-9' < "${WEB_PORT_FILE}")"
  else
    web_port="$(random_available_port "${WEB_PORT_MIN}" "${WEB_PORT_MAX}")" \
      || fail "无法找到空闲 Web 端口"
    printf '%s\n' "${web_port}" > "${WEB_PORT_FILE}"
  fi
  if [[ ! "${web_port}" =~ ^[0-9]{5}$ ]] \
    || (( 10#${web_port} < WEB_PORT_MIN || 10#${web_port} > WEB_PORT_MAX )); then
    fail "保存的 Web 端口无效：${web_port}"
  fi

  if [[ ! -f "${CONFIG_FILE}" ]]; then
    if [[ -r "${BOOTSTRAP_PORT_FILE}" ]]; then
      bootstrap_port="$(tr -dc '0-9' < "${BOOTSTRAP_PORT_FILE}")"
    else
      bootstrap_port="$(random_available_port "${BOOTSTRAP_PORT_MIN}" "${BOOTSTRAP_PORT_MAX}")" \
        || fail "无法找到空闲的初始监听端口"
      printf '%s\n' "${bootstrap_port}" > "${BOOTSTRAP_PORT_FILE}"
    fi
    create_default_config "${web_port}" "${detected_ip}" "${bootstrap_port}"
  else
    echo "保留已有配置：${CONFIG_FILE}"
  fi

  if [[ ! -f "${CONFIG_DIR}/admin.toml" ]]; then
    initial_password="$(openssl rand -hex 16)"
    printf 'username = "admin"\nbootstrap_password = "%s"\n' "${initial_password}" \
      > "${CONFIG_DIR}/admin.toml"
    printf '%s\n' "${initial_password}" > "${CONFIG_DIR}/INITIAL_ADMIN_PASSWORD"
  fi
  printf '%s\n' "${VERSION}" > "${INSTALLED_VERSION_FILE}"
  chown -R "${SERVICE_USER}:${SERVICE_USER}" "${CONFIG_DIR}"
  chmod 0750 "${CONFIG_DIR}"
  chmod 0640 "${CONFIG_FILE}" "${WEB_PORT_FILE}"
  chmod 0600 "${CONFIG_DIR}/admin.toml"
  chmod 0640 "${BOOTSTRAP_PORT_FILE}" 2>/dev/null || true
  chmod 0640 "${INSTALLED_VERSION_FILE}"
  chmod 0600 "${CONFIG_DIR}/INITIAL_ADMIN_PASSWORD" 2>/dev/null || true

  "${INSTALL_DIR}/bin/${APP_ID}-server" --config "${CONFIG_FILE}" --check

  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=${APP_NAME} mining relay
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${CONFIG_DIR}
ExecStart=${INSTALL_DIR}/bin/${APP_ID}-server --config ${CONFIG_FILE}
Restart=always
RestartSec=3s
TimeoutStopSec=20s
LimitNOFILE=65535
UMask=0027
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=${SYSTEMD_PROTECT_SYSTEM}
${SYSTEMD_WRITE_DIRECTIVE}=${CONFIG_DIR}

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}.service"
  sleep 2
  systemctl is-active --quiet "${SERVICE_NAME}.service" || {
    systemctl status "${SERVICE_NAME}.service" --no-pager --full || true
    journalctl -u "${SERVICE_NAME}.service" -n 100 --no-pager || true
    fail "${APP_NAME} 服务启动失败"
  }
  curl --fail --silent --show-error "http://127.0.0.1:${web_port}/healthz" >/dev/null \
    || fail "Web 健康检查失败"

  echo ""
  echo "${APP_NAME} ${VERSION} 安装完成并已设置开机自启动。"
  echo "检测到系统：${OS_PRETTY_NAME}"
  echo "Web 地址：http://${detected_ip}:${web_port}/"
  echo "Web 端口：${web_port}"
  echo "默认账户：admin"
  if [[ -r "${CONFIG_DIR}/INITIAL_ADMIN_PASSWORD" ]]; then
    echo "初始密码：$(cat "${CONFIG_DIR}/INITIAL_ADMIN_PASSWORD")"
  fi
  echo "配置文件：${CONFIG_FILE}"
  echo "已安装版本：${VERSION}"
  echo "查看日志：journalctl -u ${SERVICE_NAME} -f"
  echo "脚本不会自动修改 UFW 或云安全组，请按需开放 Web 和矿池中转端口。"
}

installed_version() {
  local value=""
  if [[ -r "${INSTALLED_VERSION_FILE}" ]]; then
    value="$(tr -d '[:space:]' < "${INSTALLED_VERSION_FILE}")"
  fi
  if [[ "${value}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${value}"
  else
    echo "未记录"
  fi
}

latest_published_version() {
  local response latest
  response="$(curl --fail --silent --show-error --location \
    --proto '=https' --tlsv1.2 \
    --header 'Accept: application/vnd.github+json' \
    --header 'User-Agent: ToMinerSystem-Installer' \
    "${RELEASE_API_URL}")" \
    || fail "无法读取 GitHub 版本列表"
  latest="$(printf '%s\n' "${response}" \
    | sed -nE 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' \
    | sort -V \
    | tail -n 1)"
  [[ "${latest}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "GitHub 中没有可安装的正式版本目录"
  echo "${latest}"
}

install_version() {
  local requested_version="$1" installer_url
  detect_supported_linux install-version
  [[ "${requested_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "版本号格式无效，应为 x.y.z，例如 1.0.0"

  if [[ "${requested_version}" == "${VERSION}" ]]; then
    install_server
    return 0
  fi

  installer_url="${RELEASE_RAW_ROOT}/${requested_version}/install.sh"
  temporary_installer="$(mktemp)"
  curl --fail --location --proto '=https' --tlsv1.2 \
    "${installer_url}" --output "${temporary_installer}" \
    || fail "版本 ${requested_version} 不存在或安装脚本无法下载"
  grep -Fxq "VERSION=\"${requested_version}\"" "${temporary_installer}" \
    || fail "下载的安装脚本版本与请求版本不一致"
  echo "正在安装 ToMinerSystem ${requested_version}……"
  bash "${temporary_installer}" install
  rm -f -- "${temporary_installer}"
  temporary_installer=""
}

update_server() {
  local current_version latest_version
  detect_supported_linux update
  current_version="$(installed_version)"
  latest_version="$(latest_published_version)"
  echo "当前安装版本：${current_version}"
  echo "GitHub 最新版本：${latest_version}"
  if [[ "${current_version}" == "${latest_version}" ]]; then
    echo "当前已经是最新版本。"
    return 0
  fi
  install_version "${latest_version}"
}

prompt_install_version() {
  local requested_version="${1:-}"
  if [[ -z "${requested_version}" ]]; then
    read -r -p "请输入要安装的版本号（例如 1.0.0）：" requested_version
  fi
  install_version "${requested_version}"
}

reset_password() {
  detect_supported_linux reset-password
  local password
  password="$(openssl rand -hex 16)"
  systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true
  printf 'username = "admin"\nbootstrap_password = "%s"\n' "${password}" \
    > "${CONFIG_DIR}/admin.toml"
  printf '%s\n' "${password}" > "${CONFIG_DIR}/INITIAL_ADMIN_PASSWORD"
  chown "${SERVICE_USER}:${SERVICE_USER}" \
    "${CONFIG_DIR}/admin.toml" "${CONFIG_DIR}/INITIAL_ADMIN_PASSWORD"
  chmod 0600 "${CONFIG_DIR}/admin.toml"
  chmod 0600 "${CONFIG_DIR}/INITIAL_ADMIN_PASSWORD"
  systemctl start "${SERVICE_NAME}.service"
  echo "账户：admin"
  echo "新密码：${password}"
}

show_web_port() {
  detect_supported_linux web-port
  [[ -r "${WEB_PORT_FILE}" ]] || fail "尚未安装或 Web 端口文件不存在：${WEB_PORT_FILE}"
  echo "Web 端口：$(tr -dc '0-9' < "${WEB_PORT_FILE}")"
}

change_web_port() {
  local current_port new_port current_listen listen_host temporary_config detected_ip
  detect_supported_linux change-web-port
  [[ -r "${CONFIG_FILE}" ]] || fail "尚未安装或配置文件不存在：${CONFIG_FILE}"

  current_port=""
  if [[ -r "${WEB_PORT_FILE}" ]]; then
    current_port="$(tr -dc '0-9' < "${WEB_PORT_FILE}")"
  fi
  echo "当前 Web 端口：${current_port:-未知}"
  read -r -p "请输入新端口（${WEB_PORT_MIN}-${WEB_PORT_MAX}，直接回车随机生成）：" new_port
  if [[ -z "${new_port}" ]]; then
    new_port="$(random_available_port "${WEB_PORT_MIN}" "${WEB_PORT_MAX}")" \
      || fail "无法找到空闲 Web 端口"
  fi
  [[ "${new_port}" =~ ^[0-9]+$ ]] || fail "端口必须是数字"
  if (( 10#${new_port} < WEB_PORT_MIN || 10#${new_port} > WEB_PORT_MAX )); then
    fail "Web 端口必须位于 ${WEB_PORT_MIN}-${WEB_PORT_MAX}"
  fi
  if [[ "${new_port}" != "${current_port}" ]] && port_is_listening "${new_port}"; then
    fail "端口 ${new_port} 已被其他程序占用"
  fi

  current_listen="$(awk -F'"' '/^[[:space:]]*metrics_listen[[:space:]]*=/ { print $2; exit }' "${CONFIG_FILE}")"
  [[ -n "${current_listen}" ]] || fail "配置文件中缺少 server.metrics_listen"
  listen_host="${current_listen%:*}"
  [[ -n "${listen_host}" ]] || listen_host="0.0.0.0"
  temporary_config="$(mktemp "${CONFIG_DIR}/config.toml.XXXXXX")"
  if ! awk -v replacement="metrics_listen = \"${listen_host}:${new_port}\"" '
    BEGIN { updated=0 }
    !updated && /^[[:space:]]*metrics_listen[[:space:]]*=/ {
      print replacement
      updated=1
      next
    }
    { print }
    END { if (!updated) exit 42 }
  ' "${CONFIG_FILE}" > "${temporary_config}"; then
    rm -f -- "${temporary_config}"
    fail "更新 Web 端口失败"
  fi

  install -o "${SERVICE_USER}" -g "${SERVICE_USER}" -m 0640 \
    "${temporary_config}" "${CONFIG_FILE}"
  rm -f -- "${temporary_config}"
  printf '%s\n' "${new_port}" > "${WEB_PORT_FILE}"
  chown "${SERVICE_USER}:${SERVICE_USER}" "${WEB_PORT_FILE}"
  chmod 0640 "${WEB_PORT_FILE}"

  systemctl restart "${SERVICE_NAME}.service"
  sleep 2
  systemctl is-active --quiet "${SERVICE_NAME}.service" || {
    systemctl status "${SERVICE_NAME}.service" --no-pager --full || true
    fail "服务重启失败，请检查配置和日志"
  }
  curl --fail --silent --show-error "http://127.0.0.1:${new_port}/healthz" >/dev/null \
    || fail "新 Web 端口健康检查失败"
  detected_ip="$(server_ip)"
  echo "Web 端口已修改为：${new_port}"
  echo "Web 地址：http://${detected_ip}:${new_port}/"
}

uninstall_server() {
  detect_supported_linux uninstall
  systemctl disable --now "${SERVICE_NAME}.service" 2>/dev/null || true
  rm -f -- "/etc/systemd/system/${SERVICE_NAME}.service"
  systemctl daemon-reload
  rm -f -- "${INSTALL_DIR}/bin/${APP_ID}-server"
  rmdir -- "${INSTALL_DIR}/bin" "${INSTALL_DIR}" 2>/dev/null || true
  echo "程序已卸载；配置保留在 ${CONFIG_DIR}。如需清除，请人工确认后删除该目录。"
}

run_service_action() {
  local action="$1"
  detect_supported_linux "${action}"
  systemctl "${action}" "${SERVICE_NAME}.service"
  systemctl status "${SERVICE_NAME}.service" --no-pager --full || true
}

show_menu() {
  local choice current_version
  while true; do
    current_version="$(installed_version)"
    echo ""
    echo "========================================"
    echo " ${APP_NAME} ${VERSION} Linux 管理工具"
    echo " 当前安装版本：${current_version}"
    echo "========================================"
    echo "  1. 安装软件"
    echo "  2. 更新"
    echo "  3. 启动软件"
    echo "  4. 停止软件"
    echo "  5. 重启软件"
    echo "  6. 查看 Web 端口"
    echo "  7. 修改 Web 端口"
    echo "  8. 卸载软件"
    echo "  9. 安装指定版本"
    echo " 10. 重置账号密码"
    echo "  0. 退出"
    echo "========================================"
    read -r -p "请选择 [0-10]：" choice || return 0
    case "${choice}" in
      1) install_server ;;
      2) update_server ;;
      3) run_service_action start ;;
      4) run_service_action stop ;;
      5) run_service_action restart ;;
      6) show_web_port ;;
      7) change_web_port ;;
      8) uninstall_server ;;
      9) prompt_install_version ;;
      10) reset_password ;;
      0) echo "已退出。"; return 0 ;;
      *) echo "无效选项，请输入 0-10。" ;;
    esac
    echo ""
    read -r -p "按 Enter 键返回主菜单……" _ || return 0
  done
}

if [[ "$#" -eq 0 ]]; then
  show_menu
  exit 0
fi

command_name="$1"
case "${command_name}" in
  install) install_server ;;
  update) update_server ;;
  install-version) prompt_install_version "${2:-}" ;;
  start|stop|restart)
    run_service_action "${command_name}"
    ;;
  status)
    detect_supported_linux status
    systemctl status "${SERVICE_NAME}.service" --no-pager --full
    ;;
  web-port) show_web_port ;;
  change-web-port) change_web_port ;;
  reset-password) reset_password ;;
  uninstall) uninstall_server ;;
  *)
    echo "用法：sudo bash install.sh [install|update|install-version x.y.z|start|stop|restart|status|web-port|change-web-port|reset-password|uninstall]" >&2
    echo "不带参数运行时显示交互式选择菜单。" >&2
    exit 2
    ;;
esac
