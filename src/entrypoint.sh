#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

WEEWX_ROOT="/data"
CONF_FILE="${WEEWX_ROOT}/weewx.conf"
SOCAT_TARGET="${SOCAT_TARGET:-host.docker.internal:7000}"
SOCAT_TTY="${SOCAT_TTY:-/tmp/vtty7000}"
SOCAT_LOG="${SOCAT_LOG:-/tmp/socat-vtty.log}"


# Start socat in the background
echo "Starting socat using target: $SOCAT_TARGET"
socat -d -d PTY,link="${SOCAT_TTY}",raw,echo=0,mode=666 TCP:"${SOCAT_TARGET}",forever,interval=5,retry=30 > "${SOCAT_LOG}" 2>&1 &
SOCAT_PID=$!

# Wait for /tmp/ttyV0 to appear
echo "Waiting for ${SOCAT_TTY}..."
for i in {1..20}; do
    if [ -e "${SOCAT_TTY}" ]; then
        echo "${SOCAT_TTY} is ready."
        break
    fi
    sleep 2
done

if [ ! -e "${SOCAT_TTY}" ]; then
    echo "ERROR: ${SOCAT_TTY} was not created"
    echo "Last socat log lines:"
    tail -50 "${SOCAT_LOG}" || true
    exit 1
fi

ls -l "${SOCAT_TTY}"

# echo version
if [ $# -gt 0 ] && [ "$1" = "--version" ]; then
  python -c "import _version; print(_version.__version__)"
  exit 0
fi

if [ ! -f "${CONF_FILE}" ]; then
  weectl station create --no-prompt ${WEEWX_ROOT}
  echo "A new set of configurations was created."

  # Append the logging configuration to the generated weewx.conf
  cat << EOF >> "${CONF_FILE}"

[Logging]
    [[root]]
      level = INFO
      handlers = console,
EOF

  echo "Console logging configuration has been appended to ${CONF_FILE}."
  echo "Please review and update ${CONF_FILE} as needed, then restart the container."
  exit 0
fi

echo "[INFO] Running dynamic WeeWX extension installer ..."
/home/weewx/install_extensions.sh ${CONF_FILE}

# if we have any parameters we'll send them to weectl

if [ $# -gt 0 ]; then
  weectl "$@" --config ${CONF_FILE}
  exit 0
else
  weewxd --config ${CONF_FILE}
fi
