import random
import re
import copy
from django.db import models
from django.apps import apps

def default_payment_types():
    """
    Returns a default payment types structure.
    The top-level keys represent roles directly.
    """
    fixed_default = round(random.uniform(10, 20), 2)
    commission_default = random.choice([0, 5, 10])
    return {
        "instructor": {
            "fixed monthly rate": None,
            "private lesson": {
                "commission": commission_default,
                "fixed": {
                    "90-1-2": fixed_default,
                    "60-1-1": fixed_default,
                    "60-0-0": fixed_default,
                    "0-0-0": fixed_default,
                }
            }
        },
        "admin": {
            "fixed monthly rate": None,
            "private lesson": {
                "commission": commission_default,
                "fixed": {
                    "90-1-2": fixed_default,
                    "60-1-1": fixed_default,
                    "60-0-0": fixed_default,
                    "0-0-0": fixed_default,
                }
            }
        },
        "monitor": {
            "fixed monthly rate": None,
            "private lesson": {
                "commission": commission_default,
                "fixed": {
                    "90-1-2": fixed_default,
                    "60-1-1": fixed_default,
                    "60-0-0": fixed_default,
                    "0-0-0": fixed_default,
                }
            }
        }
    }
    

def default_alerts():
    return {
        "days_until_expiration" : [15, 5], 
    }

def default_extra_prices():
    return {
        "extra_students": 10,
        "skateboards": 4,
        "helmets" : 2,
        "kneepads" : 2,
        "elbowpads" : 2,
        "wristpads" : 2,
    }

def default_group_lessons_pack_prices():
    return {
        "60m": {
            "1": 25,
            "4": 70,
        }
    }

def default_private_lessons_pack_prices():
    return {
        "30m": {
            "1p": {"1c": 20, "4c": 55},
            "2p": {},
            "3p": {},
            "4p": {},
        },
        "60m": {
            "1p": {"1c": 30, "4c": 90, "8c": 165},
            "2p": {"1c": 40, "4c": 130, "8c": 235},
            "3p": {"1c": 55, "4c": 175, "8c": 310},
            "4p": {"1c": 65, "4c": 210, "8c": 375},
        },
        "90m": {
            "1p": {"1c": 40, "4c": 140, "8c": 235},
            "2p": {"1c": 55, "4c": 190, "8c": 330},
            "3p": {"1c": 65, "4c": 230, "8c": 420},
            "4p": {"1c": 75, "4c": 260, "8c": 470},
        }
    }

def default_notification_templates():
    return {
            "group_pack_purchased_subject_parent": "Group Pack Purchased for {student}",
            "group_pack_purchased_message_parent": (
                "Dear {parent_name},\n\n"
                "A new group pack has been purchased for {student}.\n\n"
                "Pack Details:\n"
                "- Number of Classes: {number_of_classes}\n"
                "- Duration per Class: {duration_minutes} minutes\n"
                "- Start Date: {start_date}\n\n"
                "- Total Price: {total_price}{currency}\n\n"
                "Thank you for choosing {school_name}."
            ),
            "group_pack_purchased_subject_admin": "New Group Pack Booked",
            "group_pack_purchased_message_admin": (
                "Dear Admin,\n\n"
                "A new group pack has been booked for {student}.\n\n"
                "Pack Details:\n"
                "- Number of Classes: {number_of_classes}\n"
                "- Duration per Class: {duration_minutes} minutes\n"
                "- Start Date: {start_date}\n\n"
                "- Total Price: {total_price}{currency}\n\n"
                "Please review the booking details."
            ),
            "private_pack_purchased_subject_parent": "Private Pack Purchased for {students}",
            "private_pack_purchased_message_parent": (
                "Dear {parent_name},\n\n"
                "A new private pack has been purchased for {students}.\n\n"
                "Pack Details:\n"
                "- Number of Classes: {number_of_classes}\n"
                "- Duration per Class: {duration_minutes} minutes\n"
                "- Instructor: {instructor_name}\n"
                "- Start Date: {start_date}\n\n"
                "- Total Price: {total_price}{currency}\n\n"
                "Thank you for choosing {school_name}."
            ),
            "private_pack_purchased_subject_instructor": "New Private Pack Assigned",
            "private_pack_purchased_message_instructor": (
                "Dear {instructor_name},\n\n"
                "You have been assigned to a new private pack for {students}.\n\n"
                "Pack Details:\n"
                "- Number of Classes: {number_of_classes}\n"
                "- Duration per Class: {duration_minutes} minutes\n"
                "- Instructor: {instructor_name}\n"
                "- Start Date: {start_date}\n\n"
                "Please check your schedule for more details."
            ),
            "private_pack_purchased_subject_admin": "New Private Pack Booked",
            "private_pack_purchased_message_admin": (
                "Dear Admin,\n\n"
                "A new private pack has been booked for {students}.\n\n"
                "Pack Details:\n"
                "- Number of Classes: {number_of_classes}\n"
                "- Duration per Class: {duration_minutes} minutes\n"
                "- Instructor: {instructor_name}\n"
                "- Start Date: {start_date}\n\n"
                "- Total Price: {total_price}{currency}\n\n"
                "Please review the booking details."
            ),
            "private_class_scheduled_subject_parent": "Private Class Scheduled for {students}",
            "private_class_scheduled_message_parent": (
                "Dear {parent_name},\n\n"
                "The private class number {class_number} of {number_of_classes} has been scheduled for {students}.\n\n"
                "Class Details:\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- Duration: {duration_in_minutes} minutes\n"
                "- Instructor: {instructor_name}"
            ),
            "private_class_scheduled_subject_instructor": "Private Class Scheduled for {students}",
            "private_class_scheduled_message_instructor": (
                "Dear {instructor_name},\n\n"
                "The private class number {class_number} of {number_of_classes} has been scheduled for {students}.\n\n"
                "Class Details:\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- Duration: {duration_in_minutes} minutes"
            ),
            "private_class_scheduled_subject_admin": "Private Class Scheduled for {students}",
            "private_class_scheduled_message_admin": (
                "Dear Admin,\n\n"
                "The private class number {class_number} of {number_of_classes} has been scheduled for {students}.\n\n"
                "Class Details:\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- Duration: {duration_in_minutes} minutes"
            ),
            # New conflict-related notification templates
            "conflict_notification_subject": "Scheduling Conflict Detected: {conflict_type}",
            "conflict_notification_message_instructor": (
                "Dear {instructor_name},\n\n"
                "A scheduling conflict was detected for the following:\n\n"
                "Conflict Details:\n"
                "- Type: {conflict_type}\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- End Time: {end_time}\n\n"
                "Please address this issue promptly.\n\n"
                "Thank you,\n{school_name}"
            ),
            "conflict_notification_message_parent": (
                "Dear {parent_name},\n\n"
                "A scheduling conflict was detected for your child's class/activity.\n\n"
                "Conflict Details:\n"
                "- Type: {conflict_type}\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- End Time: {end_time}\n\n"
                "Please contact us for more details.\n\n"
                "Thank you,\n{school_name}"
            ),
            "expiration_alert_subject_parent" : "Theres a pack expiring in {days_until_expiration}",
            "expiration_alert_message_parent" : (
                "Dear {parent_name},\n\n"
                "{students}'s {type} pack is expiring in {days_until_expiration}.\n\n"
                "Please contact us for more details.\n\n"
                "Thank you,\n{school_name}"
            ),
        }

class Review(models.Model):
    user = models.ForeignKey(
        'users.UserAccount',
        on_delete=models.CASCADE,
        related_name="reviews"
    )
    date = models.DateField(auto_now_add=True)
    rating = models.PositiveSmallIntegerField()  # 1-5 scale
    description = models.TextField(blank=True, null=True)
    is_verified = models.BooleanField(default=False)  # Verified indicates if it's an authenticated review.
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='reviews', null=True, blank=True)

    def __str__(self):
        return f"Review by {self.user} - {self.rating} stars"

    class Meta:
        ordering = ['-date']  # Newest reviews appear first

class School(models.Model):
    private_lessons_pack_prices = models.JSONField(default=default_private_lessons_pack_prices, blank=True)
    group_lessons_pack_prices = models.JSONField(default=default_group_lessons_pack_prices, blank=True)
    name = models.CharField(max_length=255)
    payment_types = models.JSONField(default=default_payment_types, blank=True, null=True)
    extra_prices = models.JSONField(blank=True, null=True)  # Example: {"extra_time": 10, "private_lesson": 50}
    logo = models.ImageField(upload_to="school_logos/")
    description = models.TextField(blank=True, null=True)
    sports = models.ManyToManyField('sports.Sport', related_name='schools', blank=True)
    instructors = models.ManyToManyField('users.Instructor', related_name='schools', blank=True)
    students = models.ManyToManyField('users.Student', related_name='schools', blank=True)
    parents = models.ManyToManyField('users.UserAccount', related_name='schools', blank=True)
    admins = models.ManyToManyField('users.UserAccount', related_name='school_admins', blank=True)
    monitors = models.ManyToManyField('users.Monitor', related_name='schools', blank=True)
    reschedule_time_limit = models.PositiveIntegerField(default=24)
    schedule_time_limit = models.PositiveIntegerField(default=24)
    currency = models.CharField(max_length=20, default='EUR')
    notification_templates = models.JSONField(
        default=default_notification_templates,
        help_text="Customizable templates for notifications.",
        blank=True
    )
    alerts = models.JSONField(blank=True, default=default_alerts)
    locations = models.ManyToManyField('locations.Location', related_name='schools', blank=True)
    attendance_by_date = models.JSONField(null=True, blank=True)

    def __str__(self):
        return self.name
    
    @staticmethod
    def _set_nested_value(data, keys, value):
        """
        Helper to navigate a nested dict using the list of keys and set the last key to value.
        Creates intermediate dictionaries if needed.
        """
        for key in keys[:-1]:
            if key not in data or not isinstance(data[key], dict):
                data[key] = {}
            data = data[key]
        data[keys[-1]] = value

    def update_payment_type_value(self, key_path, new_value, user_obj=None):
        """
        Updates a single nested field in the payment_types structure.
        
        Args:
            key_path (str): A string representing the nested path.
                For example: "instructor[private lesson][fixed][60-1-4]"
            new_value: The value to assign at that nested key.
            user_obj (optional): If provided, the function will update the user's
                payment_types for this school. Otherwise, the school's default payment_types
                are updated.
        """
        # Extract keys from a path like: instructor[private lesson][fixed][60-1-4]
        keys = re.findall(r'\w[\w\s-]*', key_path)
        
        if user_obj:
            # Ensure the user has a JSON field "payment_types".
            # The first-level keys are school names.
            if not user_obj.payment_types or not isinstance(user_obj.payment_types, dict):
                user_obj.payment_types = {}

            # If there is no entry for this school (or it's blank), copy the school's payment_types.
            if self.name not in user_obj.payment_types or not user_obj.payment_types[self.name]:
                user_obj.payment_types[self.name] = copy.deepcopy(self.payment_types) if self.payment_types else {}

            # Update the nested key within the user's payment_types for this school.
            School._set_nested_value(user_obj.payment_types[self.name], keys, new_value)
            user_obj.save(update_fields=['payment_types'])
        else:
            # Update the school's own payment_types.
            if not self.payment_types or not isinstance(self.payment_types, dict):
                self.payment_types = default_payment_types()
            School._set_nested_value(self.payment_types, keys, new_value)
            self.save(update_fields=['payment_types'])
    
    def get_unpaid_camp_orders(self):
        orders = []
        camp_orders = self.camp_orders.all()
        if camp_orders:
            for order in camp_orders:
                orders.append(order)
        return orders
    
    def get_unpaid_packs(self):
        packs = []
        private_packs = self.private_packs.all()
        group_packs = self.group_packs.all()

        if private_packs:
            for pack in private_packs:
                packs.append(pack)

        if group_packs:
            for pack in group_packs:
                packs.append(pack)

        return packs
    
    def update_pack_price(self, pack_type, duration, number_of_people=None, number_of_classes=None, price=None):
        """
        Updates or adds a price to the specified pack type (private or group).

        Args:
            pack_type (str): Either "private" or "group" to specify the type of pack.
            duration (str): Duration of the lesson (e.g., "30m", "60m", "90m").
            number_of_people (str): Number of people (e.g., "1p", "2p"), required for private packs.
            number_of_classes (str): Number of classes (e.g., "1c", "4c"), required for private packs.
            price (float): The price to set for the specified pack configuration.

        Returns:
            bool: True if the update was successful, False otherwise.
        """
        if pack_type not in ["private", "group"]:
            raise ValueError("pack_type must be either 'private' or 'group'")

        if not price:
            raise ValueError("A price must be specified")

        if pack_type == "private":
            if not number_of_people or not number_of_classes:
                raise ValueError("For private packs, number_of_people and number_of_classes must be specified")

            private_prices = self.private_lessons_pack_prices
            if duration not in private_prices:
                private_prices[duration] = {}

            if number_of_people not in private_prices[duration]:
                private_prices[duration][number_of_people] = {}

            private_prices[duration][number_of_people][number_of_classes] = price
            self.private_lessons_pack_prices = private_prices

        elif pack_type == "group":
            group_prices = self.group_lessons_pack_prices
            if duration not in group_prices:
                group_prices[duration] = {}
            group_prices[duration][number_of_classes] = price
            self.group_lessons_pack_prices = group_prices

        self.save()
        return True
    
    def delete_pack_option(self, pack_type, duration=None, number_of_people=None, number_of_classes=None):
        """
        Deletes a specific pricing option for private or group lessons and removes empty dictionaries.
        """
        if pack_type not in ["private", "group"]:
            raise ValueError("Invalid lesson type. Use 'private' or 'group'.")

        if pack_type == "private":
            if not duration or not number_of_people or not number_of_classes:
                raise ValueError("Duration, number of people, and number of classes must be specified for private lessons.")

            prices = self.private_lessons_pack_prices
            if duration in prices and number_of_people in prices[duration]:
                if number_of_classes in prices[duration][number_of_people]:
                    del prices[duration][number_of_people][number_of_classes]

                    if not prices[duration][number_of_people]:
                        del prices[duration][number_of_people]
                    if not prices[duration]:
                        del prices[duration]

        elif pack_type == "group":
            if not duration or not number_of_classes:
                raise ValueError("Duration and number of classes must be specified for group lessons.")

            prices = self.group_lessons_pack_prices
            if duration in prices and number_of_classes in prices[duration]:
                del prices[duration][number_of_classes]
                if not prices[duration]:
                    del prices[duration]

        self.save()
    
    def get_notification_template(self, key):
        """
        Retrieves a notification template by key. Returns a default if not found.
        """
        templates = self.notification_templates or {}
        default_templates = {
            "private_pack_purchased_subject_parent": "Private Pack Purchased for {students}",
            "private_pack_purchased_message_parent": (
                "Dear {parent_name},\n\n"
                "A new private pack has been purchased for {students}.\n\n"
                "Pack Details:\n"
                "- Number of Classes: {number_of_classes}\n"
                "- Duration per Class: {duration_minutes} minutes\n"
                "- Instructor: {instructor_name}\n"
                "- Start Date: {start_date}\n\n"
                "- Total Price: {total_price}{currency}\n\n"
                "Thank you for choosing {school_name}."
            ),
            "private_pack_purchased_subject_instructor": "New Private Pack Assigned",
            "private_pack_purchased_message_instructor": (
                "Dear {instructor_name},\n\n"
                "You have been assigned to a new private pack for {students}.\n\n"
                "Pack Details:\n"
                "- Number of Classes: {number_of_classes}\n"
                "- Duration per Class: {duration_minutes} minutes\n"
                "- Instructor: {instructor_name}\n"
                "- Start Date: {start_date}\n\n"
                "Please check your schedule for more details."
            ),
            "private_pack_purchased_subject_admin": "New Private Pack Booked",
            "private_pack_purchased_message_admin": (
                "Dear Admin,\n\n"
                "A new private pack has been booked for {students}.\n\n"
                "Pack Details:\n"
                "- Number of Classes: {number_of_classes}\n"
                "- Duration per Class: {duration_minutes} minutes\n"
                "- Instructor: {instructor_name}\n"
                "- Start Date: {start_date}\n\n"
                "- Total Price: {total_price}{currency}\n\n"
                "Please review the booking details."
            ),
            "private_class_scheduled_subject_parent": "Private Class Scheduled for {students}",
            "private_class_scheduled_message_parent": (
                "Dear {parent_name},\n\n"
                "The private class number {class_number} of {number_of_classes} has been scheduled for {students}.\n\n"
                "Class Details:\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- Duration: {duration_in_minutes} minutes\n"
                "- Instructor: {instructor_name}"
            ),
            "private_class_scheduled_subject_instructor": "Private Class Scheduled for {students}",
            "private_class_scheduled_message_instructor": (
                "Dear {instructor_name},\n\n"
                "The private class number {class_number} of {number_of_classes} has been scheduled for {students}.\n\n"
                "Class Details:\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- Duration: {duration_in_minutes} minutes"
            ),
            "private_class_scheduled_subject_admin": "Private Class Scheduled for {students}",
            "private_class_scheduled_message_admin": (
                "Dear Admin,\n\n"
                "The private class number {class_number} of {number_of_classes} has been scheduled for {students}.\n\n"
                "Class Details:\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- Duration: {duration_in_minutes} minutes"
            ),
            "conflict_notification_subject": "Scheduling Conflict Detected: {conflict_type}",
            "conflict_notification_message_instructor": (
                "Dear {instructor_name},\n\n"
                "A scheduling conflict was detected for the following:\n\n"
                "Conflict Details:\n"
                "- Type: {conflict_type}\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- End Time: {end_time}\n\n"
                "Please address this issue promptly.\n\n"
                "Thank you,\n{school_name}"
            ),
            "conflict_notification_message_parent": (
                "Dear {parent_name},\n\n"
                "A scheduling conflict was detected for your child's class/activity.\n\n"
                "Conflict Details:\n"
                "- Type: {conflict_type}\n"
                "- Date: {date}\n"
                "- Start Time: {start_time}\n"
                "- End Time: {end_time}\n\n"
                "Please contact us for more details.\n\n"
                "Thank you,\n{school_name}"
            ),
            "expiration_alert_subject_parent" : "Theres a pack expiring in {days_until_expiration}",
            "expiration_alert_message_parent" : (
                "Dear {parent_name},\n\n"
                "{students}'s {type} pack is expiring in {days_until_expiration}.\n\n"
                "Please contact us for more details.\n\n"
                "Thank you,\n{school_name}"
            ),
        }
        return templates.get(key, default_templates.get(key))
    
    # Example: when adding an instructor, update the instructor's payment_types for this school.
    def add_instructor(self, instructor):
        if instructor and instructor not in self.instructors.all():
            self.instructors.add(instructor)
            user = instructor.user
            
            # Ensure the instructor has a dictionary for payment_types.
            if not user.payment_types or not isinstance(user.payment_types, dict):
                user.payment_types = {}
            
            # If there's no payment types entry for this school, initialize it
            if self.name not in user.payment_types or not user.payment_types[self.name]:
                user.payment_types[self.name] = copy.deepcopy(self.payment_types)
                user.save(update_fields=['payment_types'])
            
            return True
        return False
    
    def remove_instructor(self, instructor):
        if instructor and instructor in self.instructors.all():
            self.instructors.remove(instructor)
            user = instructor.user
            
            # Remove the payment types entry for this school if it exists
            if user.payment_types and isinstance(user.payment_types, dict):
                if self.name in user.payment_types:
                    del user.payment_types[self.name]
                    user.save(update_fields=['payment_types'])
                    
            return True
        return False
    
    def add_scheduled_lesson_to_attendance(self, date, id, type, lesson_was_scheduled):
        if not self.attendance_by_date:
            self.attendance_by_date = {}
        date_str = str(date)
        if date_str not in self.attendance_by_date:
            self.attendance_by_date[date_str] = {"scheduled": [], "unscheduled": []}
        if lesson_was_scheduled:
            self.attendance_by_date[date_str]["scheduled"].append(f"{type}-{id}")
        else:
            self.attendance_by_date[date_str]["unscheduled"].append(f"{type}-{id}")
        self.save()
    
    def update_extra_price(self, item_name, price):
        if not item_name or price is None:
            raise ValueError("Item name and price must be provided.")
        if not isinstance(price, (int, float)) or price < 0:
            raise ValueError("Price must be a positive number.")
        extra_prices = self.extra_prices or {}
        extra_prices[item_name] = price
        self.extra_prices = extra_prices
        self.save()
        return True
    
    def remove_extra_price(self, item_name):
        if not item_name:
            raise ValueError("Item name must be provided.")
        if not self.extra_prices or item_name not in self.extra_prices:
            return False
        del self.extra_prices[item_name]
        self.save()
        return True
