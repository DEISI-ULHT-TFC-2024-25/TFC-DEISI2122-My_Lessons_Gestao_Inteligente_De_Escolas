from datetime import datetime, timedelta, date, time
from decimal import Decimal
from django.contrib.auth.models import AbstractUser,  Group, Permission
from django.db import models
from .utils import get_phone
from django.utils import timezone

from notifications.models import Notification

class UserAccount(AbstractUser):
    country_code = models.CharField(max_length=5, blank=True, null=True)
    phone = models.BigIntegerField(blank=True, null=True)
    birthday = models.DateField(blank=True, null=True)
    photo = models.ImageField(upload_to='user_photos/', blank=True, null=True)
    groups = models.ManyToManyField(
        Group,
        related_name='useraccount_set',
        blank=True,
        help_text='The groups this user belongs to.',
        verbose_name='groups',
    )
    user_permissions = models.ManyToManyField(
        Permission,
        related_name='useraccount_set',
        blank=True,
        help_text='Specific permissions for this user.',
        verbose_name='user permissions',
    )
    current_role = models.CharField(max_length=255, default="Parent")
    current_school_id = models.PositiveIntegerField(null=True, blank=True)
    balance = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    balance_history = models.JSONField(null=True, blank=True, default=list)
    payment_types = models.JSONField(blank=True, null=True, default=dict) 
    
    def __str__(self):
        return f"{self.first_name} {self.last_name}"
    
    def update_balance(self, amount, message):
        """
        Update the user's balance and record the transaction.

        The balance_history JSON structure is now a list of transactions.
        Each transaction is represented as:
            {
                "timestamp": "YYYY-MM-DDTHH:MM:SS",
                "amount": "+50.00" or "-20.00",
                "message": "Description of transaction"
                "current_balance": "current balance at this time after the new transaction"
            }
        """
        # Ensure amount is a Decimal for arithmetic
        amount = Decimal(amount)
        self.balance += amount

        # Get the current timestamp
        now = timezone.now()

        # Create a new transaction entry
        transaction_entry = {
            "timestamp": now.isoformat(),  # e.g., "2025-02-18T14:00:00"
            "amount": f"{amount:+.2f}",      # formats as '+50.00' or '-20.00'
            "message": message,
            "current_balance" : f"{self.balance:+.2f}"
        }

        # Initialize balance_history as a list if it's empty
        if not self.balance_history:
            self.balance_history = []

        # Append the new transaction entry
        self.balance_history.append(transaction_entry)
        
        # Save changes to the instance
        self.save(update_fields=["balance", "balance_history"])


class Student(models.Model):
    id = models.AutoField(primary_key=True)
    user = models.OneToOneField(UserAccount, on_delete=models.CASCADE, related_name='student_profile', null=True, blank=True)
    first_name = models.CharField(max_length=255)
    last_name = models.CharField(max_length=255)
    birthday = models.DateField()
    level = models.PositiveIntegerField(null=None, blank=None)
    parents = models.ManyToManyField(UserAccount, related_name='students')

    def __str__(self):
        return f"{self.first_name} {self.last_name}"
    
    def get_all_booked_lessons(self):
        return list(self.lessons.exclude(date=None, start_time=None))
    
    
class Instructor(models.Model):
    id = models.AutoField(primary_key=True)
    user = models.OneToOneField(UserAccount, on_delete=models.CASCADE, related_name='instructor_profile')

    def __str__(self):
        return f"{self.user.first_name} {self.user.last_name}"
    
    
    def get_phone(self):
        return get_phone(self.user)
    
    def view_available_lesson_times(self, date, duration, increment, school):
        # Define the working hours (adjust as needed for the school or instructor)
        start_time = time(9, 0)  # Start of the day
        end_time = time(18, 0)  # End of the day
        # TODO 
        # Get all conflicting schedules for the instructor on the given date
        conflicting_times = []

        # Unavailabilities
        conflicting_times.extend(
            [(u.start_time, u.end_time) for u in self.unavailabilities.filter(date=date)]
        )

        # Private Classes
        conflicting_times.extend(
            [(pc.start_time, pc.end_time) for pc in self.lessons.filter(date=date)]
        )

        # Activities
        conflicting_times.extend(
            [(a.start_time, a.end_time) for a in self.activities.filter(date=date, school=school)]
        )

        # Sort and merge overlapping/conflicting times
        conflicting_times = sorted(conflicting_times)
        merged_times = []
        for start, end in conflicting_times:
            if not merged_times or merged_times[-1][1] < start:
                merged_times.append((start, end))
            else:
                merged_times[-1] = (merged_times[-1][0], max(merged_times[-1][1], end))

        # Generate available time slots
        available_times = []
        current_time = start_time

        for start, end in merged_times:
            while current_time < start:
                next_time = (datetime.combine(date, current_time) + timedelta(minutes=increment)).time()
                if next_time <= start and (datetime.combine(date, next_time) - datetime.combine(date, current_time)).seconds // 60 >= duration:
                    available_times.append(current_time)
                current_time = next_time
            current_time = max(current_time, end)

        # Check times after the last conflict until the end of the day
        while current_time < end_time:
            next_time = (datetime.combine(date, current_time) + timedelta(minutes=increment)).time()
            if next_time <= end_time and (datetime.combine(date, next_time) - datetime.combine(date, current_time)).seconds // 60 >= duration:
                available_times.append(current_time)
            current_time = next_time

        return available_times
    
class Monitor(models.Model):
    id = models.AutoField(primary_key=True)
    user = models.OneToOneField(UserAccount, on_delete=models.CASCADE, related_name='monitor_profile')

    def __str__(self):
        return f"Monitor: {self.user.first_name} {self.user.last_name}"
    
    
class Unavailability(models.Model):
    id = models.AutoField(primary_key=True)
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='unavailabilities', null=True, blank=True)
    instructor = models.ForeignKey(Instructor, on_delete=models.CASCADE, related_name='unavailabilities', null=True, blank=True)
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField(null=True, blank = True)
    duration_in_minutes = models.PositiveIntegerField()
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='unavailabilities', null=True, blank=True)

    def __str__(self):
        details = []
        if self.student:
            details.append(f"Student: {self.student}")
        if self.instructor:
            details.append(f"Instructor: {self.instructor}")
        return f"Unavailability on {self.date} from {self.start_time} to {self.end_time} ({', '.join(details)})"
    
    @classmethod
    def define_availability(cls, instructor=None, student=None, date=None, start_time=None, end_time=None, recurrence=None, school=None):
        """
        Defines availability for an instructor or student by handling overlapping unavailabilities.
        """
        if not date or not (start_time or end_time):
            raise ValueError("Date and time range must be provided.")

        current_date = date
        while True:
            # Filter overlapping unavailabilities
            overlapping_unavailabilities = cls.objects.filter(
                date=current_date,
                instructor=instructor if instructor else None,
                student=student if student else None,
                school=school
            ).filter(
                start_time__lt=end_time,
                end_time__gt=start_time
            )

            for unavailability in overlapping_unavailabilities:
                # Case 1: Fully contained within the new availability range
                if unavailability.start_time >= start_time and unavailability.end_time <= end_time:
                    unavailability.delete()

                # Case 2: Overlaps on the left side
                elif unavailability.start_time < start_time < unavailability.end_time and unavailability.end_time < end_time:
                    unavailability.end_time = start_time
                    unavailability.duration_in_minutes = int(
                        (datetime.combine(unavailability.date, unavailability.end_time) - datetime.combine(unavailability.date, unavailability.start_time)).total_seconds() / 60
                    )
                    unavailability.save()

                # Case 3: Overlaps on the right side
                elif unavailability.start_time < end_time < unavailability.end_time and unavailability.start_time > start_time:
                    unavailability.start_time = end_time
                    unavailability.duration_in_minutes = int(
                        (datetime.combine(unavailability.date, unavailability.end_time) - datetime.combine(unavailability.date, unavailability.start_time)).total_seconds() / 60
                    )
                    unavailability.save()

                # Case 4: Fully encompasses the new availability range
                elif unavailability.start_time < start_time and unavailability.end_time > end_time:
                    # Create a new unavailability for the portion after `end_time`
                    cls.objects.create(
                        instructor=instructor,
                        student=student,
                        date=current_date,
                        start_time=end_time,
                        end_time=unavailability.end_time,
                        duration_in_minutes=int(
                            (datetime.combine(unavailability.date, unavailability.end_time) - datetime.combine(unavailability.date, end_time)).total_seconds() / 60
                        ),
                        school=school
                    )
                    
                    # Update the current unavailability to end at `start_time`
                    unavailability.end_time = start_time
                    unavailability.duration_in_minutes = int(
                        (datetime.combine(unavailability.date, unavailability.end_time) - datetime.combine(unavailability.date, unavailability.start_time)).total_seconds() / 60
                    )
                    unavailability.save()

            if recurrence:
                if recurrence['type'] == 'daily':
                    current_date += timedelta(days=recurrence['frequency'])
                elif recurrence['type'] == 'weekly':
                    current_date += timedelta(weeks=recurrence['frequency'])
                if current_date > recurrence['end_date']:
                    break
            else:
                break

        return f"Availability defined successfully for {start_time} to {end_time} on {date}."


    @classmethod
    def define_unavailability(cls, instructor=None, student=None, date=None, start_time=None, end_time=None, recurrence=None, school=None):
        """
        Defines unavailability for an instructor or student and notifies relevant parties.
        """
        if not date or not (start_time or end_time):
            raise ValueError("Date and time range must be provided.")

        unavailabilities = []
        current_date = date
        duration = int((datetime.combine(date, end_time) - datetime.combine(date, start_time)).total_seconds() / 60)

        while True:
            conflicts = []

            if instructor:
                # Check for conflicts with related classes and activities via instructor
                conflicts += list(instructor.lessons.filter(
                    date=current_date,
                    start_time__lt=end_time,
                    end_time__gt=start_time
                ))
                conflicts += list(instructor.activities.filter(
                    date=current_date,
                    start_time__lt=end_time,
                    end_time__gt=start_time
                ))

                # Create the unavailability
                unavailabilities.append(
                    cls.objects.create(
                        instructor=instructor,
                        date=current_date,
                        start_time=start_time,
                        end_time=end_time,
                        duration_in_minutes=duration,
                        school=school
                    )
                )

            if student:
                # Check for conflicts via students
                for parent in student.parents.all():
                    conflicts += list(student.lessons.filter(
                        date=current_date,
                        start_time__lt=end_time,
                        end_time__gt=start_time
                    ))

                # Create the unavailability
                unavailabilities.append(
                    cls.objects.create(
                        student=student,
                        date=current_date,
                        start_time=start_time,
                        end_time=end_time,
                        duration_in_minutes=duration,
                        school=school
                    )
                )

            # TODO admin notifications?

            # Notify relevant parties
            if conflicts:
                notified_parents = set()
                notified_instructors = set()
                for conflict in conflicts:
                    # Notify instructor
                    for instructor in conflict.instructors.all():
                        if instructor.id not in notified_instructors:
                            Notification.create_notification(
                                user=instructor.user,
                                subject=school.get_notification_template("conflict_notification_subject").format(
                                    conflict_type=conflict.__class__.__name__
                                ),
                                message=school.get_notification_template("conflict_notification_message_instructor").format(
                                    instructor_name=instructor.user.first_name,
                                    conflict_type=conflict.__class__.__name__,
                                    date=conflict.date,
                                    start_time=conflict.start_time,
                                    end_time=conflict.end_time,
                                    school_name=school.name
                                ),
                                school=school
                            )
                            notified_instructors.add(instructor.id)

                    # Notify parents, avoiding duplicates
                    if hasattr(conflict, 'students'):
                        for student in conflict.students.all():
                            for parent in student.parents.all():
                                if parent.id not in notified_parents:
                                    Notification.create_notification(
                                        user=parent,
                                        subject=school.get_notification_template("conflict_notification_subject").format(
                                            conflict_type=conflict.__class__.__name__
                                        ),
                                        message=school.get_notification_template("conflict_notification_message_parent").format(
                                            parent_name=parent.first_name,
                                            conflict_type=conflict.__class__.__name__,
                                            date=conflict.date,
                                            start_time=conflict.start_time,
                                            end_time=conflict.end_time,
                                            school_name=school.name
                                        ),
                                        school=school
                                    )
                                    notified_parents.add(parent.id)

            # Handle recurrence
            if recurrence:
                if recurrence['type'] == 'daily':
                    current_date += timedelta(days=recurrence['frequency'])
                elif recurrence['type'] == 'weekly':
                    current_date += timedelta(weeks=recurrence['frequency'])
                if current_date > recurrence['end_date']:
                    break
            else:
                break

        return unavailabilities



        
class Discount(models.Model):
    discount_percentage = models.PositiveIntegerField(null=True, blank=True, help_text="Percentage discount (e.g., 10 for 10%)")
    discount_value = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True, help_text="Fixed discount value (e.g., €10.00)")
    date = models.DateField(auto_now_add=True, help_text="Date when the discount was created")
    expiration_date = models.DateField(help_text="Date when the discount expires")
    user = models.ForeignKey(UserAccount, on_delete=models.CASCADE, related_name="discounts", help_text="User associated with the discount")
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='discounts', null=True, blank=True)

    def __str__(self):
        if self.discount_percentage:
            return f"{self.discount_percentage}% discount for {self.user.username}"
        elif self.discount_value:
            return f"€{self.discount_value} discount for {self.user.username}"
        else:
            return f"Discount for {self.user.username}"
        
    def update_price(self, price):
        if self.discount_percentage:
            price = price - (price/self.discount_percentage)
        elif self.discount_value:
            price = price - self.discount_value
        return price

    def is_expired(self):
        """Check if the discount is expired."""
        from django.utils.timezone import now
        return now().date() > self.expiration_date

    def clean(self):
        """Ensure at least one discount type is specified."""
        if not (self.discount_percentage or self.discount_value):
            from django.core.exceptions import ValidationError
            raise ValidationError("You must specify either a discount percentage or a discount value.")
        if self.discount_percentage and self.discount_value:
            raise ValidationError("You cannot specify both a discount percentage and a discount value.")
        
class GoogleCredential(models.Model):
    user = models.OneToOneField(
        UserAccount,
        on_delete=models.CASCADE,
        related_name="google_credential",
        help_text="The user associated with these Google credentials"
    )
    credentials = models.TextField(help_text="Serialized Google API credentials")

    def __str__(self):
        return f"Google Credential for {self.user.username}"

    def is_valid(self):
        """Check if the credentials are valid."""
        # Implement logic here to validate the credentials using Google's API client library if needed.
        pass