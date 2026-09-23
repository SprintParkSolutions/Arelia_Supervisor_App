import '../models/email_recipients.dart';

/// Email routing must be supplied for the intended deployment. The current
/// client-credentials login identifies the integration user, not a person.
class NotificationConfig {
  static const supervisorEmail = String.fromEnvironment(
    'SUPERVISOR_NOTIFICATION_EMAIL',
  );
  static const managerEmail = String.fromEnvironment(
    'MANAGER_NOTIFICATION_EMAIL',
  );

  static Map<String, String> get recipients => EmailRecipients.groups(
    supervisor: supervisorEmail,
    manager: managerEmail,
  );
}
