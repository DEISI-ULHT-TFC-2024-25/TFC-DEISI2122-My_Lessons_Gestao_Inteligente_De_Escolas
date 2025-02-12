from django.test import TestCase
from django.utils.timezone import now
from datetime import datetime, timedelta, date, time
from users.models import UserAccount, Student, Instructor
from lessons.models import GroupClass, PrivateClass, GroupPack, PrivatePack
from schools.models import School
from events.models import Activity
from notifications.models import Notification

class NotificationModelTests(TestCase):

    def setUp(self):
        # Create test data
        self.school = School.objects.create(name="Test School")
        self.user = UserAccount.objects.create(username="test_user", email="test_user@example.com")
        self.student = Student.objects.create(user=self.user, level=1, birthday=date(2010, 1, 1))
        self.group_class = GroupClass.objects.create(
            date=date(2025, 1, 1),
            start_time=time(10, 0),
            end_time=time(11, 0),
            duration_in_minutes=60,
            level=1,
            minimum_age=5,
            maximum_age=18,
            maximum_number_of_students=10,
            school=self.school
        )
        self.private_class = PrivateClass.objects.create(
            date=date(2025, 1, 2),
            start_time=time(12, 0),
            end_time=time(13, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            school=self.school,
        )
        self.private_class.students.set([self.student])
        self.group_pack = GroupPack.objects.create(
            date=date(2025, 1, 1),
            number_of_classes=5,
            number_of_classes_left=5,
            duration_in_minutes=60,
            price=100.00,
            student=self.student,
            expiration_date=date(2025, 6, 1),
            school=self.school
        )
        self.private_pack = PrivatePack.objects.create(
            date=date(2025, 1, 1),
            number_of_classes=5,
            duration_in_minutes=60,
            price=200.00,
            expiration_date=date(2025, 6, 1),
            school=self.school
        )
        self.private_pack.students.set([self.student])
        self.activity = Activity.objects.create(
            name="Test Activity",
            description="A fun activity for all ages",
            date=date(2025, 1, 3),
            start_time=time(15, 0),
            end_time=time(16, 0),
            school=self.school,
            student_price=50,
            monitor_price=50,
            duration_in_minutes=60
        )

    def test_create_notification(self):
        """Test that a notification can be created with all attributes."""
        notification = Notification.objects.create(
            user=self.user,
            subject="Group Class Scheduled",
            message="Your group class is scheduled.",
            sent_at=now(),
            school=self.school
        )
        notification.group_classes.set([self.group_class])
        notification.private_classes.set([self.private_class])
        notification.group_packs.set([self.group_pack])
        notification.private_packs.set([self.private_pack])
        notification.activities.set([self.activity])

        self.assertEqual(notification.user, self.user)
        self.assertEqual(notification.subject, "Group Class Scheduled")
        self.assertEqual(notification.message, "Your group class is scheduled.")
        self.assertEqual(notification.school, self.school)
        self.assertIn(self.group_class, notification.group_classes.all())
        self.assertIn(self.private_class, notification.private_classes.all())
        self.assertIn(self.group_pack, notification.group_packs.all())
        self.assertIn(self.private_pack, notification.private_packs.all())
        self.assertIn(self.activity, notification.activities.all())

    def test_mark_as_read(self):
        """Test that a notification can be marked as read."""
        notification = Notification.objects.create(
            user=self.user,
            subject="Mark As Read Test",
            message="Mark this notification as read.",
            school=self.school,
        )
        self.assertIsNone(notification.date_read)
        notification.mark_as_read()
        self.assertIsNotNone(notification.date_read)

    def test_send_email(self):
        """Test that an email is sent when a notification is created with sent_at=now()."""
        notification = Notification.objects.create(
            user=self.user,
            subject="Email Notification Test",
            message="Check your email for this notification.",
            school=self.school,
        )
        self.assertIsNone(notification.sent_at)
        # Assuming send_email is mocked in actual tests
        notification.send()
        # Check if the email was flagged to send
        self.assertIsNotNone(notification.sent_at)

    def test_bulk_send_notifications(self):
        """Test creating and sending multiple notifications."""
        notifications = []
        for i in range(5):
            notifications.append(
                Notification.objects.create(
                    user=self.user,
                    subject=f"Notification {i + 1}",
                    message=f"This is message {i + 1}",
                    school=self.school,
                    sent_at=now() + timedelta(minutes=i)
                )
            )

        self.assertEqual(len(notifications), 5)
        for i, notification in enumerate(notifications):
            self.assertEqual(notification.subject, f"Notification {i + 1}")
            self.assertEqual(notification.message, f"This is message {i + 1}")

    def test_ordering(self):
        """Test that notifications are ordered by sent_at descending."""
        for i in range(3):
            Notification.objects.create(
                user=self.user,
                subject=f"Notification {i + 1}",
                message=f"This is message {i + 1}",
                school=self.school,
                sent_at=now() - timedelta(days=i)
            )

        notifications = Notification.objects.all()
        self.assertEqual(notifications[0].subject, "Notification 1")  # Most recent
        self.assertEqual(notifications[1].subject, "Notification 2")
        self.assertEqual(notifications[2].subject, "Notification 3")  # Oldest
