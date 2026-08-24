#!/usr/bin/env python3
"""Wait for an exact App Store build and make it available to a beta group."""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

BASE = "https://api.appstoreconnect.apple.com/v1"


def require_environment() -> None:
    required = ("ASC_KEY_PATH", "ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_APP_ID", "ASC_BETA_GROUP_ID", "BUILD_NUMBER")
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit("missing required environment variables: " + ", ".join(missing))


def token() -> str:
    key = open(os.environ["ASC_KEY_PATH"], "rb").read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"]},
    )


def request(path: str, method: str = "GET", body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=30) as response:
        payload = response.read()
        return json.loads(payload) if payload else {}


def idempotent_conflict(payload: str) -> bool:
    value = payload.lower()
    return "already" in value and any(word in value for word in ("exist", "associat", "include"))


def attach(build_id: str, group_id: str) -> str:
    try:
        group = request(f"/betaGroups/{group_id}").get("data", {})
        if group.get("attributes", {}).get("hasAccessToAllBuilds") is True:
            return "automatic"
    except urllib.error.HTTPError as error:
        if error.code not in (403, 404):
            raise

    attempts = int(os.environ.get("ASC_GROUP_ATTEMPTS", "18"))
    interval = float(os.environ.get("ASC_GROUP_INTERVAL", "10"))
    last = ""
    for attempt in range(1, attempts + 1):
        endpoints = (
            f"/betaGroups/{group_id}/relationships/builds",
            f"/builds/{build_id}/relationships/betaGroups",
        )
        for path in endpoints:
            try:
                request(path, "POST", {"data": [{"type": "builds" if path.startswith("/betaGroups") else "betaGroups", "id": build_id if path.startswith("/betaGroups") else group_id}]})
                return "assigned"
            except urllib.error.HTTPError as error:
                payload = error.read().decode(errors="replace")
                last = f"HTTP {error.code}: {payload[:300]}"
                if error.code == 409 and idempotent_conflict(payload):
                    return "already-assigned"
                if error.code not in (404, 409):
                    raise RuntimeError(f"beta group assignment failed: {last}") from error
        if attempt < attempts:
            print(f"Beta relationship not ready (attempt {attempt}/{attempts})", flush=True)
            time.sleep(interval)
    raise SystemExit(f"beta group relationship did not become available: {last}")


def main() -> None:
    require_environment()
    app_id = os.environ["ASC_APP_ID"]
    build_number = os.environ["BUILD_NUMBER"]
    group_id = os.environ["ASC_BETA_GROUP_ID"]
    query = urllib.parse.urlencode({"filter[app]": app_id, "filter[version]": build_number, "limit": "1"})
    attempts = int(os.environ.get("ASC_PROCESSING_ATTEMPTS", "135"))
    interval = float(os.environ.get("ASC_PROCESSING_INTERVAL", "20"))
    build = None
    for attempt in range(1, attempts + 1):
        rows = request(f"/builds?{query}").get("data", [])
        if rows:
            build = rows[0]
            state = build["attributes"]["processingState"]
            print(f"Build {build_number}: {state} (attempt {attempt})", flush=True)
            if state == "VALID":
                break
            if state in {"FAILED", "INVALID"}:
                raise SystemExit(f"Apple rejected build {build_number}: {state}")
        else:
            print(f"Build {build_number}: not visible yet (attempt {attempt})", flush=True)
        time.sleep(interval)
    else:
        raise SystemExit(f"Build {build_number} did not finish processing in time")

    assert build is not None
    relationship = attach(build["id"], group_id)
    evidence = f"TestFlight verified: build_id={build['id']} version={build_number} state=VALID group={group_id} relationship={relationship}"
    print(evidence)
    if path := os.environ.get("EVIDENCE_PATH"):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(evidence + "\n")


if __name__ == "__main__":
    main()
