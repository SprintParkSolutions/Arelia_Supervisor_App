# Notification overview

Phone popup support has now been added. See [push-notifications.md](push-notifications.md) for the current implementation, Firebase configuration, sender contract and remaining deployment work. The notes below describe the original polling fallback; their statement that push handling is absent has been superseded by that document.

# Notification implementation and deployment

The app checks Lead, Opportunity, Project__c and the discovered Vendor Assignment object every 15 seconds while open, and on resume. A bell on each main screen opens a persistent inbox with unread badges, mark-read, individual clear, clear-all, close and sound controls. It retains the latest 500 alerts on this device. Clearing does not delete Salesforce data. Notification state is keyed by Salesforce organization and user; logout deletes local storage.

First use silently snapshots accessible records. Subsequent queries use persisted timestamps, overlap and pagination. Failed sources retain their cursor and display an error independently. Status, stage, approval and completion fields are discovered through object describe; messages show their actual values. Boolean approval does not imply a whole stage has completed. Any record LastModifiedDate change generates an alert, including app writes confirmed by Salesforce. Native foreground audio is implemented for Android and iOS; device sound settings still apply.

## Email configuration

Email alerts are disabled until the deployment supplies recipient addresses:

```sh
flutter run --dart-define=SUPERVISOR_NOTIFICATION_EMAIL=supervisor@example.com --dart-define=MANAGER_NOTIFICATION_EMAIL=manager@example.com
```

Only EmailMessage rows addressed to an exact configured To/Cc address create alerts. The query excludes draft outbound mail. Sender and subject appear in the alert; a non-null ReplyToEmailMessageId identifies a reply. RelatedToId provides the related record name when that record is monitored. Email bodies are not fetched or stored. These alerts indicate a logged email, not a delivery receipt.

Salesforce must log outbound automation emails and ingest incoming replies as EmailMessage, preserving recipients, sender, thread link and record association. Ordinary mailbox messages and unlogged Apex emails cannot be detected by this app. Access to these objects/fields must be granted to the existing authenticated Salesforce principal.

The app uses client-credentials authentication: every installation uses the integration user's access. It does not currently authenticate individual supervisors/managers. Compile-time recipients are deployment configuration, not authorization. Per-person delivery requires real user identity and server-enforced recipient access. Neither recipient addresses nor org configuration were available for live verification.

## Remaining work for complete event delivery

This implementation is foreground polling, not remote push. No Firebase/APNs credentials, Salesforce metadata project, backend or mailbox integration were supplied. It does not notify while closed, capture deletes, preserve every intermediate stage change between polls, or detect child-only changes that leave the parent LastModifiedDate unchanged. The first baseline can be expensive in large orgs, and polling consumes Salesforce API requests (at least four per minute per active installation). Stored snapshots grow with accessible records. Use a server event feed for production scale.

To finish full delivery:

1. Identify each app user and their supervisor/manager assignment; enforce record and notification visibility on the server.
2. Configure Salesforce change events or an Apex/Flow outbox for all required parent and child workflow objects. Persist a unique event ID, recipient user ID, record ID/name, event time, stage and exact previous/new status.
3. Log sent emails and ingest replies. Persist email event ID, sender, recipient role, related record and the stage at email time. Current record status cannot establish the historical email stage.
4. Use a trusted backend to consume the durable outbox and send FCM/APNs push notifications. Configure mobile push permissions, token registration/rotation/removal and foreground/background handlers. Never put push-server credentials in the app.
5. Merge push and feed events by their server event ID; keep read/dismiss state on the server if it must sync across devices.

## Verification

Run `flutter test` and `flutter analyze --no-pub`. Device acceptance: establish baseline; edit a record externally and from the app; verify one alert with correct field values within the polling interval; clear and restart; verify cleared alerts stay cleared; test offline recovery and navigation across all four tabs. Verify audio on physical Android/iOS devices. With configured recipients and Salesforce logging, test new mail, linked replies, unrelated recipients and To/Cc matching. Background/closed delivery is not an acceptance claim for this implementation.

References: [Salesforce EmailMessage](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_emailmessage.htm), [Android notification sound](https://developer.android.com/reference/android/media/RingtoneManager), [Apple alert sound](https://developer.apple.com/documentation/audiotoolbox/audioservicesplayalertsound(_:)).

## Email settings and earlier messages

The notification panel now provides **Delivery & sound → Email settings** for entering the Supervisor and Manager recipient addresses without recompiling. These matching preferences are saved with the current Salesforce user's notification state; they do not grant Salesforce access or change server push routing. Compile-time addresses remain initial defaults.

Saving loads the last 30 days of matching logged EmailMessage records. **Load previous emails → All recorded emails** searches the available Salesforce history using the paginated email query. Earlier emails are imported silently; later matches can create normal notifications. Outgoing rows are labeled “Email sent to Manager” (or Supervisor). Previously cleared IDs stay cleared. The inbox retains its existing limit of the latest 500 notifications across all categories.

Matching still requires To/Cc recipient addresses and accessible EmailMessage records. A successful Additional Budget update does not prove that an email was sent or logged. If Apex/Flow sends emails without storing them as EmailMessage records, the org automation must add email logging; this app cannot reconstruct historical unlogged sends or read an external mailbox. Empty-history and access errors are displayed in Delivery & sound.

The **Supervisor emails** and **Manager emails** fields accept multiple addresses separated by commas, semicolons, or new lines. All addresses are validated before saving, normalized for case, deduplicated and restored in full when reopening settings. A shared address can belong to both roles. Matching several configured To/Cc recipients produces one notification per email with distinct role labels, rather than duplicate alerts. The existing single-address saved format remains compatible.

## Descriptive notification content

Notifications now compare assignment lookups, stages/statuses, approval flags, appointment dates, invoice/payment and budget fields exposed by the Salesforce describe API. Supervisor/manager lookups to supported named objects include the related name, with assigned/reassigned/removed wording. Proforma Invoice records are checked separately and appear under Invoices. Client Status moving to Sent is described as marked as sent, not proof of delivered email. Logged email alerts include the subject, sender, To and Cc recipients. Inbox and local phone popups use the same event title/body.

Previously untracked fields establish a baseline on the first check after upgrade; missing old fields are not mistaken for a new assignment. Previously saved generic notifications cannot recover old transitions and remain unchanged. New records without a prior snapshot show current tracked values rather than invented transitions. Changes outside tracked fields still have an honest fallback. Polling only sees final values between checks, so intermediate transitions need the server event feed. Remote senders must use the same descriptive title/body in data and notification payloads.

### General business-field coverage

Notification selection no longer depends on keywords or a list of five workflow examples. All readable supported scalar business fields exposed by describe are compared on the monitored Lead, Opportunity, Project, Vendor Assignment and Proforma Invoice objects. This includes new custom fields without app-specific wording code. Audit bookkeeping, hidden/deprecated fields, encrypted fields and binary/compound values are excluded. Text previews are limited to 180 characters per field; percentages, multiple selections and timestamps are formatted for display. Related records are described as linked/changed, while people assignments retain assigned/reassigned wording. Wide object queries are split into 80-field batches and rejected for retry if record versions change between batches.

This expands message detail for monitored records; it does not claim to capture arbitrary unmonitored child objects, unlogged emails, deletions, or every intermediate change between polling cycles. Existing generic history cannot be reconstructed. Newly added fields take a baseline on the first check, as before.

### Confirmed in-app assignment actions and delivery latency

Lead supervisor assignment now emits its own descriptive inbox/phone event immediately after a successful Salesforce PATCH, before the detail reload. Selecting the existing supervisor does not generate another assignment alert; failed requests produce no success notification. Confirmed field values are persisted and reconciled with polling so the same assignment does not generate a second polling alert; other changed fields still notify.

Each source publishes ready alerts as soon as its query completes rather than waiting for every other source and email history. Updates without comparable fields still produce a fallback alert; only a matched, already-notified confirmed action is suppressed. External Salesforce changes still use the 15-second foreground polling schedule and depend on network response time. This does not enable closed-app detection without the remote sender.

### Notification delivery regression recovery

The hasDetails gate was too strict: legitimate LastModifiedDate changes with no comparable business fields were discarded from both the inbox and local popup callback. Such updates now notify once using the existing fallback; detailed messages and action-specific duplicate suppression remain. Salesforce INVALID_FIELD failures in expanded queries fall back to Id, Name and LastModifiedDate, and the inbox reports that detailed fields are unavailable. Authentication, rate-limit and network errors remain errors and do not advance the source cursor. The fallback uses normal pagination and never manufactures an assignment or email delivery claim.
