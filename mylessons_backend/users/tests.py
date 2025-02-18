from django.test import TestCase
from lessons.models import PrivateClass, PrivatePack, UserAccount, Instructor, Unavailability
from schools.models import School
from datetime import datetime, timedelta, date, time
from django.utils.timezone import now
from users.models import Student

class StudentTests(TestCase):
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

    def test_get_all_booked_private_lessons(self):
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
        private_lesson1 = pack.classes.all()[0]
        private_lesson2 = pack.classes.all()[1]
        private_lesson3 = pack.classes.all()[2]
        private_lesson4 = pack.classes.all()[3]
        self.assertIsNotNone(private_lesson1)
        self.assertIsNotNone(private_lesson2)
        self.assertIsNotNone(private_lesson3)
        self.assertIsNotNone(private_lesson4)
        self.assertTrue(private_lesson1.schedule_lesson(date(2025,1,1), time(10,00)))
        self.assertTrue(private_lesson2.schedule_lesson(date(2025,1,1), time(11,00)))
        self.assertFalse(private_lesson3.schedule_lesson(date(2025,1,1), time(10,00)))
        self.assertFalse(private_lesson4.schedule_lesson(date(2025,1,1), time(11,00)))

        lessons = self.student.get_all_booked_private_lessons()

        self.assertIn(private_lesson1, lessons)
        self.assertIn(private_lesson2, lessons)
        self.assertIsNone(private_lesson3.date)
        self.assertIsNone(private_lesson3.start_time)
        self.assertIsNone(private_lesson4.date)
        self.assertIsNone(private_lesson4.start_time)
        self.assertNotIn(private_lesson3, lessons)
        self.assertNotIn(private_lesson4, lessons)

class InstructorTests(TestCase):
    def setUp(self):
        # Create an instructor with a related UserAccount
        self.instructor = Instructor.objects.create(
            user=UserAccount.objects.create(username="instructor")
        )
        # Create a school
        self.school = School.objects.create(name='School')
        
        # Create a couple of unavailability objects
        self.unavailability1 = Unavailability.objects.create(
            instructor=self.instructor,
            date=date(2025, 1, 2),
            start_time=time(13, 0),
            end_time=time(14, 0),
            duration_in_minutes=60,
        )
        self.unavailability2 = Unavailability.objects.create(
            instructor=self.instructor,
            date=date(2025, 1, 2),
            start_time=time(10, 0),
            end_time=time(12, 0),
            duration_in_minutes=120,
        )
        # Create a private class
        self.private_class = PrivateClass.objects.create(
            date=date(2025, 1, 2),
            start_time=time(15, 0),
            end_time=time(16, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            instructor=self.instructor,
            school=self.school,
        )
        # Create and assign a student to the private class
        student = Student.objects.create(
            level=1,
            birthday=date(2001, 1, 1),
            first_name="Alice",
            last_name="Silva"
        )
        self.private_class.students.set([student])

    def test_view_available_lesson_times(self):
        # Ensure the instructor is added to the school (which also initializes payment_types)
        self.assertTrue(self.school.add_instructor(self.instructor))
        times_list = self.instructor.view_available_lesson_times(
            date(2025, 1, 2), 60, 60, self.school, False, True
        )
        self.assertNotIn(time(8, 0), times_list)
        self.assertIn(time(9, 0), times_list)
        self.assertNotIn(time(10, 0), times_list)
        self.assertNotIn(time(11, 0), times_list)
        self.assertIn(time(12, 0), times_list)
        self.assertNotIn(time(13, 0), times_list)
        self.assertIn(time(14, 0), times_list)
        self.assertNotIn(time(15, 0), times_list)
        self.assertIn(time(16, 0), times_list)
        self.assertIn(time(17, 0), times_list)
        self.assertNotIn(time(18, 0), times_list)

    def test_payment_types_initialization_and_update(self):
        # Add the instructor to the school and initialize payment_types
        self.assertTrue(self.school.add_instructor(self.instructor))
        
        # Refresh the instructor from the DB to ensure changes are persisted
        self.instructor.refresh_from_db()
        
        # The instructor's payment_types should now have an entry for the school name
        self.assertIn(self.school.name, self.instructor.user.payment_types)
        pt = self.instructor.user.payment_types[self.school.name]
        # With the new structure, the top-level keys are the roles directly
        self.assertIn("instructor", pt)
        
        # Update a nested value:
        # Set instructor[private lesson][fixed][60-1-4] to 10.00
        self.school.update_payment_type_value(
            "instructor[private lesson][fixed][60-1-4]", 10.00, user_obj=self.instructor.user
        )
        self.instructor.refresh_from_db()
        updated_value = self.instructor.user.payment_types[self.school.name]["instructor"]["private lesson"]["fixed"].get("60-1-4")
        self.assertEqual(updated_value, 10.00)

        # Update a nested value again:
        # Set instructor[private lesson][fixed][60-1-4] to 20.00
        self.school.update_payment_type_value(
            "instructor[private lesson][fixed][60-1-4]", 20.00, user_obj=self.instructor.user
        )
        self.instructor.refresh_from_db()
        updated_value = self.instructor.user.payment_types[self.school.name]["instructor"]["private lesson"]["fixed"].get("60-1-4")
        self.assertEqual(updated_value, 20.00)
        
        # Remove the instructor from the school; this should also remove the payment_types entry
        self.assertTrue(self.school.remove_instructor(self.instructor))
        self.instructor.refresh_from_db()
        self.assertNotIn(self.school.name, self.instructor.user.payment_types)


class UnavailabilityTests(TestCase):

    def setUp(self):
        # Create test data
        self.school = School.objects.create(name="Test School")
        self.user_instructor = UserAccount.objects.create(username="test_instructor")
        self.instructor = Instructor.objects.create(user=self.user_instructor)
        self.user_student = UserAccount.objects.create(username="test_student")
        self.student = Student.objects.create(user=self.user_student, level=1, birthday=date(2000, 1, 1))


    def test_single_unavailability(self):
        """
        Test creating a single unavailability for an instructor.
        """
        unavailabilities = Unavailability.define_unavailability(
            instructor=self.instructor,
            date=date(2025, 1, 25),
            start_time=time(10, 0),
            end_time=time(12, 0),
            school=self.school
        )
        self.assertEqual(len(unavailabilities), 1)
        unavailability = unavailabilities[0]
        self.assertEqual(unavailability.instructor, self.instructor)
        self.assertEqual(unavailability.date, date(2025, 1, 25))
        self.assertEqual(unavailability.start_time, time(10, 0))
        self.assertEqual(unavailability.end_time, time(12, 0))
        self.assertEqual(unavailability.school, self.school)

    def test_recurring_daily_unavailability(self):
        """
        Test creating recurring daily unavailability for an instructor.
        """
        unavailabilities = Unavailability.define_unavailability(
            instructor=self.instructor,
            date=date(2025, 1, 25),
            start_time=time(10, 0),
            end_time=time(12, 0),
            recurrence={
                'type': 'daily',
                'frequency': 1,
                'end_date': date(2025, 1, 28)
            },
            school=self.school
        )
        self.assertEqual(len(unavailabilities), 4)  # Jan 25, 26, 27, 28
        for i, unavailability in enumerate(unavailabilities):
            self.assertEqual(unavailability.date, date(2025, 1, 25) + timedelta(days=i))
            self.assertEqual(unavailability.start_time, time(10, 0))
            self.assertEqual(unavailability.end_time, time(12, 0))

    def test_recurring_weekly_unavailability(self):
        """
        Test creating recurring weekly unavailability for an instructor.
        """
        unavailabilities = Unavailability.define_unavailability(
            instructor=self.instructor,
            date=date(2025, 1, 25),
            start_time=time(14, 0),
            end_time=time(16, 0),
            recurrence={
                'type': 'weekly',
                'frequency': 1,
                'end_date': date(2025, 2, 15)
            },
            school=self.school
        )
        self.assertEqual(len(unavailabilities), 4)  # Jan 25, Feb 1, Feb 8, Feb 15
        for i, unavailability in enumerate(unavailabilities):
            self.assertEqual(unavailability.date, date(2025, 1, 25) + timedelta(weeks=i))
            self.assertEqual(unavailability.start_time, time(14, 0))
            self.assertEqual(unavailability.end_time, time(16, 0))

    def test_single_unavailability_for_student(self):
        """
        Test creating a single unavailability for a student.
        """
        unavailabilities = Unavailability.define_unavailability(
            student=self.student,
            date=date(2025, 2, 1),
            start_time=time(9, 0),
            end_time=time(11, 0),
            school=self.school
        )
        self.assertEqual(len(unavailabilities), 1)
        unavailability = unavailabilities[0]
        self.assertEqual(unavailability.student, self.student)
        self.assertEqual(unavailability.date, date(2025, 2, 1))
        self.assertEqual(unavailability.start_time, time(9, 0))
        self.assertEqual(unavailability.end_time, time(11, 0))

    def test_invalid_input_missing_date(self):
        """
        Test that an error is raised when date is missing.
        """
        with self.assertRaises(ValueError):
            Unavailability.define_unavailability(
                instructor=self.instructor,
                start_time=time(10, 0),
                end_time=time(12, 0),
                school=self.school
            )

    def test_invalid_input_missing_time(self):
        """
        Test that an error is raised when start_time and end_time are missing.
        """
        with self.assertRaises(ValueError):
            Unavailability.define_unavailability(
                instructor=self.instructor,
                date=date(2025, 1, 25),
                school=self.school
            )


class DefineAvailabilityTests(TestCase):

    def setUp(self):
        self.school = School.objects.create(name="Test School")
        self.instructor = Instructor.objects.create(user=UserAccount.objects.create(username="instructor"))
        self.user_student = UserAccount.objects.create(username="test_student")
        self.student = Student.objects.create(user=self.user_student, level=1, birthday=date(2000, 1, 1))

    def test_define_availability_no_overlap(self):
        """Test defining availability with no overlapping unavailabilities."""
        date_today = date(2025, 1, 24)
        start_time = time(10, 0)
        end_time = time(12, 0)

        # No unavailabilities exist initially
        self.assertEqual(Unavailability.objects.count(), 0)

        # Define availability
        Unavailability.define_availability(
            instructor=self.instructor,
            date=date_today,
            start_time=start_time,
            end_time=end_time,
            school=self.school
        )

        # Ensure no unavailabilities overlap
        self.assertEqual(Unavailability.objects.count(), 0)

    def test_define_availability_partial_overlap(self):
        """Test defining availability with partially overlapping unavailabilities."""
        date_today = date(2025, 1, 24)
        
        # Create overlapping unavailability
        Unavailability.objects.create(
            instructor=self.instructor,
            date=date_today,
            start_time=time(9, 0),
            end_time=time(11, 0),
            duration_in_minutes=120,
            school=self.school
        )

        Unavailability.objects.create(
            instructor=self.instructor,
            date=date_today,
            start_time=time(11, 0),
            end_time=time(13, 0),
            duration_in_minutes=120,
            school=self.school
        )

        # Define availability
        Unavailability.define_availability(
            instructor=self.instructor,
            date=date_today,
            start_time=time(10, 0),
            end_time=time(12, 0),
            school=self.school
        )

        # Verify the adjusted unavailabilities
        unavailabilities = Unavailability.objects.filter(instructor=self.instructor, date=date_today)
        self.assertEqual(unavailabilities.count(), 2)

        # Check adjustments
        unavailability_1 = unavailabilities.get(start_time=time(9, 0))
        self.assertEqual(unavailability_1.end_time, time(10, 0))

        unavailability_2 = unavailabilities.get(start_time=time(12, 0))
        self.assertEqual(unavailability_2.end_time, time(13, 0))

    def test_define_availability_full_overlap(self):
        """Test defining availability that fully overlaps existing unavailabilities."""
        date_today = date(2025, 1, 24)

        # Create overlapping unavailability
        Unavailability.objects.create(
            instructor=self.instructor,
            date=date_today,
            start_time=time(9, 0),
            end_time=time(13, 0),
            duration_in_minutes=240,
            school=self.school
        )

        # Define availability
        Unavailability.define_availability(
            instructor=self.instructor,
            date=date_today,
            start_time=time(10, 0),
            end_time=time(12, 0),
            school=self.school
        )

        # Verify the adjusted unavailabilities
        unavailabilities = Unavailability.objects.filter(instructor=self.instructor, date=date_today)
        self.assertEqual(unavailabilities.count(), 2)

        # Check adjustments
        unavailability_1 = unavailabilities.get(end_time=time(10, 0))
        self.assertEqual(unavailability_1.start_time, time(9, 0))

        unavailability_2 = unavailabilities.get(start_time=time(12, 0))
        self.assertEqual(unavailability_2.end_time, time(13, 0))

    def test_define_availability_with_recurrence(self):
        """Test defining recurring availability."""
        date_today = date(2025, 1, 24)

        # Create recurring unavailability
        recurrence = {
            'type': 'daily',
            'frequency': 1,
            'end_date': date_today + timedelta(days=2)
        }

        for i in range(3):
            Unavailability.objects.create(
                instructor=self.instructor,
                date=date_today + timedelta(days=i),
                start_time=time(9, 0),
                end_time=time(13, 0),
                duration_in_minutes=240,
                school=self.school
            )

        # Define availability
        Unavailability.define_availability(
            instructor=self.instructor,
            date=date_today,
            start_time=time(10, 0),
            end_time=time(12, 0),
            school=self.school,
            recurrence=recurrence
        )

        # Verify the adjusted unavailabilities across recurrence dates
        for i in range(3):
            current_date = date_today + timedelta(days=i)
            unavailabilities = Unavailability.objects.filter(instructor=self.instructor, date=current_date)
            self.assertEqual(unavailabilities.count(), 2)

            unavailability_1 = unavailabilities.get(end_time=time(10, 0))
            self.assertEqual(unavailability_1.start_time, time(9, 0))

            unavailability_2 = unavailabilities.get(start_time=time(12, 0))
            self.assertEqual(unavailability_2.end_time, time(13, 0))

        # Ensure no additional unavailabilities are created
        self.assertEqual(Unavailability.objects.count(), 6)

    def test_define_availability_no_unavailabilities(self):
        """Test defining availability when no unavailabilities exist."""
        date_today = date(2025, 1, 24)
        start_time = time(10, 0)
        end_time = time(12, 0)

        # Ensure no unavailabilities exist
        self.assertEqual(Unavailability.objects.filter(instructor=self.instructor).count(), 0)

        # Define availability
        Unavailability.define_availability(
            instructor=self.instructor,
            date=date_today,
            start_time=start_time,
            end_time=end_time,
            school=self.school
        )

        # Ensure no unavailabilities remain
        self.assertEqual(Unavailability.objects.filter(instructor=self.instructor).count(), 0)
