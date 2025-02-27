import random
import re
import copy
from django.db import models
from django.apps import apps

def default_payment_types():
    """
    Returns a default payment types structure.
    The top-level keys represent roles directly.
    The "fixed" pricing for private lessons is now a list of pricing dictionaries.
    """
    fixed_default = round(random.uniform(10, 20), 2)
    commission_default = random.choice([0, 5, 10])
    default_fixed = [
        {"duration": 90, "min_students": 1, "max_students": 2, "price": fixed_default},
        {"duration": 60, "min_students": 1, "max_students": 4, "price": fixed_default},
        {"duration": 60, "min_students": 0, "max_students": 0, "price": fixed_default},
        {"duration": 0, "min_students": 0, "max_students": 0, "price": fixed_default},
    ]
    return {
        "instructor": {
            "fixed monthly rate": None,
            "private lesson": {
                "commission": commission_default,
                "fixed": copy.deepcopy(default_fixed)
            }
        },
        "admin": {
            "fixed monthly rate": None,
            "private lesson": {
                "commission": commission_default,
                "fixed": copy.deepcopy(default_fixed)
            }
        },
        "monitor": {
            "fixed monthly rate": None,
            "private lesson": {
                "commission": commission_default,
                "fixed": copy.deepcopy(default_fixed)
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

def default_pack_prices():
    return {
        "private": {
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
        },
        "group": {
            "60m": {
                "1": 25,
                "4": 70,
            }
        }
    }

def default_notification_templates():
    return {
            "group_pack_purchased_subject_parent": "Group Pack Purchased for {students}",
            "group_pack_purchased_message_parent": (
                "Dear {parent_name},\n\n"
                "A new group pack has been purchased for {students}.\n\n"
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
                "A new group pack has been booked for {students}.\n\n"
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
    pack_prices = models.JSONField(default=dict, blank=True)
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

    def __str__(self):
        return self.name

    def update_payment_type_value(self, key_path, new_value, user_obj=None):
        """
        Updates a single nested field in the payment_types structure.

        For simple dictionary fields (e.g., "commission" or "fixed monthly rate"), the key_path is used as before.
        However, if the target field is the "fixed" pricing list, then new_value is expected to be a dictionary 
        with keys: "duration", "min_students", "max_students", and "price". The method will search the list for 
        a pricing rule matching the provided criteria. If found, it updates the rule’s "price" with new_value["price"].
        If no matching rule exists, it appends new_value to the list.

        Args:
            key_path (str): A string representing the nested path.
                For example: "instructor[private lesson][fixed]" for the fixed pricing list.
            new_value: The new value to assign. For the "fixed" field, this must be a dict with the required keys.
            user_obj (optional): If provided, update that user's payment_types for this school.
                            Otherwise, update the school's default payment_types.
        """
        # Parse the key_path into parts. For example, "instructor[private lesson][fixed]" -> 
        # ["instructor", "private lesson", "fixed"]
        keys = re.findall(r'\w[\w\s-]*', key_path)
        
        # Determine the target: either user-specific (keyed by school name) or the school's own payment_types.
        if user_obj:
            if not user_obj.payment_types or not isinstance(user_obj.payment_types, dict):
                user_obj.payment_types = {}
            if self.name not in user_obj.payment_types or not user_obj.payment_types[self.name]:
                user_obj.payment_types[self.name] = copy.deepcopy(self.payment_types) if self.payment_types else {}
            target = user_obj.payment_types[self.name]
        else:
            if not self.payment_types or not isinstance(self.payment_types, dict):
                self.payment_types = default_payment_types()
            target = self.payment_types

        # Traverse the nested structure for all keys except the last.
        current = target
        for key in keys[:-1]:
            if key not in current or not isinstance(current[key], (dict, list)):
                current[key] = {}
            current = current[key]
        
        last_key = keys[-1]
        
        # If the current node for last_key is a list, we assume it is the "fixed" pricing list.
        if isinstance(current.get(last_key), list):
            # In this case, new_value must be a dict with required keys.
            if not isinstance(new_value, dict):
                raise ValueError("For updating a list field (fixed pricing), new_value must be a dictionary.")
            required_keys = {"duration", "min_students", "max_students", "price"}
            if not required_keys.issubset(new_value.keys()):
                raise ValueError(f"new_value must contain keys: {required_keys}")
            updated = False
            for rule in current[last_key]:
                if (rule.get("duration") == new_value["duration"] and
                    rule.get("min_students") == new_value["min_students"] and
                    rule.get("max_students") == new_value["max_students"]):
                    rule["price"] = new_value["price"]
                    updated = True
                    break
            if not updated:
                current[last_key].append(new_value)
        else:
            # Otherwise, simply update the field.
            current[last_key] = new_value

        # Save the changes.
        if user_obj:
            user_obj.save(update_fields=["payment_types"])
        else:
            self.save(update_fields=["payment_types"])
    
    def get_unpaid_camp_orders(self):
        return list(self.camp_orders.filter(is_fully_paid=False))
    
    def get_unpaid_packs(self):
        return list(self.packs.filter(is_paid=False))
    
    def update_pack_price(self, pack_type, duration, number_of_people=None, number_of_classes=None, price=None, expiration_date=None):
        if pack_type not in ["private", "group"]:
            raise ValueError("pack_type must be either 'private' or 'group'")
        if not price:
            raise ValueError("A price must be specified")
        
        pack_prices = self.pack_prices or {}
        
        # Ensure the key for pack_type exists.
        if pack_type not in pack_prices:
            pack_prices[pack_type] = {}
        
        if pack_type == "private":
            if not number_of_people or not number_of_classes:
                raise ValueError("For private packs, number_of_people and number_of_classes must be specified")
            if duration not in pack_prices[pack_type]:
                pack_prices[pack_type][duration] = {}
            if number_of_people not in pack_prices[pack_type][duration]:
                pack_prices[pack_type][duration][number_of_people] = {}
            pack_prices[pack_type][duration][number_of_people][number_of_classes] = {
                'price': price,
                'expiration_date': expiration_date
            }
        elif pack_type == "group":
            if not number_of_classes:
                raise ValueError("For group packs, number_of_classes must be specified")
            if duration not in pack_prices[pack_type]:
                pack_prices[pack_type][duration] = {}
            pack_prices[pack_type][duration][number_of_classes] = {
                'price': price,
                'expiration_date': expiration_date
            }
        
        self.pack_prices = pack_prices
        self.save()
        return True

    def delete_pack_option(self, pack_type, duration=None, number_of_people=None, number_of_classes=None):
        if pack_type not in ["private", "group"]:
            raise ValueError("Invalid lesson type. Use 'private' or 'group'.")
        
        pack_prices = self.pack_prices
        
        if pack_type == "private":
            if not duration or not number_of_people or not number_of_classes:
                raise ValueError("Duration, number of people, and number of classes must be specified for private lessons.")
            
            if duration in pack_prices[pack_type] and number_of_people in pack_prices[pack_type][duration]:
                if number_of_classes in pack_prices[pack_type][duration][number_of_people]:
                    del pack_prices[pack_type][duration][number_of_people][number_of_classes]
                    
                    if not pack_prices[pack_type][duration][number_of_people]:
                        del pack_prices[pack_type][duration][number_of_people]
                    if not pack_prices[pack_type][duration]:
                        del pack_prices[pack_type][duration]
        
        elif pack_type == "group":
            if not duration or not number_of_classes:
                raise ValueError("Duration and number of classes must be specified for group lessons.")
            
            if duration in pack_prices[pack_type] and number_of_classes in pack_prices[pack_type][duration]:
                del pack_prices[pack_type][duration][number_of_classes]
                if not pack_prices[pack_type][duration]:
                    del pack_prices[pack_type][duration]
        
        self.pack_prices = pack_prices
        self.save()
        return True
    
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
