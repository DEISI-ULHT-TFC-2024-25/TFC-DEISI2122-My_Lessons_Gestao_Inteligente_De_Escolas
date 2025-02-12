from django.test import TestCase
from django.utils.timezone import now
from datetime import timedelta, time, datetime, date
from equipment.models import Equipment
from lessons.models import GroupPack, GroupClass, ClassTicket, PrivateClass, PrivatePack, Voucher
from notifications.models import Notification
from users.models import Student, UserAccount, Instructor, Unavailability
from schools.models import School
from events.models import Activity

class GroupPackTests(TestCase):
    def setUp(self):
        self.user = UserAccount.objects.create(username="guardian")
        self.student = Student.objects.create(level=1, birthday=date(2000, 1, 1), user=self.user, first_name="Test", last_name="Student")
        self.group_pack = GroupPack.objects.create(
            date=date(2025,1,1),
            number_of_classes=5,
            number_of_classes_left=5,
            duration_in_minutes=60,
            price=200.00,
            student=self.student,
            expiration_date=date(2024,12,31),
        )
        # Create a school and an admin so we can test notifications
        self.school = School.objects.create(name="Test School", currency="USD")
        self.admin_user = UserAccount.objects.create(username="school_admin", first_name="Admin")
        self.school.admins.set([self.admin_user])
        self.school.save()


    def test_mark_done(self):
        self.group_pack.mark_done()
        self.assertTrue(self.group_pack.is_done)


    def test_book_new_pack(self):
        """
        Test the GroupPack.book_new_pack classmethod.
        We check if:
          - A new GroupPack is created with the correct data
          - The debt is set correctly
          - Tickets are created
          - Notifications are sent to parents and admins
        """

        # Make sure student has a "parent" relationship in place
        # (If your Student model's 'parents' is ManyToMany, do something like .add() or .set())
        # For example, if the Student model is set up with a many-to-many to UserAccount for parents:
        #   self.student.parents.add(self.user)
        # If it's a ForeignKey, then it's already set by self.student.user = self.user, etc.
        # Adjust this part based on your actual relationships:
        self.student.parents.add(self.user)

        date_of_pack = date(2025, 2, 1)
        number_of_classes = 10
        duration_in_minutes = 90
        price = 500.00
        payment = 200.00

        # Call the class method
        new_pack = GroupPack.book_new_pack(
            student=self.student,
            school=self.school,
            date=date_of_pack,
            number_of_classes=number_of_classes,
            duration_in_minutes=duration_in_minutes,
            price=price,
            payment=payment
        )

        # Check that the pack was created
        self.assertIsNotNone(new_pack.id)
        self.assertEqual(new_pack.student, self.student)
        self.assertEqual(new_pack.school, self.school)
        self.assertEqual(new_pack.date, date_of_pack)
        self.assertEqual(new_pack.number_of_classes, number_of_classes)
        self.assertEqual(new_pack.number_of_classes_left, number_of_classes)
        self.assertEqual(new_pack.duration_in_minutes, duration_in_minutes)
        self.assertEqual(new_pack.price, price)

        # Debt should be the price minus the payment
        self.assertEqual(new_pack.debt, price - payment)
        self.assertFalse(new_pack.is_paid)  # Because there's still debt left

        # Check tickets
        tickets = new_pack.tickets.all()
        self.assertEqual(tickets.count(), number_of_classes)
        for ticket in tickets:
            self.assertEqual(ticket.student, self.student)
            self.assertEqual(ticket.pack, new_pack)
            self.assertFalse(ticket.is_used)

        # Check that notifications were sent to the parent
        parent_notifications = Notification.objects.filter(user=self.user)
        self.assertTrue(parent_notifications.exists(), "Expected a notification for the parent.")
        # Optionally assert on the subject/message if you have known templates

        # Check that notifications were sent to the school admin
        admin_notifications = Notification.objects.filter(user=self.admin_user)
        self.assertTrue(admin_notifications.exists(), "Expected a notification for the school admin.")
        
        # Make sure the parents field on the pack is set (if relevant):
        self.assertIn(self.user, new_pack.parents.all())
        
        # You can test further things like discount deletion if discount_id was provided, etc.
        # But for a basic test, this should cover the main functionality.

class GroupClassTests(TestCase):
    def setUp(self):
        self.user = UserAccount.objects.create(username="guardian")
        self.student = Student.objects.create(level=1, birthday=date(2015, 1, 1), user=self.user, first_name="Test", last_name="Student")
        self.instructor = Instructor.objects.create(user=UserAccount.objects.create(username="instructor"))
        self.group_class = GroupClass.objects.create(
            date=date(2025,1,2),
            start_time=time(9, 30),
            end_time=time(10, 30),
            duration_in_minutes=60,
            level=1,
            minimum_age=5,
            maximum_age=22,
            maximum_number_of_students=10,
        )

    def test_is_full(self):
        self.assertFalse(self.group_class.is_full())
        for _ in range(10):
            self.assertTrue(self.group_class.add_student(Student.objects.create(level=1, birthday=date(2015, 1, 1), user=UserAccount.objects.create(username=f"student_{_}"))))
        self.assertTrue(self.group_class.is_full())
        self.assertFalse(self.group_class.add_student(self.student))

    def test_add_students_with_unavailability(self):
        self.assertTrue(self.group_class.add_student(self.student))
        self.assertTrue(self.group_class.remove_student(self.student))

        unavailability = Unavailability.objects.create(
                            student=self.student,
                            date=date(2025, 1, 2),
                            start_time=time(9, 30),
                            end_time=time(11, 30),
                            duration_in_minutes=120,
                        )

        # Check that the unavailability is linked to the student
        self.assertIn(unavailability, self.student.unavailabilities.all())
        
        # Ensure the student cannot be added if they have a conflict
        self.assertFalse(self.group_class.add_student(self.student))

    def test_add_instructor_success(self):
        self.group_class.add_instructor(self.instructor)
        self.assertIn(self.instructor, self.group_class.instructors.all())

class PrivateClassTests(TestCase):
    def setUp(self):
        self.school = School.objects.create(name="Test School", currency="EUR")
        self.admin = UserAccount.objects.create(username="admin", email="admin@testschool.com", first_name="Admin")
        self.school.admins.set([self.admin])
        self.school.save()

        self.instructor_user = UserAccount.objects.create(username="instructor", first_name="John", last_name="Doe")
        self.instructor = Instructor.objects.create(user=self.instructor_user)

        self.parent_user = UserAccount.objects.create(username="parent", first_name="Jane", last_name="Smith", email="parent@test.com")
        self.student = Student.objects.create(level=1, birthday=date(2010, 1, 1), first_name="Alice", last_name="Smith")
        self.student.parents.add(self.parent_user)
        self.private_class = PrivateClass.objects.create(
            date=date(2025,1,3),
            start_time=time(10, 0),
            end_time=time(11, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            instructor=self.instructor,
            school=self.school,
        )
        self.private_class.students.set([self.student])
        # Prepare test data
        date_of_pack = now().date()
        number_of_classes = 5
        duration_in_minutes = 60
        price = 300.00
        payment = 300.00

        # Call the book_new_pack function
        self.pack = PrivatePack.book_new_pack(
            students=[self.student],
            school=self.school,
            date=date_of_pack,
            number_of_classes=number_of_classes,
            duration_in_minutes=duration_in_minutes,
            instructor=self.instructor,
            price=price,
            payment=payment
        )
        self.private_class.pack = self.pack
        self.private_class.save()

    def test_calculate_extra_prices(self):
        skateboard1 = Equipment.objects.create(name="skateboard", school=self.school)
        skateboard2 = Equipment.objects.create(name="skateboard", school=self.school)
        helmet = Equipment.objects.create(name="helmet", school=self.school)

        self.private_class.equipments.set([skateboard1, skateboard2, helmet])
        self.private_class.number_of_extra_students = 1  # Fix for counting students

        self.assertTrue(self.school.update_extra_price(skateboard1.name, 10))
        self.assertTrue(self.school.update_extra_price(helmet.name, 7))
        self.assertTrue(self.school.update_extra_price('extra_students', 20))

        self.assertEqual(self.private_class.get_extra_costs(), {
            "extra_students": "1x20",
            "skateboard": "2x10",
            "helmet": "1x7",
            "total_price": 47
        })

    def test_is_available(self):
        is_available, instructor = self.private_class.is_available(self.instructor, date(2025,1,3), time(10, 0))
        self.assertTrue(is_available)
        self.assertEqual(instructor, self.instructor)

    def test_schedule_and_reschedule(self):
        

        # Verify the pack creation
        self.assertIsNotNone(self.pack)
        scheduled = self.private_class.schedule_lesson(date(2025,1,3), time(10, 0))
        self.assertTrue(scheduled)
        self.assertEqual(self.private_class.date, date(2025,1,3))
        self.private_class.unschedule_lesson()
        self.assertIsNone(self.private_class.date)
        self.assertIsNone(self.private_class.start_time)
        fail_lesson_datetime = now() + timedelta(hours=23)
        success_lesson_datetime = now() + timedelta(hours=25)
        self.private_class.date = fail_lesson_datetime.date()
        self.private_class.start_time = fail_lesson_datetime.time()
        self.assertIsNotNone(self.private_class.date)
        self.assertIsNotNone(self.private_class.start_time)
        self.assertFalse(self.private_class.can_still_reschedule())
        self.private_class.date = success_lesson_datetime.date()
        self.private_class.start_time = success_lesson_datetime.time()
        self.assertTrue(self.private_class.can_still_reschedule())

    def test_schedule_while_instructor_is_unavailable(self):

        self.assertTrue(self.private_class.schedule_lesson(date=date(2025, 1, 2), time=time(9, 30)))
        self.assertEqual(date(2025, 1,2), self.private_class.date)
        self.assertEqual(time(9, 30), self.private_class.start_time)
        self.assertEqual(time(10, 30), self.private_class.end_time)
        unavailabilities = Unavailability.define_unavailability(
            instructor=self.instructor,
            date=date(2025, 1, 2),
            start_time=time(9, 30),
            end_time=time(11, 30),
            school=self.school
        )
        self.assertEqual(len(unavailabilities), 1)
        unavailability = unavailabilities[0]
        self.assertEqual(unavailability.instructor, self.instructor)
        # Verify notifications for the instructor
        instructor_notifications = Notification.objects.filter(user=self.instructor.user)
        self.assertTrue(instructor_notifications.exists())
        instructor_conflict_notifications = 0
        for notification in instructor_notifications:
            if "Conflict Detected" in notification.subject:
                instructor_conflict_notifications =+ 1
        self.assertEqual(1, instructor_conflict_notifications)

        # Verify notifications for parents
        for student in self.private_class.students.all():
            for parent in student.parents.all():
                parent_notifications = Notification.objects.filter(user=parent)
                self.assertTrue(parent_notifications.exists())
                parent_conflict_notifications = 0
                for notification in parent_notifications:
                    if "Conflict Detected" in notification.subject:
                        parent_conflict_notifications =+ 1
                self.assertEqual(1, parent_conflict_notifications)
        self.assertFalse(self.private_class.schedule_lesson(date=date(2025, 1, 2), time=time(9, 30)))
        self.assertTrue(self.private_class.schedule_lesson(date=date(2025, 1, 2), time=time(11, 30)))
        self.assertTrue(self.private_class.unschedule_lesson())
        self.assertIsNone(self.private_class.date)

        private_class2 = PrivateClass.objects.create(
            date=date(2025,1,2),
            start_time=time(12, 0),
            end_time=time(13, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            instructor=self.instructor,
            school=self.school,
        )
        private_class2.students.set([Student.objects.create(level=1, birthday=date(2010, 1, 1), first_name="Joao", last_name="Silva")])
        self.assertFalse(self.private_class.schedule_lesson(date=date(2025, 1, 2), time=time(12, 30)))
        self.assertTrue(self.private_class.schedule_lesson(date=date(2025, 1, 2), time=time(13, 30)))
        self.assertTrue(self.private_class.unschedule_lesson())
        self.assertIsNone(self.private_class.date)

        group_class = GroupClass.objects.create(
            date=date(2025,1,2),
            start_time=time(16, 00),
            end_time=time(17, 00),
            duration_in_minutes=60,
            level=1,
            minimum_age=5,
            maximum_age=22,
            maximum_number_of_students=10,
        )
        self.assertTrue(group_class.add_instructor(instructor=self.instructor))
        self.assertEqual(self.instructor, self.private_class.instructor)
        self.assertFalse(self.private_class.schedule_lesson(date=date(2025, 1, 2), time=time(16, 30)))
        self.assertTrue(self.private_class.schedule_lesson(date=date(2025, 1, 2), time=time(17, 00)))


        activity = Activity.objects.create(name='Activity', student_price=50.00, monitor_price=40.00, date=date(2025, 1, 20), start_time=time(10, 00), end_time=time(11, 00), duration_in_minutes=60, school=School.objects.create(name="School"))
        self.assertTrue(activity.add_instructor(instructor=self.instructor))        
        self.assertFalse(self.private_class.schedule_lesson(date=date(2025, 1, 20), time=time(10, 00)))
        self.assertTrue(self.private_class.schedule_lesson(date=date(2025, 1, 20), time=time(11, 00)))

class PrivatePackTests(TestCase):
    def setUp(self):
        self.school = School.objects.create(name="Test School", currency="EUR")
        self.admin = UserAccount.objects.create(username="admin", email="admin@testschool.com", first_name="Admin")
        self.school.admins.set([self.admin])
        self.school.save()

        self.instructor_user = UserAccount.objects.create(username="instructor", first_name="John", last_name="Doe")
        self.instructor = Instructor.objects.create(user=self.instructor_user)

        self.parent_user = UserAccount.objects.create(username="parent", first_name="Jane", last_name="Smith", email="parent@test.com")
        self.student = Student.objects.create(level=1, birthday=date(2010, 1, 1), first_name="Alice", last_name="Smith")
        self.student.parents.add(self.parent_user)

    def test_book_new_pack(self):
        # Prepare test data
        date_of_pack = now().date()
        number_of_classes = 5
        duration_in_minutes = 60
        price = 300.00
        payment = 300.00

        # Call the book_new_pack function
        pack = PrivatePack.book_new_pack(
            students=[self.student],
            school=self.school,
            date=date_of_pack,
            number_of_classes=number_of_classes,
            duration_in_minutes=duration_in_minutes,
            instructor=self.instructor,
            price=price,
            payment=payment
        )

        # Verify the pack creation
        self.assertIsNotNone(pack)
        self.assertEqual(pack.number_of_classes, number_of_classes)
        self.assertEqual(pack.duration_in_minutes, duration_in_minutes)
        self.assertEqual(pack.price, price)
        self.assertIn(self.student, pack.students.all())
        self.assertEqual(pack.school, self.school)

        # Verify notifications to parents
        parent_notifications = Notification.objects.filter(user=self.parent_user)
        self.assertEqual(parent_notifications.count(), 1)
        parent_notification = parent_notifications.first()
        self.assertIn("Alice Smith", parent_notification.message)
        self.assertIn("Private Pack", parent_notification.subject)

        # Verify notifications to instructor
        instructor_notifications = Notification.objects.filter(user=self.instructor_user)
        self.assertEqual(instructor_notifications.count(), 1)
        instructor_notification = instructor_notifications.first()
        self.assertIn("Alice Smith", instructor_notification.message)
        self.assertIn("New Private Pack Assigned", instructor_notification.subject)

        # Verify notifications to school admin
        admin_notifications = Notification.objects.filter(user=self.admin)
        self.assertEqual(admin_notifications.count(), 1)
        admin_notification = admin_notifications.first()
        self.assertIn("Alice Smith", admin_notification.message)
        self.assertIn("New Private Pack Booked", admin_notification.subject)

        private_classes = pack.classes
        self.assertEqual(private_classes.count(), pack.number_of_classes)

        pack.mark_done()
        self.assertTrue(pack.is_done)

class VoucherTests(TestCase):
    def setUp(self):
        self.user = UserAccount.objects.create(username="guardian")
        self.group_pack = GroupPack.objects.create(
            date=now().date(),
            number_of_classes=5,
            number_of_classes_left=5,
            duration_in_minutes=60,
            price=200.00,
            student=Student.objects.create(level=1, birthday=date(2000, 1, 1), user=self.user, first_name="Test", last_name="Student"),
            expiration_date=now().date(),
        )
        self.voucher = Voucher.objects.create(
            user=self.user,
            group_pack=self.group_pack,
            expiration_date=now().date(),
        )

    def test_is_expired(self):
        self.assertFalse(self.voucher.is_expired())
        self.voucher.expiration_date = now().date() - timedelta(days=1)
        self.assertTrue(self.voucher.is_expired())
