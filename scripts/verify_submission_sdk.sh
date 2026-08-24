#!/usr/bin/env bash
set -euo pipefail

required_major="${1:-}"
[[ "$required_major" =~ ^[0-9]+$ ]] || { echo "usage: $0 REQUIRED_SDK_MAJOR" >&2; exit 2; }
command -v xcodebuild >/dev/null || { echo "xcodebuild is required" >&2; exit 2; }
command -v xcrun >/dev/null || { echo "xcrun is required" >&2; exit 2; }

xcodebuild -version
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
sdk_major="${sdk_version%%.*}"
echo "iphoneos_sdk=$sdk_version required_major=$required_major"
[[ "$sdk_major" =~ ^[0-9]+$ ]] || { echo "could not parse iPhoneOS SDK version: $sdk_version" >&2; exit 1; }
if (( sdk_major < required_major )); then
  echo "iPhoneOS SDK $sdk_version is below Apple's current submission minimum major $required_major" >&2
  exit 1
fi
