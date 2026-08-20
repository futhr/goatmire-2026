#!/usr/bin/env bash
set -euo pipefail

for required_command in curl jq unzip; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "required command not found: $required_command" >&2
    exit 1
  fi
done

if command -v google-chrome >/dev/null 2>&1; then
  chrome_command="$(command -v google-chrome)"
elif command -v google-chrome-stable >/dev/null 2>&1; then
  chrome_command="$(command -v google-chrome-stable)"
elif [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
  chrome_command="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
else
  echo "Google Chrome is required for the Wallaby E2E suite" >&2
  exit 1
fi

chrome_version="$("$chrome_command" --version | grep -Eo '[0-9]+(\.[0-9]+){3}' | head -n 1)"
chrome_build="${chrome_version%.*}"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) driver_platform="linux64" ;;
  Darwin-arm64) driver_platform="mac-arm64" ;;
  Darwin-x86_64) driver_platform="mac-x64" ;;
  *)
    echo "unsupported ChromeDriver platform: $(uname -s)-$(uname -m)" >&2
    exit 1
    ;;
esac

driver_url="$({
  curl -fsSL https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json
} | jq -r --arg build "$chrome_build" --arg platform "$driver_platform" '
  [.versions[]
   | select(.version | startswith($build + "."))
   | .downloads.chromedriver[]
   | select(.platform == $platform)
   | .url] | last // empty
')"

if [[ -z "$driver_url" ]]; then
  echo "no ChromeDriver found for Chrome build $chrome_build ($driver_platform)" >&2
  exit 1
fi

driver_install_dir="$PWD/tmp/tools"
mkdir -p "$driver_install_dir"

driver_tmp_dir="$(mktemp -d /tmp/goatmire-chromedriver.XXXXXX)"
trap 'rm -rf "$driver_tmp_dir"' EXIT

curl -fsSL "$driver_url" -o "$driver_tmp_dir/chromedriver.zip"
unzip -q "$driver_tmp_dir/chromedriver.zip" -d "$driver_tmp_dir/unpacked"
driver_source="$(find "$driver_tmp_dir/unpacked" -type f -name chromedriver -print -quit)"

if [[ -z "$driver_source" ]]; then
  echo "download did not contain a chromedriver binary" >&2
  exit 1
fi

install -m 0755 "$driver_source" "$driver_install_dir/chromedriver"

if command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$driver_install_dir/chromedriver" 2>/dev/null || true
fi

driver_absolute_dir="$(cd "$driver_install_dir" && pwd)"
printf '%s/chromedriver\n' "$driver_absolute_dir"
