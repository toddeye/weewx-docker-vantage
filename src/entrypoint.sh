#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

WEEWX_ROOT="/data"
CONF_FILE="${WEEWX_ROOT}/weewx.conf"

# Start socat in the background
SOCAT_TARGET="${SOCAT_TARGET:-host.docker.internal:7000}"
echo "Starting socat using target: $SOCAT_TARGET"
# /usr/bin/socat PTY,link=/tmp/ttyV0,raw,echo=0,mode=666 TCP:weewx.local:7000,forever,interval=5
socat -d -d pty,raw,echo=0,link=/tmp/ttyV0,perm=666,b19200 tcp:$SOCAT_TARGET,forever,interval=5,retry=30 &
SOCAT_PID=$!

# Wait for /tmp/ttyV0 to appear
echo "Waiting for /tmp/ttyV0..."
for i in {1..20}; do
    if [ -e /tmp/ttyV0 ]; then
        echo "/tmp/ttyV0 is ready."
        break
    fi
    sleep 2
done

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

# if we have any parameters we'll send them to weectl

if [ $# -gt 0 ]; then
  weectl "$@" --config ${CONF_FILE}
  exit 0
else
  weewxd --config ${CONF_FILE}
fi
