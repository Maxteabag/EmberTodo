#!/usr/bin/env python3
"""Inspect an IPA and enforce primary and embedded-target release metadata."""
from __future__ import annotations

import argparse
import datetime as dt
import json
import plistlib
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


def decode_profile(path: Path) -> dict:
    commands = []
    if shutil.which("security"):
        commands.append(["security", "cms", "-D", "-i", str(path)])
    if shutil.which("openssl"):
        commands.append(["openssl", "smime", "-inform", "der", "-verify", "-noverify", "-in", str(path)])
    for command in commands:
        result = subprocess.run(command, capture_output=True)
        if result.returncode == 0:
            return plistlib.loads(result.stdout)
    raise RuntimeError(f"unable to decode provisioning profile: {path}")


def target_metadata(path: Path) -> dict:
    info = plistlib.load(open(path / "Info.plist", "rb"))
    result = {
        "path": str(path),
        "bundle_id": info.get("CFBundleIdentifier"),
        "version": info.get("CFBundleShortVersionString"),
        "build": info.get("CFBundleVersion"),
        "minimum_os": info.get("MinimumOSVersion"),
        "profile": None,
    }
    profile_path = path / "embedded.mobileprovision"
    if profile_path.exists():
        profile = decode_profile(profile_path)
        entitlements = profile.get("Entitlements", {})
        team = (profile.get("TeamIdentifier") or [""])[0]
        app_id = entitlements.get("application-identifier", "")
        result["profile"] = {
            "name": profile.get("Name"),
            "uuid": profile.get("UUID"),
            "team": team,
            "application_identifier": app_id,
            "expiration": profile.get("ExpirationDate").isoformat() if profile.get("ExpirationDate") else None,
            "aps_environment": entitlements.get("aps-environment"),
        }
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa")
    parser.add_argument("--bundle-id")
    parser.add_argument("--version")
    parser.add_argument("--build")
    parser.add_argument("--minimum-os")
    parser.add_argument("--team-id")
    parser.add_argument("--allow-missing-profile", action="store_true")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="verify-ipa-") as directory:
        root = Path(directory)
        with zipfile.ZipFile(args.ipa) as archive:
            archive.extractall(root)
        apps = list((root / "Payload").glob("*.app"))
        if len(apps) != 1:
            raise SystemExit(f"expected one primary app, found {len(apps)}")
        primary_path = apps[0]
        targets = [target_metadata(primary_path)]
        targets.extend(target_metadata(path) for path in sorted(primary_path.rglob("*.appex")))

    actual = targets[0]
    print(json.dumps({"primary": actual, "embedded_targets": targets[1:]}, indent=2, sort_keys=True))

    expected = {"bundle_id": args.bundle_id, "version": args.version, "build": args.build, "minimum_os": args.minimum_os}
    failures = [f"{key}: expected {value!r}, got {actual[key]!r}" for key, value in expected.items() if value is not None and str(actual[key]) != value]
    now = dt.datetime.now(dt.timezone.utc)
    for target in targets:
        profile = target["profile"]
        if profile is None:
            if not args.allow_missing_profile:
                failures.append(f"{target['bundle_id']}: missing embedded provisioning profile")
            continue
        if args.team_id and profile["team"] != args.team_id:
            failures.append(f"{target['bundle_id']}: expected team {args.team_id!r}, got {profile['team']!r}")
        expected_app_id = f"{profile['team']}.{target['bundle_id']}"
        if profile["application_identifier"] != expected_app_id:
            failures.append(f"{target['bundle_id']}: application-identifier mismatch ({profile['application_identifier']!r})")
        if profile["expiration"] and dt.datetime.fromisoformat(profile["expiration"]).astimezone(dt.timezone.utc) <= now:
            failures.append(f"{target['bundle_id']}: provisioning profile expired at {profile['expiration']}")
    if failures:
        print("IPA verification failed:\n- " + "\n- ".join(failures), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
