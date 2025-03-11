import random
import re
import copy
import logging
from django.db import models
from django.apps import apps
import uuid

logger = logging.getLogger(__name__)

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
    services = models.JSONField(default=list, blank=True)
    name = models.CharField(max_length=255)
    payment_types = models.JSONField(default=dict, blank=True, null=True)
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
    
    def add_or_edit_service(self, service_data: dict) -> list:
        """
        Add or edit a service in this school's services list based on the 'id' field.

        Validation:
          - The service's "type" field must contain either a "pack" or an "activity", but not both.
        
        If 'id' is not provided, a new one is generated.
        If a service with that 'id' exists, it is updated; otherwise, appended.
        
        Returns the updated list of services.
        """
        services_list = self.services or []

        # Validate the "type" field.
        service_type = service_data.get("type", {})
        has_pack = "pack" in service_type and bool(service_type["pack"])
        has_activity = "activity" in service_type and bool(service_type["activity"])

        if has_pack and has_activity:
            raise ValueError("Service 'type' must contain either a 'pack' or an 'activity', not both.")
        if not (has_pack or has_activity):
            raise ValueError("Service 'type' must contain either a 'pack' or an 'activity'.")

        # Generate an id if missing.
        if "id" not in service_data or not service_data["id"]:
            service_data["id"] = str(uuid.uuid4())

        incoming_id = service_data["id"]

        # Find if there's an existing service with the same id.
        found_index = None
        for i, svc in enumerate(services_list):
            if svc.get("id") == incoming_id:
                found_index = i
                break

        if found_index is not None:
            # Update existing service.
            services_list[found_index].update(service_data)
        else:
            # Add a new service.
            services_list.append(service_data)

        self.services = services_list
        self.save()
        return self.services

    def update_payment_type_value(self, key_path, new_value, user_obj=None):
        """
        Updates a single nested field in the payment_types structure.
        If user_obj is provided, update that user's payment_types for this school.
        Otherwise, update the school's default payment_types.
        """
        logger.debug("update_payment_type_value called with key_path: %s and new_value: %s", key_path, new_value)
        keys = re.findall(r'\w[\w\s-]*', key_path)
        logger.debug("Parsed keys: %s", keys)

        if user_obj:
            # Ensure user_obj.payment_types is a dict.
            if not user_obj.payment_types or not isinstance(user_obj.payment_types, dict):
                logger.debug("Initializing user_obj.payment_types as an empty dict")
                user_obj.payment_types = {}
            # Only initialize if it doesn't exist yet.
            if self.name not in user_obj.payment_types:
                logger.debug("Initializing user_obj.payment_types[%s] as an empty dict", self.name)
                user_obj.payment_types[self.name] = {}
            target = user_obj.payment_types[self.name]
            logger.debug("User-specific target structure before update: %s", target)
        else:
            if not self.payment_types or not isinstance(self.payment_types, dict):
                logger.debug("Initializing self.payment_types")
                self.payment_types = {}
            target = self.payment_types
            logger.debug("School default target structure before update: %s", target)

        # Traverse the nested structure for all keys except the last.
        current = target
        for key in keys[:-1]:
            logger.debug("Traversing key '%s'. Current structure: %s", key, current)
            if key not in current or not isinstance(current[key], (dict, list)):
                logger.debug("Key '%s' not found or not a dict/list. Initializing it as empty dict.", key)
                current[key] = {}
            current = current[key]
        logger.debug("Structure at final level before update: %s", current)

        last_key = keys[-1]

        # Handle fixed pricing updates if the target node is a list.
        if isinstance(current.get(last_key), list):
            logger.debug("Target for key '%s' is a list; processing fixed pricing update.", last_key)
            required_keys = {"duration", "min_students", "max_students", "price"}
            if isinstance(new_value, list):
                for pricing in new_value:
                    if not isinstance(pricing, dict):
                        raise ValueError("Each fixed pricing entry must be a dictionary.")
                    if not required_keys.issubset(pricing.keys()):
                        raise ValueError(f"Each fixed pricing entry must contain keys: {required_keys}")
                    updated = False
                    for rule in current[last_key]:
                        if (rule.get("duration") == pricing["duration"] and 
                            rule.get("min_students") == pricing["min_students"] and 
                            rule.get("max_students") == pricing["max_students"]):
                            rule["price"] = pricing["price"]
                            updated = True
                            break
                    if not updated:
                        current[last_key].append(pricing)
            elif isinstance(new_value, dict):
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
                raise ValueError("For updating a list field (fixed pricing), new_value must be a dict or list of dicts.")
        else:
            logger.debug("Updating key '%s' from %s to %s", last_key, current.get(last_key), new_value)
            current[last_key] = new_value

        logger.debug("Final updated target structure: %s", target)

        if user_obj:
            logger.debug("Saving user_obj.payment_types")
            user_obj.save(update_fields=["payment_types"])
        else:
            logger.debug("Saving self.payment_types")
            self.save(update_fields=["payment_types"])
        logger.debug("Update successful.")
        return True

    def delete_payment_type_value(self, key_path, entry_to_delete, user_obj=None):
        """
        Deletes a fixed pricing entry from the payment_types structure.
        The payload should specify a key_path (e.g., "instructor[private][fixed]") and
        an entry (a dict with keys like 'duration', 'min_students', 'max_students', 'price').
        """
        logger.debug("delete_payment_type_value called with key_path: %s and entry: %s", key_path, entry_to_delete)
        keys = re.findall(r'\w[\w\s-]*', key_path)
        logger.debug("Parsed keys: %s", keys)
        
        if user_obj:
            if not user_obj.payment_types or not isinstance(user_obj.payment_types, dict):
                user_obj.payment_types = {}
            if self.name not in user_obj.payment_types:
                user_obj.payment_types[self.name] = {}
            target = user_obj.payment_types[self.name]
        else:
            if not self.payment_types or not isinstance(self.payment_types, dict):
                self.payment_types = {}
            target = self.payment_types
        
        current = target
        for key in keys[:-1]:
            if key not in current or not isinstance(current[key], (dict, list)):
                current[key] = {}
            current = current[key]
        
        last_key = keys[-1]
        if isinstance(current.get(last_key), list):
            required_keys = {"duration", "min_students", "max_students", "price"}
            # Verify the entry contains the required keys.
            if not required_keys.issubset(entry_to_delete.keys()):
                raise ValueError(f"Entry must contain keys: {required_keys}")
            # Remove matching entry.
            original_length = len(current[last_key])
            current[last_key] = [
                rule for rule in current[last_key]
                if not (rule.get("duration") == entry_to_delete["duration"] and
                        rule.get("min_students") == entry_to_delete["min_students"] and
                        rule.get("max_students") == entry_to_delete["max_students"] and
                        rule.get("price") == entry_to_delete["price"])
            ]
            if len(current[last_key]) == original_length:
                raise ValueError("No matching fixed pricing entry found to delete.")
        else:
            raise ValueError("Target field is not a list. Cannot delete entry.")
        
        if user_obj:
            user_obj.save(update_fields=["payment_types"])
        else:
            self.save(update_fields=["payment_types"])
        return True

    
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
    
    def add_payment_types_to_user(self, user):
        # Ensure the instructor has a dictionary for payment_types.
        if not user.payment_types or not isinstance(user.payment_types, dict):
            user.payment_types = {}
        
        user.payment_types[self.name] = copy.deepcopy(self.payment_types)
        user.save(update_fields=['payment_types'])
            
    def remove_payment_types_from_user(self, user):
        # Remove the payment types entry for this school if it exists
        if user.payment_types and isinstance(user.payment_types, dict):
            if self.name in user.payment_types:
                del user.payment_types[self.name]
                user.save(update_fields=['payment_types'])
    
    # Example: when adding an instructor, update the instructor's payment_types for this school.
    def add_instructor(self, instructor):
        if instructor and instructor not in self.instructors.all():
            self.instructors.add(instructor)
            user = instructor.user
            self.add_payment_types_to_user(user)
            return True
        return False
    
    def remove_instructor(self, instructor):
        if instructor and instructor in self.instructors.all():
            self.instructors.remove(instructor)
            user = instructor.user
            self.remove_payment_types_from_user(user)
                    
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
