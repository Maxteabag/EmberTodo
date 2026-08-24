#!/usr/bin/env python3
"""Ensure an existing App Store Connect beta tester belongs to a group and invite them."""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

BASE = "https://api.appstoreconnect.apple.com/v1"


def required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"missing required environment variable: {name}")
    return value


def token() -> str:
    now = int(time.time())
    key = open(required("ASC_KEY_PATH"), "rb").read()
    return jwt.encode(
        {"iss": required("ASC_ISSUER_ID"), "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": required("ASC_KEY_ID")},
    )


def request(path: str, method: str = "GET", body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            payload = response.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as error:
        payload = error.read().decode(errors="replace")
        raise RuntimeError(f"{method} {path} -> HTTP {error.code}: {payload[:500]}") from error


def relationship_ids(path: str) -> set[str]:
    return {row["id"] for row in request(path).get("data", [])}


def main() -> None:
    email = required("TESTER_EMAIL")
    app_id = required("ASC_APP_ID")
    group_id = required("ASC_BETA_GROUP_ID")
    query = urllib.parse.urlencode({"filter[email]": email, "limit": "10"})
    testers = request(f"/betaTesters?{query}").get("data", [])
    if not testers:
        raise SystemExit(
            "No betaTester resource exists for the requested Apple ID. "
            "For an internal group, add the eligible App Store Connect user through Invite Testers first."
        )

    group_testers = relationship_ids(f"/betaGroups/{group_id}/relationships/betaTesters")
    tester = next((row for row in testers if row["id"] in group_testers), None)
    if tester is None:
        tester = next((row for row in testers if row.get("attributes", {}).get("state")), testers[0])
    tester_id = tester["id"]
    attributes = tester.get("attributes", {})
    print(
        "tester_found "
        + json.dumps(
            {
                "id": tester_id,
                "email": attributes.get("email"),
                "inviteType": attributes.get("inviteType"),
                "state": attributes.get("state"),
            },
            sort_keys=True,
        )
    )

    if tester_id not in group_testers:
        body = {"data": [{"type": "betaTesters", "id": tester_id}]}
        request(f"/betaGroups/{group_id}/relationships/betaTesters", "POST", body)
        print("tester_group_assignment=created")
    else:
        print("tester_group_assignment=existing")

    updated = relationship_ids(f"/betaGroups/{group_id}/relationships/betaTesters")
    if tester_id not in updated:
        raise SystemExit("Tester assignment write returned but relationship verification failed")

    invite_body = {
        "data": {
            "type": "betaTesterInvitations",
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "betaTester": {"data": {"type": "betaTesters", "id": tester_id}},
            },
        }
    }
    try:
        invitation = request("/betaTesterInvitations", "POST", invite_body).get("data", {})
        print(f"invitation_request=created invitation_id={invitation.get('id', '')}")
    except RuntimeError as error:
        text = str(error)
        if "HTTP 409" in text and any(word in text.lower() for word in ("already", "accepted", "invite")):
            print("invitation_request=already-active")
        else:
            raise

    final = request(f"/betaTesters/{tester_id}").get("data", {}).get("attributes", {})
    print(
        "tester_delivery_verified "
        + json.dumps(
            {
                "tester_id": tester_id,
                "group_id": group_id,
                "email": final.get("email", email),
                "inviteType": final.get("inviteType"),
                "state": final.get("state"),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
