"""FCM HTTP v1 sender for a trusted Salesforce outbox worker.

This is a sender utility, not a deployed server or Salesforce event subscription.
Use workload credentials to obtain a short-lived access token. Never ship it in
Flutter. Persist the inbox event before calling send, retry transient failures,
and remove device registrations on FCM UNREGISTERED responses.
"""
import argparse
import hashlib
import json
import os
import urllib.request


def build_message(event, device_token, sound=True, platform="android"):
    for key in ("id", "title", "body", "time", "source"):
        if not isinstance(event.get(key), str) or not event[key].strip():
            raise ValueError(f"Missing event field: {key}")
    data = {key: str(value) for key, value in event.items()
            if key in ("id", "title", "body", "time", "source", "recordId")
            and value is not None}
    aps = {"alert": {"title": event["title"], "body": event["body"]}}
    if sound:
        aps["sound"] = "default"
    message = {
        "token": device_token,
        "notification": {"title": event["title"], "body": event["body"]},
        "data": data,
        "android": {
            "priority": "high",
            "notification": {
                "channel_id": "arelia_updates_v1" if sound else "arelia_updates_silent_v1",
                "icon": "ic_stat_notification",
                "tag": event["id"],
                "visibility": "PUBLIC",
                "notification_priority": "PRIORITY_HIGH",
                "default_sound": sound,
            },
        },
        "apns": {
            "headers": {
                "apns-push-type": "alert", "apns-priority": "10",
                "apns-collapse-id": hashlib.sha256(event["id"].encode()).hexdigest(),
            },
            "payload": {"aps": aps},
        },
    }
    # FCM limits include duplicated title/body in data and notification payloads.
    payload = json.dumps({"message": message}, ensure_ascii=False).encode()
    if len(payload) > 4000:
        raise ValueError("Notification exceeds the push payload budget; shorten its summary")
    return {"message": message}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("event_file")
    parser.add_argument("device_file", help='JSON with token, platform and sound')
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    with open(args.event_file) as source:
        event = json.load(source)
    with open(args.device_file) as source:
        device = json.load(source)
    payload = build_message(event, device["token"], device.get("sound", True), device.get("platform", "android"))
    if args.dry_run:
        payload["message"]["token"] = "<redacted>"
        print(json.dumps(payload, indent=2))
        return
    project = os.environ["FIREBASE_PROJECT_ID"]
    access_token = os.environ["FCM_ACCESS_TOKEN"]
    request = urllib.request.Request(
        f"https://fcm.googleapis.com/v1/projects/{project}/messages:send",
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        print(json.load(response)["name"])


if __name__ == "__main__":
    main()
