from django.test import TestCase
from lessons.models import Lesson, Pack, Unavailability
from schools.models import School, default_payment_types
from datetime import datetime, timedelta, date, time
from django.utils.timezone import now
from users.models import Student, UserAccount, Instructor
from decimal import Decimal
import copy
import re

# -------------------- PaymentTypeUpdateTests --------------------

class PaymentTypeUpdateTests(TestCase):
    def setUp(self):
        # Create a school and an instructor user.
        self.school = School.objects.create(name="Test School", currency="EUR")
        self.user = UserAccount.objects.create(username="instructor", first_name="John", last_name="Doe")
        self.instructor = Instructor.objects.create(user=self.user)
        # Add the instructor to the school so that user's payment_types is initialized.
        self.school.add_instructor(self.instructor)
    
    def test_update_simple_field(self):
        # Update a simple field like commission.
        # Key path: "instructor[private lesson][commission]"
        self.school.update_payment_type_value("instructor[private lesson][commission]", 12, user_obj=self.user)
        self.user.refresh_from_db()
        commission = self.user.payment_types[self.school.name]["instructor"]["private lesson"]["commission"]
        self.assertEqual(commission, 12)
    
    def test_update_fixed_existing_rule(self):
        # Assume the default fixed pricing list contains a rule for duration=60, min_students=1, max_students=4.
        # Update that rule's price to 10.00.
        new_rule = {"duration": 60, "min_students": 1, "max_students": 4, "price": 10.00}
        self.school.update_payment_type_value("instructor[private lesson][fixed]", new_rule, user_obj=self.user)
        self.user.refresh_from_db()
        fixed_list = self.user.payment_types[self.school.name]["instructor"]["private lesson"]["fixed"]
        # Find the rule.
        rule = next((r for r in fixed_list 
                     if r["duration"] == 60 and r["min_students"] == 1 and r["max_students"] == 4), None)
        self.assertIsNotNone(rule)
        self.assertEqual(rule["price"], 10.00)
    
    def test_update_fixed_append_new_rule(self):
        # Use a rule that does not exist in the fixed list.
        new_rule = {"duration": 45, "min_students": 2, "max_students": 3, "price": 8.50}
        self.school.update_payment_type_value("instructor[private lesson][fixed]", new_rule, user_obj=self.user)
        self.user.refresh_from_db()
        fixed_list = self.user.payment_types[self.school.name]["instructor"]["private lesson"]["fixed"]
        rule = next((r for r in fixed_list 
                     if r["duration"] == 45 and r["min_students"] == 2 and r["max_students"] == 3), None)
        self.assertIsNotNone(rule)
        self.assertEqual(rule["price"], 8.50)
    
    def test_update_without_user_obj(self):
        # Update the school default payment_types.
        self.school.update_payment_type_value("instructor[private lesson][commission]", 7)
        self.school.refresh_from_db()
        commission = self.school.payment_types["instructor"]["private lesson"]["commission"]
        self.assertEqual(commission, 7)

# -------------------- PrivateClassMarkingTests --------------------

class PrivateClassMarkingTests(TestCase):
    def setUp(self):
        # Create a school, instructor user, and student.
        self.school = School.objects.create(name="Test School", currency="EUR")
        self.user = UserAccount.objects.create(username="instructor", first_name="John", last_name="Doe")
        self.instructor = Instructor.objects.create(user=self.user)
        self.school.add_instructor(self.instructor)
        # Update fixed pricing for 60-minute lesson with 1-4 students to 15.00.
        self.school.update_payment_type_value(
            "instructor[private lesson][fixed]",
            {"duration": 60, "min_students": 1, "max_students": 4, "price": 15.00},
            user_obj=self.user
        )
        # Set commission to 10%
        self.school.update_payment_type_value("instructor[private lesson][commission]", 10, user_obj=self.user)
        # Create a student.
        self.student = Student.objects.create(level=1, first_name="Alice", last_name="Smith", birthday=date(2010,1,1))
    
    def test_get_fixed_price(self):
        # Create a PrivateClass with a 60-minute duration and 1 student.
        private_class = Lesson.objects.create(
            date=date(2025, 1, 1),
            start_time=time(10, 0),
            end_time=time(11, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            school=self.school,
            type="private"
        )
        private_class.students.add(self.student)
        private_class.instructors.add(self.instructor)
        fixed_price = private_class.get_fixed_price(instructor=self.instructor)
        self.assertEqual(fixed_price, 15.00)
    
    def test_mark_as_given_updates_balance_and_history(self):
        # Initialize user balance and history.
        self.user.balance = Decimal("0.00")
        self.user.balance_history = []
        self.user.save(update_fields=["balance", "balance_history"])
        
        private_class = Lesson.objects.create(
            date=date(2025, 1, 1),
            start_time=time(10, 0),
            end_time=time(11, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            school=self.school,
            type="private"
        )
        private_class.students.add(self.student)
        private_class.instructors.add(self.instructor)
        # Commission is 10% so commission fee = 50 * 0.10 = 5.00.
        # Total amount to add = fixed price (15.00) + commission fee (5.00) = 20.00.
        result = private_class.mark_as_given()
        self.assertTrue(result)
        self.user.refresh_from_db()
        self.assertEqual(self.user.balance, Decimal("20.00"))
        # Verify that a transaction was recorded.
        self.assertGreaterEqual(len(self.user.balance_history), 1)
        last_tx = self.user.balance_history[-1]
        self.assertEqual(last_tx["amount"], "+20.00")
        # Calling mark_as_given again should return False.
        self.assertFalse(private_class.mark_as_given())
    
    def test_mark_as_not_given_reverses_balance(self):
        # Initialize balance and history.
        self.user.balance = Decimal("0.00")
        self.user.balance_history = []
        self.user.save(update_fields=["balance", "balance_history"])
        
        private_class = Lesson.objects.create(
            date=date(2025, 1, 1),
            start_time=time(10, 0),
            end_time=time(11, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            school=self.school,
            type="private"
        )
        private_class.students.add(self.student)
        private_class.instructors.add(self.instructor)
        # First mark as given (+20.00), then reverse it.
        private_class.mark_as_given()
        result = private_class.mark_as_not_given()
        self.assertTrue(result)
        self.user.refresh_from_db()
        self.assertEqual(self.user.balance, Decimal("0.00"))
        transactions = self.user.balance_history
        # Expect at least two transactions: one for mark_as_given and one for reversal.
        self.assertGreaterEqual(len(transactions), 2)
        self.assertEqual(transactions[-1]["amount"], "-20.00")

# -------------------- BalanceHistoryTests --------------------

class BalanceHistoryTests(TestCase):
    def setUp(self):
        self.user = UserAccount.objects.create(username="testuser", first_name="Test", last_name="User")
        self.user.balance = Decimal("0.00")
        self.user.balance_history = []
        self.user.save(update_fields=["balance", "balance_history"])
    
    def test_multiple_transactions_recorded(self):
        # Perform multiple balance updates.
        self.user.update_balance(50.00, "Initial deposit")
        self.user.update_balance(-20.00, "Withdrawal")
        self.user.update_balance(30.00, "Another deposit")
        self.user.refresh_from_db()
        self.assertEqual(self.user.balance, Decimal("60.00"))
        self.assertEqual(len(self.user.balance_history), 3)
        # Check that amounts are correctly formatted.
        self.assertEqual(self.user.balance_history[0]["amount"], "+50.00")
        self.assertEqual(self.user.balance_history[1]["amount"], "-20.00")
        self.assertEqual(self.user.balance_history[2]["amount"], "+30.00")

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
        pack = Pack.book_new_pack(
            students=[self.student],
            school=self.school,
            date=date_of_pack,
            number_of_classes=number_of_classes,
            duration_in_minutes=duration_in_minutes,
            instructors=[self.instructor],
            price=price,
            payment=payment,
            type="private"
        )
        # Verify the pack creation
        self.assertIsNotNone(pack)
        private_lesson1 = pack.lessons.all()[0]
        private_lesson2 = pack.lessons.all()[1]
        private_lesson3 = pack.lessons.all()[2]
        private_lesson4 = pack.lessons.all()[3]
        self.assertIsNotNone(private_lesson1)
        self.assertIsNotNone(private_lesson2)
        self.assertIsNotNone(private_lesson3)
        self.assertIsNotNone(private_lesson4)
        self.assertTrue(private_lesson1.schedule_lesson(date(2025,1,1), time(10,00)))
        self.assertTrue(private_lesson2.schedule_lesson(date(2025,1,1), time(11,00)))
        self.assertFalse(private_lesson3.schedule_lesson(date(2025,1,1), time(10,00)))
        self.assertFalse(private_lesson4.schedule_lesson(date(2025,1,1), time(11,00)))

        lessons = self.student.get_all_booked_lessons()

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
        self.private_class = Lesson.objects.create(
            date=date(2025, 1, 2),
            start_time=time(15, 0),
            end_time=time(16, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            school=self.school,
            type="private"
        )
        # Create and assign a student to the private class
        student = Student.objects.create(
            level=1,
            birthday=date(2001, 1, 1),
            first_name="Alice",
            last_name="Silva"
        )
        self.private_class.instructors.set([self.instructor])
        self.private_class.students.set([student])

    def test_view_available_lesson_times(self):
        # Ensure the instructor is added to the school (which also initializes payment_types)
        self.assertTrue(self.school.add_instructor(self.instructor))
        times_list = self.instructor.view_available_lesson_times(
            date(2025, 1, 2), 60, 60, self.school
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
