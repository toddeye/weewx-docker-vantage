#!/bin/bash
set -e

CONF_FILE="$1"

# If no URLs are provided, skip.
if [[ -z "$WEEX_EXT_URLS" ]]; then
    echo "[INFO] No WEEX_EXT_URLS provided. Skipping extension installation."
    exit 0
fi

IFS=',' read -ra URLS <<< "$WEEX_EXT_URLS"

for url in "${URLS[@]}"; do
    url=$(echo "$url" | xargs)  # trim whitespace
    if [[ -z "$url" ]]; then
        continue
    fi

    echo "[INFO] Installing WeeWX extension from: $url"

    filename="/tmp/$(basename $url)"

    # Download
#    if ! curl -fsSL "$url" -o "$filename"; then
#        echo "[ERROR] Failed to download $url"
#        continue
#    fi

    # Install using WeeWX's built-in installer
    if weectl extension install "$url" --config ${CONF_FILE} --verbosity 2 --yes; then
        echo "[INFO] Extension installed: $url"
    else
        echo "[ERROR] Failed installing extension: $url"
    fi

    rm -f "$filename"
done
