# Phone popups and remote push deployment

## Implemented in the app

Existing Salesforce polling alerts now also create Android/iOS system notifications with the same title and body. Android uses a high-importance channel, notification permission, status icon and public lock-screen visibility. iOS requests alert/sound permission and presents banners. The app sound switch selects a separate silent Android channel and updates the registered device preference for future server sends. Users' OS channel, lock-screen privacy, Focus/Do Not Disturb and sound settings always take precedence; heads-up display is requested, not forced.

Firebase Messaging handles foreground delivery, background notification taps and cold-start notification taps. Tapping opens the existing inbox after login. Clearing an inbox item removes its corresponding local notification and delivered remote alert; clear-all clears the tray. Persistent event IDs deduplicate pushes, feed catch-up, and cleared notifications. Missed/unopened remote notifications are loaded from the server inbox on resume; catch-up does not repeat popups. Background notification payloads are displayed by FCM/APNs, without relying on a running Dart timer or data-only background handler.

The Firebase packages are installed. Android has conditional Google Services integration; unconfigured builds remain usable for foreground polling and local popups. iOS has push entitlements and background modes; its minimum deployment target is now iOS 15 because the Firebase SDK requires it.

## Not yet connected

The supplied Android and iOS Firebase configurations are installed for project `areliaspace-supervisor-app` (project number `65259048392`). Android Google Services processes the JSON, and the iOS plist is included in Runner Copy Bundle Resources. Firebase receiving is enabled by default; debug builds expose Firebase console testing without extra flags. No APNs key, authenticated deployment connection, device-registration endpoint, Salesforce outbox or deployed sender was supplied. **Automatic Salesforce locked-phone/closed-app delivery is not active until the sender is connected.** `PUSH_ENABLED` still defaults to false and controls only the Salesforce backend integration. An honest setup status appears in the inbox, with an Enable button to request permission/retry registration. Existing foreground polling continues to work.

1. Completed: Android application `com.example.arelia_supervisor` and iOS bundle `com.example.areliaSupervisor` are registered and their supplied native configurations are installed. These client configuration files do not authorize server-side FCM sends or Salesforce deployment.
2. In Xcode, select the correct Apple team and enable Push Notifications for the App ID/provisioning profiles. Check `aps-environment` against development/distribution signing; the checked-in entitlement is development. Upload the APNs authentication key to Firebase. Enable Remote notifications/Background fetch. Build/sign on a Mac with Xcode (not available in this workspace).
3. Implement the authenticated Salesforce endpoints below and a durable outbox/sender. Do not enable production push registration until real recipient authorization is implemented. The existing mobile login is a shared client-credentials integration user, not an authenticated supervisor/manager identity; this must be resolved for individual delivery.
4. Build with `flutter run --dart-define=PUSH_ENABLED=true`. Sign in and allow notification permission. The registration status must report enabled before testing closed-app delivery.
5. Generate an actual Salesforce change or logged email event. Verify one matching inbox item and one tray/lock-screen alert, then test tap, sound-off, clear, offline/resume, token refresh and logout. Android force-stop and iOS force-quit/background restrictions can prevent delivery until reopening; OS permissions and lock-screen settings can hide previews.

## Salesforce endpoint contract

Base URL is the existing Salesforce instance plus `/services/apexrest/arelia-notifications/v1`. The client sends its existing Salesforce bearer token only to this instance. These endpoints are **a contract to deploy, not existing Salesforce standard APIs**.

- `PUT /devices`: `{ "token": "FCM device token", "platform": "android" | "ios", "sound": true }`. Idempotently register/refresh the device and its preference; return 2xx. Derive and authorize recipient identity on the server, never trust a caller-supplied user/role or email. Token-refresh callbacks and periodic authenticated refreshes retry registration. Remove invalid/stale tokens server-side.
- `DELETE /devices`: `{ "token": "..." }`. Remove only the authenticated user's registration. Logout invokes deregistration, disables FCM auto-init, deletes the FCM token and clears tray notifications before deleting session storage.
- `GET /events?cursor=<opaque cursor>`: `{ "events": [event], "cursor": "next cursor", "hasMore": false }`. Return authorized events in durable cursor order, paging when necessary. Empty result must still provide a cursor. Initial request returns retained unread/recent history; subsequent requests must include every event after the cursor. Retention/cursor-expiry behavior should be explicit (do not silently skip events).

Event schema (all FCM data fields must be strings):

```json
{
  "id": "durable-event-id",
  "title": "Project updated · Kitchen renovation",
  "body": "Installation: In progress",
  "time": "2026-09-09T10:00:00.000Z",
  "source": "Project",
  "recordId": "SalesforceRecordId"
}
```

Persist this same event before sending it. The FCM `notification` title/body must equal the `data` title/body. Use a stable id per transition/email, and reuse it for retries. For events also generated by fallback polling, use the app's exact ID convention (`<source>:<recordId>:<Salesforce LastModifiedDate>` or `Email:<EmailMessageId>`) to avoid a fallback duplicate. Do not collapse different events under one record-level identifier.

Capture Salesforce Lead, Opportunity, Project, Vendor Assignment and relevant child-stage transitions in a durable outbox through CDC, Apex or Flow. Include the actual previous/new stage and recipient at event time. For email/replies, log sent mail and ingest replies with sender, recipient, related record and historical stage. A phone cannot detect unlogged mailbox messages. An outbox worker must deliver retries idempotently, back off for 429/5xx, remove FCM UNREGISTERED tokens, and enforce recipient access before enqueueing/sending. The repository contains no deployed worker or Salesforce metadata for those pieces.

## Sender utility

`server/send_push.py` supplies a concrete FCM HTTP v1 payload and send utility for a trusted worker. It uses high Android priority, the matching sound/silent channel and event tag, and APNs alert payloads with priority 10. It includes both notification and data so the OS can display the alert while the app is closed. No background polling workaround is used.

Supply event and device JSON files to the utility. Device JSON has `token`, `platform`, `sound`. Use `--dry-run` to validate and preview with the token redacted. For an actual authorized send, the server environment must provide `FIREBASE_PROJECT_ID` and a short-lived `FCM_ACCESS_TOKEN` with Firebase Messaging send permission. Obtain it with the backend's workload identity; do not store service-account keys or server tokens in Flutter. This utility is not invoked by the app and has not sent any notifications.

## Known boundaries

Read/clear state currently belongs to this device, not a cross-device server preference. Seen-event tombstones persist to avoid reappearing cleared alerts and require a retention policy aligned with server feed retention for large deployments. Background sound preference changes take effect after successful device preference sync. A denied permission does not stop the in-app inbox. Until the backend is connected, alerts cannot be discovered while the app is suspended/closed, even though already-created local notifications remain in the tray/lock screen.

References: [Firebase Flutter receive behavior](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [Firebase platform setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [local notification plugin setup](https://pub.dev/packages/flutter_local_notifications/versions/19.5.0).

## Testing before Play Store publication

A debug APK installed directly on the phone can receive FCM notifications. Play Store publication is not a prerequisite. The device must have the appropriate Firebase configuration, notification permission and (Android) Google Play services. iOS still needs Apple signing/APNs setup.

### Verify display and tap routing without a Firebase project

In a debug build, open **Notifications → Delivery & sound → Test phone popup**, then switch to another app. This schedules one OS notification for 30 seconds later using an inexact Android alarm (the OS may delay it). Tap the notification to open the app's inbox. It is labeled as a test, not a Salesforce event. This verifies local display and routing only; it does not enable automatic detection of changes while the app is closed. The test is not rescheduled after reboot.

Cold-start notification taps now validate an existing Salesforce session and proceed to the home screen/inbox when valid. If the session is missing or expired, sign-in is required and the pending inbox destination is retained. Local popup payloads now include the event so tapping a test can add it to the inbox.

### Verify a real remote Firebase message before the Salesforce sender is deployed

1. The supplied Firebase configurations are installed. For iOS, finish APNs/signing setup first.
2. Run `flutter run` or install the newly built debug APK. Firebase test mode is now enabled by default in debug builds. It initializes Firebase without attempting to register through the not-yet-deployed Salesforce endpoints. Set `--dart-define=PUSH_TEST_MODE=false` to disable console-message fallback and the token-copy control; `--dart-define=FIREBASE_ENABLED=false` disables Firebase initialization.
3. Sign in, allow notifications, then use **Delivery & sound → Copy Firebase test token**.
4. From your Firebase project's Messaging console, send an authorized test notification to that token while the app is in the background. Alternatively use the existing trusted `server/send_push.py` utility with an event payload.
5. Tap it and verify the inbox opens. Firebase console messages without custom event data are labeled as Test events in debug test mode. Never publish the copied device token in logs or screenshots.

For **automatic delivery of every Salesforce/email event**, `PUSH_ENABLED=true` still requires the deployed recipient-scoped registration/inbox endpoints and an outbox sender. `PUSH_TEST_MODE` does not create those services. The Firebase project files are installed, but there is still no deployed Salesforce sender. No end-to-end remote test has been performed here: no phone is connected, no authenticated Firebase sending access is available, and this Mac has Command Line Tools rather than full Xcode.

## Automatic foreground checks

The signed-in Leads screen starts the notification service without waiting for the bell or inbox. A single 15-second timer is armed before initial network requests, tolerates an initially unknown lifecycle state and temporary inactive permission dialogs, pauses when hidden/paused/detached, and refreshes immediately on resume. Object queries run concurrently; email requests time out after 45 seconds so a hung request cannot permanently prevent subsequent checks. Slow requests can still delay a cycle; this polling interval is not an instant-delivery guarantee. Real cross-app/locked-phone Salesforce alerts still require the server sender above.
