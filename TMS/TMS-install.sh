#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.0.0"

# Customer customization: change this block for white-label builds.
APP_NAME="ToMinerSystem TMS"
APP_ID="tominersystem"
DOWNLOAD_HOST="https://github.com/ToMinerSystem/ToMinerSystem/raw/main/TMS/linux"
SERVICE_NAME="ToMinerSystem-TMS"

# 发布目录格式：
# TMS/linux/TMS-<版本>-linux-<架构>
# 支持的 CPU 架构：x86_64、aarch64（ARM64）。
# Linux 二进制采用 glibc 2.17 兼容基线，系统识别用于自动选择依赖安装方式。

readonly VERSION APP_NAME APP_ID DOWNLOAD_HOST SERVICE_NAME
readonly SERVICE_USER="${APP_ID}"
readonly INSTALL_DIR="${TMS_LOCAL_INSTALL_DIR:-/opt/ToMinerSystem-TMS}"
readonly CONFIG_DIR="${TMS_LOCAL_CONFIG_DIR:-/etc/ToMinerSystem-TMS}"
readonly CONFIG_FILE="${CONFIG_DIR}/local-relay.toml"
readonly WEB_PORT_FILE="${CONFIG_DIR}/web-port"
readonly INSTALLED_VERSION_FILE="${CONFIG_DIR}/installed-version"
readonly INSTALLED_ARCH_FILE="${CONFIG_DIR}/installed-architecture"
readonly INSTALLED_BINARY_NAME="TMS"
readonly LEGACY_SERVICE_NAME="tominersystem-tms"
readonly LEGACY_CONFIG_DIR="/etc/tominersystem-tms"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly DOWNLOAD_BASE_URL="${TMS_DOWNLOAD_BASE_URL:-${DOWNLOAD_HOST}}"
readonly RELEASE_API_URL="https://api.github.com/repos/ToMinerSystem/ToMinerSystem/contents/TMS/linux?ref=main"
readonly WEB_PORT_MIN=52347
readonly WEB_PORT_MAX=61892

OS_ID=""
OS_PRETTY_NAME=""
PACKAGE_FAMILY=""
CPU_ARCH=""
EXPECTED_ELF_MACHINE=""
NOLOGIN_SHELL="/sbin/nologin"
SYSTEMD_PROTECT_SYSTEM="strict"
SYSTEMD_WRITE_DIRECTIVE="ReadWritePaths"

temporary_binary=""
source_binary=""
selected_binary_name=""

cleanup() {
  [[ -z "${temporary_binary}" || ! -f "${temporary_binary}" ]] \
    || rm -f -- "${temporary_binary}"
}
trap cleanup EXIT

fail() {
  echo "错误：$*" >&2
  exit 1
}

version_is_valid() {
  [[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

detect_cpu_architecture() {
  case "$(uname -m)" in
    x86_64|amd64)
      CPU_ARCH="x86_64"
      EXPECTED_ELF_MACHINE="62"
      ;;
    aarch64|arm64)
      CPU_ARCH="aarch64"
      EXPECTED_ELF_MACHINE="183"
      ;;
    *)
      fail "不支持的 CPU 架构：$(uname -m)。当前发布包支持 x86_64 和 aarch64（ARM64）"
      ;;
  esac
}

detect_supported_linux() {
  local systemd_version
  [[ "${EUID}" -eq 0 ]] \
    || fail "请使用 root 权限运行：sudo bash TMS-install.sh ${1:-install}"
  [[ -r /etc/os-release ]] || fail "无法识别 Linux 系统：缺少 /etc/os-release"

  OS_ID="$(awk -F= '$1 == "ID" { value=$2; gsub(/^"|"$/, "", value); print tolower(value); exit }' /etc/os-release)"
  OS_PRETTY_NAME="$(awk -F= '$1 == "PRETTY_NAME" { value=substr($0, index($0, "=") + 1); gsub(/^"|"$/, "", value); print value; exit }' /etc/os-release)"
  case "${OS_ID}" in
    ubuntu|debian)
      PACKAGE_FAMILY="debian"
      ;;
    centos|rhel|rocky|almalinux|ol|fedora)
      PACKAGE_FAMILY="rpm"
      ;;
    *)
      fail "不支持的 Linux 系统：${OS_PRETTY_NAME:-${OS_ID:-unknown}}。当前支持 Ubuntu、Debian、CentOS、RHEL、Rocky Linux、AlmaLinux、Oracle Linux 和 Fedora"
      ;;
  esac

  detect_cpu_architecture
  command -v systemctl >/dev/null 2>&1 || fail "当前 Linux 系统没有 systemd"
  if command -v nologin >/dev/null 2>&1; then
    NOLOGIN_SHELL="$(command -v nologin)"
  fi
  systemd_version="$(systemctl --version | awk 'NR == 1 { print $2; exit }')"
  if [[ "${systemd_version}" =~ ^[0-9]+$ ]] && (( systemd_version < 231 )); then
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
    rpm)
      if command -v dnf >/dev/null 2>&1; then
        dnf install -y ca-certificates curl iproute openssl shadow-utils
      elif command -v yum >/dev/null 2>&1; then
        yum install -y ca-certificates curl iproute openssl shadow-utils
      else
        fail "RPM 系统中未找到 dnf 或 yum"
      fi
      update-ca-trust 2>/dev/null || true
      ;;
    *)
      fail "未初始化 Linux 包管理器"
      ;;
  esac
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

binary_name_for() {
  local release_version="$1"
  echo "TMS-${release_version}-linux-${CPU_ARCH}"
}

expected_sha256_for() {
  local release_version="$1"
  case "${release_version}:${CPU_ARCH}" in
    1.0.0:x86_64)
      echo "ed04a5b24174c109a47a7ce4d62b6113187baedbdb704326f8f569ffed1d1a3f"
      ;;
    1.0.0:aarch64)
      echo "40311bfa2275990d8aebdfe0a8f1e60b50722280002b5507712a582a3b657c3e"
      ;;
    *)
      return 1
      ;;
  esac
}

obtain_release() {
  local release_version="$1" local_release_dir release_url
  selected_binary_name="$(binary_name_for "${release_version}")"
  local_release_dir="${SCRIPT_DIR}/linux/${release_version}"
  if [[ -f "${local_release_dir}/${selected_binary_name}" ]]; then
    source_binary="${local_release_dir}/${selected_binary_name}"
    return 0
  fi
  if [[ -f "${SCRIPT_DIR}/linux/${selected_binary_name}" ]]; then
    source_binary="${SCRIPT_DIR}/linux/${selected_binary_name}"
    return 0
  fi

  release_url="${DOWNLOAD_BASE_URL%/}"
  temporary_binary="$(mktemp)"
  curl --fail --location --proto '=https' --tlsv1.2 \
    "${release_url}/${selected_binary_name}" --output "${temporary_binary}" \
    || fail "没有适用于 ${CPU_ARCH} 的 TMS ${release_version} Linux 程序"
  source_binary="${temporary_binary}"
}

verify_release() {
  local binary="$1" release_version="$2" magic expected_sha256 actual_sha256 elf_machine
  magic="$(od -An -N4 -tx1 "${binary}" | tr -d ' \n')"
  [[ "${magic}" == "7f454c46" ]] || fail "${selected_binary_name} 不是 Linux ELF 程序"
  elf_machine="$(od -An -j18 -N2 -tu2 "${binary}" | tr -d ' ')"
  [[ "${elf_machine}" == "${EXPECTED_ELF_MACHINE}" ]] \
    || fail "下载程序的 CPU 架构与当前 ${CPU_ARCH} 系统不一致"

  expected_sha256="$(expected_sha256_for "${release_version}")" \
    || fail "安装脚本中没有 TMS ${release_version} ${CPU_ARCH} 的 SHA-256 校验值"
  actual_sha256="$(sha256sum "${binary}" | awk '{print tolower($1)}')"
  [[ "${actual_sha256}" == "${expected_sha256}" ]] \
    || fail "${selected_binary_name} SHA-256 校验失败"
}

installed_version() {
  local value=""
  if [[ -r "${INSTALLED_VERSION_FILE}" ]]; then
    value="$(tr -d '[:space:]' < "${INSTALLED_VERSION_FILE}")"
  fi
  if version_is_valid "${value}"; then
    echo "${value}"
  else
    echo "未安装"
  fi
}

installed_architecture() {
  if [[ -r "${INSTALLED_ARCH_FILE}" ]]; then
    tr -d '[:space:]' < "${INSTALLED_ARCH_FILE}"
  else
    echo "未记录"
  fi
}

latest_published_version() {
  local response latest
  response="$(curl --fail --silent --show-error --location \
    --proto '=https' --tlsv1.2 \
    --header 'Accept: application/vnd.github+json' \
    --header 'User-Agent: ToMinerSystem-TMS-Installer' \
    "${RELEASE_API_URL}")" \
    || fail "无法读取 GitHub TMS 版本列表"
  latest="$(printf '%s\n' "${response}" \
    | tr '{' '\n' \
    | sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"TMS-([0-9]+\.[0-9]+\.[0-9]+)-linux-(x86_64|aarch64)".*/\1/p' \
    | sort -V \
    | tail -n 1)"
  version_is_valid "${latest}" \
    || fail "GitHub TMS/linux 目录中没有正式版本"
  echo "${latest}"
}

install_tms() {
  local requested_version="${1:-${VERSION}}" dependencies_ready="${2:-false}" web_port detected_ip
  version_is_valid "${requested_version}" \
    || fail "版本号格式无效，应为 x.y.z，例如 ${VERSION}"
  detect_supported_linux install
  if [[ "${dependencies_ready}" != "true" ]]; then
    install_dependencies
  fi
  obtain_release "${requested_version}"
  verify_release "${source_binary}" "${requested_version}"

  if ! getent group "${SERVICE_USER}" >/dev/null 2>&1; then
    groupadd --system "${SERVICE_USER}"
  fi
  if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
    useradd --system --gid "${SERVICE_USER}" --home-dir "${CONFIG_DIR}" \
      --no-create-home --shell "${NOLOGIN_SHELL}" "${SERVICE_USER}"
  fi
  if systemctl list-unit-files "${LEGACY_SERVICE_NAME}.service" --no-legend 2>/dev/null | grep -q .; then
    systemctl disable --now "${LEGACY_SERVICE_NAME}.service" 2>/dev/null || true
  fi

  install -d -o root -g root -m 0755 "${INSTALL_DIR}" "${INSTALL_DIR}/bin"
  install -d -o "${SERVICE_USER}" -g "${SERVICE_USER}" -m 0750 "${CONFIG_DIR}"
  if [[ ! -e "${CONFIG_FILE}" && -r "${LEGACY_CONFIG_DIR}/local-relay.toml" ]]; then
    install -o "${SERVICE_USER}" -g "${SERVICE_USER}" -m 0640 \
      "${LEGACY_CONFIG_DIR}/local-relay.toml" "${CONFIG_FILE}"
  fi
  if [[ ! -e "${WEB_PORT_FILE}" && -r "${LEGACY_CONFIG_DIR}/web-port" ]]; then
    install -o "${SERVICE_USER}" -g "${SERVICE_USER}" -m 0640 \
      "${LEGACY_CONFIG_DIR}/web-port" "${WEB_PORT_FILE}"
  fi
  install -o root -g root -m 0755 "${source_binary}" \
    "${INSTALL_DIR}/bin/${INSTALLED_BINARY_NAME}.new"
  mv -f -- "${INSTALL_DIR}/bin/${INSTALLED_BINARY_NAME}.new" \
    "${INSTALL_DIR}/bin/${INSTALLED_BINARY_NAME}"

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

  "${INSTALL_DIR}/bin/${INSTALLED_BINARY_NAME}" \
    --config "${CONFIG_FILE}" --check

  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=${APP_NAME} local encrypted relay
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${CONFIG_DIR}
ExecStart=${INSTALL_DIR}/bin/${INSTALLED_BINARY_NAME} --headless --web-listen 0.0.0.0:${web_port} --config ${CONFIG_FILE}
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
  systemctl enable "${SERVICE_NAME}.service"
  if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    systemctl restart "${SERVICE_NAME}.service"
  else
    systemctl start "${SERVICE_NAME}.service"
  fi
  sleep 2
  systemctl is-active --quiet "${SERVICE_NAME}.service" || {
    systemctl status "${SERVICE_NAME}.service" --no-pager --full || true
    journalctl -u "${SERVICE_NAME}.service" -n 100 --no-pager || true
    fail "TMS 服务启动失败"
  }
  curl --fail --silent --show-error \
    "http://127.0.0.1:${web_port}/api/status" >/dev/null \
    || fail "TMS Web 健康检查失败"

  printf '%s\n' "${requested_version}" > "${INSTALLED_VERSION_FILE}"
  printf '%s\n' "${CPU_ARCH}" > "${INSTALLED_ARCH_FILE}"
  chmod 0644 "${INSTALLED_VERSION_FILE}" "${INSTALLED_ARCH_FILE}"

  detected_ip="$(local_ip)"
  echo ""
  echo "TMS ${requested_version} 安装完成并已设置开机自启动。"
  echo "检测到系统：${OS_PRETTY_NAME}"
  echo "检测到架构：${CPU_ARCH}"
  echo "Web 端口：${web_port}"
  echo "程序启动成功, 访问此地址: ${detected_ip}:${web_port}"
  echo "打开 Web 后输入 ToMinerSystem 管理端生成的 TMS 配对码；识别码会自动保存并连接。"
  echo "配置文件：${CONFIG_FILE}"
  echo "查看日志：journalctl -u ${SERVICE_NAME} -f"
}

update_tms() {
  local current_version current_arch latest_version
  detect_supported_linux update
  install_dependencies
  current_version="$(installed_version)"
  current_arch="$(installed_architecture)"
  latest_version="$(latest_published_version)"
  echo "当前安装版本：${current_version}"
  echo "当前安装架构：${current_arch}"
  echo "GitHub 最新版本：${latest_version}"
  if [[ "${current_version}" == "${latest_version}" \
    && "${current_arch}" == "${CPU_ARCH}" ]]; then
    echo "当前已经是适用于 ${CPU_ARCH} 的最新版本。"
    return 0
  fi
  install_tms "${latest_version}" true
}

install_current_version() {
  install_tms "${VERSION}"
}

run_service_action() {
  local action="$1"
  detect_supported_linux "${action}"
  systemctl "${action}" "${SERVICE_NAME}.service"
  systemctl status "${SERVICE_NAME}.service" --no-pager --full || true
}

uninstall_tms() {
  detect_supported_linux uninstall
  systemctl disable --now "${SERVICE_NAME}.service" 2>/dev/null || true
  systemctl disable --now "${LEGACY_SERVICE_NAME}.service" 2>/dev/null || true
  rm -f -- "/etc/systemd/system/${SERVICE_NAME}.service"
  rm -f -- "/etc/systemd/system/${LEGACY_SERVICE_NAME}.service"
  systemctl daemon-reload
  rm -f -- "${INSTALL_DIR}/bin/${INSTALLED_BINARY_NAME}"
  rmdir -- "${INSTALL_DIR}/bin" "${INSTALL_DIR}" 2>/dev/null || true
  rm -f -- "${INSTALLED_VERSION_FILE}" "${INSTALLED_ARCH_FILE}"
  echo "TMS 程序已卸载；识别码、线路配置和 Web 端口保留在 ${CONFIG_DIR}。"
}

show_menu() {
  local choice current_version current_arch
  current_version="$(installed_version)"
  current_arch="$(installed_architecture)"
  echo ""
  echo "========================================"
  echo " ${APP_NAME} ${VERSION} Linux 管理工具"
  echo " 当前安装版本：${current_version}"
  echo " 当前安装架构：${current_arch}"
  echo " 当前系统架构：$(uname -m)"
  echo "========================================"
  echo "  1. 安装 TMS"
  echo "  2. 更新 TMS"
  echo "  3. 停止运行 TMS"
  echo "  4. 启动 TMS"
  echo "  5. 重启 TMS"
  echo "  6. 卸载 TMS"
  echo "========================================"
  read -r -p "请选择 [1-6]：" choice || return 0
  case "${choice}" in
    1) install_current_version ;;
    2) update_tms ;;
    3) run_service_action stop ;;
    4) run_service_action start ;;
    5) run_service_action restart ;;
    6) uninstall_tms ;;
    *) fail "无效选项，请输入 1-6" ;;
  esac
}

if [[ "$#" -eq 0 ]]; then
  show_menu
  exit 0
fi

command_name="$1"
case "${command_name}" in
  install)
    install_tms "${2:-${VERSION}}"
    ;;
  install-version)
    [[ -n "${2:-}" ]] || fail "install-version 需要版本号，例如 ${VERSION}"
    install_tms "$2"
    ;;
  update)
    update_tms
    ;;
  start|stop|restart)
    run_service_action "${command_name}"
    ;;
  status)
    detect_supported_linux status
    systemctl status "${SERVICE_NAME}.service" --no-pager --full || true
    ;;
  web-port)
    detect_supported_linux web-port
    [[ -r "${WEB_PORT_FILE}" ]] || fail "尚未安装或 Web 端口文件不存在"
    cat "${WEB_PORT_FILE}"
    ;;
  uninstall)
    uninstall_tms
    ;;
  *)
    echo "用法：sudo bash TMS-install.sh [install [x.y.z]|install-version x.y.z|update|start|stop|restart|status|web-port|uninstall]" >&2
    echo "不带参数运行时显示交互式选择菜单。" >&2
    exit 2
    ;;
esac
