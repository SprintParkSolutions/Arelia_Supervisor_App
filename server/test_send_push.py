import unittest
from send_push import build_message


class PushPayloadTest(unittest.TestCase):
    def setUp(self):
        self.event = dict(id="event-1", title="Project updated", body="Stage: In progress",
                          time="2026-09-09T10:00:00Z", source="Project", recordId="record-1")

    def test_os_visible_alert_and_matching_inbox(self):
        message = build_message(self.event, "device-token")["message"]
        self.assertEqual(message["data"], self.event)
        self.assertEqual(message["notification"]["body"], self.event["body"])
        self.assertEqual(message["android"]["priority"], "high")
        self.assertEqual(message["android"]["notification"]["tag"], "event-1")
        self.assertEqual(message["apns"]["headers"]["apns-push-type"], "alert")
        self.assertEqual(message["apns"]["payload"]["aps"]["sound"], "default")

    def test_silent_channel_and_apns(self):
        message = build_message(self.event, "device-token", sound=False)["message"]
        self.assertEqual(message["android"]["notification"]["channel_id"], "arelia_updates_silent_v1")
        self.assertNotIn("sound", message["apns"]["payload"]["aps"])

    def test_invalid_and_oversized_events(self):
        with self.assertRaises(ValueError):
            build_message({}, "token")
        self.event["body"] = "x" * 4000
        with self.assertRaises(ValueError):
            build_message(self.event, "token")


if __name__ == "__main__":
    unittest.main()
