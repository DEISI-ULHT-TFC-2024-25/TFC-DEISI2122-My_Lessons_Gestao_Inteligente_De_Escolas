from datetime import time, timedelta, datetime
from decimal import Decimal
from django.db import models
from events.models import Activity
from notifications.models import Notification
from users.models import Discount, Unavailability, UserAccount, Student, Instructor
from users.utils import get_users_name, get_students_ids, get_instructors_name, get_instructors_ids
from django.db.models import Q
from django.utils.timezone import now, make_aware
from payments.models import Payment

# TODO not here but everywhere make_aware problem (convert to datetime and then make the operation with now())

class Pack(models.Model):
    date = models.DateField()
    date_time = models.DateTimeField(auto_now_add=True)
    type = models.CharField(max_length=255, default='private')
    number_of_classes = models.PositiveIntegerField()
    number_of_classes_left = models.PositiveIntegerField()
    duration_in_minutes = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_done = models.BooleanField(default=False)
    is_paid = models.BooleanField(default=False)
    is_suspended = models.BooleanField(default=False)
    debt = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    students = models.ManyToManyField(Student, related_name="packs", blank=True)
    instructors = models.ManyToManyField(Instructor, related_name="packs", blank=True)
    finished_date = models.DateField(blank=True, null=True)
    expiration_date = models.DateField(blank=True, null=True)
    parents = models.ManyToManyField(UserAccount, blank=True, related_name="packs")
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='packs', blank=True, null=True)
    sport = models.ForeignKey('sports.Sport', related_name='packs', on_delete=models.SET_NULL, blank=True, null=True)

    def __str__(self):
        return f"{self.type} pack for {self.get_students_name()}, {self.number_of_classes_left}/{self.number_of_classes} lessons left, {self.get_number_of_unscheduled_lessons()} number of unscheduled lessons"
    
    def handle_expiration_date(self):
        today = now().date()
        print("ENTERED HANDLE EXPIRATION")
        print(self.expiration_date)
        if self.expiration_date < today:
            print(f"PACK IS EXPIRED: {str(self)}")
            if self.type == "private":
                for lesson in self.lessons.filter(is_done=True):
                    lesson.mark_as_given()
                self.update_pack_status()
        days_until_expiration = None
        if self.expiration_date:
            days_until_expiration = (self.expiration_date - today).days
        return days_until_expiration
            
        
    def update_pack_status(self):

        if self.number_of_classes_left > 0:
            self.is_done = False
        elif self.number_of_classes_left == 0:
            self.is_done = True
        else:
            return False

        self.save(update_fields=["is_done"])
        return True

        # TODO notifications

    def get_number_of_unscheduled_lessons(self):
        today = now().date()

        if self.type == "private":
            return self.lessons.filter(
                is_done=False
            ).filter(
                Q(date__lt=today) |
                Q(date=None) |
                Q(start_time=None)
            ).count()
        elif self.type == "group":
            # If there are no lessons, return the total number of classes.
            if not self.lessons.exists():
                return self.number_of_classes
            
            # Count lessons that are considered scheduled (have both date and start_time).
            scheduled_count = self.lessons.filter(
                date__isnull=False,
                start_time__isnull=False
            ).count()
            
            # Calculate unscheduled lessons.
            unscheduled = self.number_of_classes - scheduled_count
            
            # Ensure we never return a negative value.
            return max(unscheduled, 0)

    def get_students_name(self):
        return get_users_name(self.students.all())

    def get_students_ids(self):
        return get_students_ids(self.students.all())

    def get_instructors_name(self):
        return get_instructors_name(self.instructors.all())
    
    def get_instructors_ids(self):
        return get_instructors_ids(self.instructors.all())
    
    @classmethod
    def book_new_pack(cls, students, school, date, number_of_classes, duration_in_minutes, instructors, price, payment, discount_id = None, type = None, expiration_date=None):
        """
        Books a new private pack, creates the necessary associations, and sends notifications.
        """
        parents = []

        for student in students:
            for parent in student.parents.all():
                parents.append(parent)

        parents = list(set(parents))

        if not date:
            date = now().date()

        # Create the pack
        pack = cls.objects.create(
            school=school,
            date=date,
            number_of_classes=number_of_classes,
            number_of_classes_left=number_of_classes,
            duration_in_minutes=duration_in_minutes,
            price=price,
            debt=price, 
            type=type,
            expiration_date=expiration_date
        )

        pack.students.set(students)
        pack.parents.set(parents)
        if school:
            for parent in parents:
                school.parents.add(parent)
            for student in students:
                school.students.add(student)
        pack.instructors.set(instructors)

        if type == "private":
            pack.create_private_classes()

        if payment:
            pack.update_debt(payment=payment)
        
        # Notify parents
        for parent in parents:
            Notification.create_notification(
                user=parent,
                subject=school.get_notification_template(f"{type}_pack_purchased_subject_parent").format(
                    students=get_users_name(students),
                ),
                message=school.get_notification_template(f"{type}_pack_purchased_message_parent").format(
                    parent_name=parent.first_name,
                    students=get_users_name(students),
                    number_of_classes=number_of_classes,
                    duration_minutes=duration_in_minutes,
                    instructor_name=f"{get_instructors_name(instructors)}" if instructors else "Not Assigned yet",
                    start_date=date,
                    total_price=price,
                    currency=school.currency,
                    school_name=school.name
                ),
                packs=[pack],
                school=school,
                type="Parent",
            )

        # Notify instructors
        if instructors:
            for instructor in instructors:
                Notification.create_notification(
                    user=instructor.user,
                    subject=school.get_notification_template(f"{type}_pack_purchased_subject_instructor"),
                    message=school.get_notification_template(f"{type}_pack_purchased_message_instructor").format(
                        instructor_name=f"{instructor.user.first_name} {instructor.user.last_name}",
                        students=get_users_name(students),
                        number_of_classes=number_of_classes,
                        duration_minutes=duration_in_minutes,
                        start_date=date
                    ),
                    packs=[pack],
                    school=school,
                    type="Instructor",
                )

        # Notify school admin
        for admin in school.admins.all():
            Notification.create_notification(
                user=admin,
                subject=school.get_notification_template(f"{type}_pack_purchased_subject_admin"),
                message=school.get_notification_template(f"{type}_pack_purchased_message_admin").format(
                    students=get_users_name(students),
                    number_of_classes=number_of_classes,
                    duration_minutes=duration_in_minutes,
                    instructor_name=f"{get_instructors_name(instructors)}" if instructors else "Not Assigned",
                    start_date=date,
                    total_price=price,
                    currency=school.currency
                ),
                packs=[pack],
                school=school,
                type="Admin",
            )
        
        if discount_id and pack:
            discount = Discount.objects.filter(id=discount_id)
            if discount:
                discount.delete()
        return pack
    
    def create_private_classes(self):
        for i in range(self.number_of_classes):
            private_class = Lesson.objects.create(
                class_number=i + 1,
                price=self.price/self.number_of_classes,
                duration_in_minutes=self.duration_in_minutes,
                school=self.school,
                type=self.type,
            )
            private_class.students.set(self.students.all())
            private_class.instructors.set(self.instructors.all())
            self.lessons.add(private_class)
        self.save()

    def update_debt(self, payment):
        self.debt -= payment
        if self.debt <= 0:
            self.is_paid = True
        self.save(update_fields=["debt", "is_paid"])
        
    def suspend(self):
        self.is_suspended = True
        self.save(update_fields=["is_suspended"])

    def resume_pack(self):
        self.is_suspended = False
        self.save(update_fields=["is_suspended"])

    def add_class(self, lesson):
        if not self.is_done:
            self.lessons.add(lesson)
            self.save()
        else:
            raise ValueError("Cannot add classes to a completed pack.")

class Lesson(models.Model):
    date = models.DateField(null=True, blank = True)
    start_time = models.TimeField(null=True, blank = True)
    end_time = models.TimeField(null=True, blank = True)
    duration_in_minutes = models.PositiveIntegerField()
    class_number = models.PositiveIntegerField(null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    is_done = models.BooleanField(default=False)
    extras = models.JSONField(null=True, blank=True, default=dict)
 # example {student_id : {
 #              extra_student_count,
 #              equipments : {
 #                  equipment : {
 #                      id, (may be null, only for the future)
 #                      name,
 #                      size,
 #                      is_kids_size, (boolean)
 #                  },
 #              }
 #          }
    level = models.PositiveIntegerField(blank=True, null=True)
    minimum_age = models.PositiveIntegerField(blank=True, null=True)
    maximum_age = models.PositiveIntegerField(blank=True, null=True)
    maximum_number_of_students = models.PositiveIntegerField(blank=True, null=True)
    students = models.ManyToManyField('users.Student', related_name="lessons")
    instructors = models.ManyToManyField(Instructor, related_name="lessons", blank=True)
    location = models.ForeignKey('locations.Location', on_delete=models.SET_NULL, null=True, blank=True, related_name="lessons")
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='lessons', blank=True, null=True)
    pack = models.ForeignKey(Pack, on_delete=models.CASCADE, related_name='lessons', blank=True, null=True)
    type = models.CharField(max_length=50, default='private')
    sport = models.ForeignKey('sports.Sport', related_name='lessons', on_delete=models.SET_NULL, blank=True, null=True)

    def __str__(self):
        if self.date and self.start_time:
            if self.pack != None and self.class_number != None:
                return f"{self.get_students_name()} {self.type} lesson {self.class_number}/{self.pack.number_of_classes} on {self.date} at {self.start_time}"
            else: 
                return f"{self.get_students_name()} {self.type} lesson on {self.date} at {self.start_time}"
        else:
            if self.pack != None and self.class_number != None:
                return f"{self.get_students_name()} {self.type} lesson {self.class_number}/{self.pack.number_of_classes}"
            else: 
                return f"{self.get_students_name()} {self.type} lesson"
    

    def list_available_lesson_times(self, date, increment):
        """
        Returns a list of available start times (as strings in "HH:MM" format)
        on the given date for a private lesson.
        This method only applies to lessons of type "private".
        """
        # Only process lessons that are marked as "private"
        if self.type != "private":
            return []
        
        # Define the working hours for the day (adjust as needed)
        day_start = time(8, 0)
        day_end = time(20, 0)
        
        available_times = []
        current_dt = datetime.combine(date, day_start)
        end_of_day_dt = datetime.combine(date, day_end)
        
        # Iterate in 15-minute increments; ensure the lesson fits within the day.
        while current_dt + timedelta(minutes=self.duration_in_minutes) <= end_of_day_dt:
            start_time = current_dt.time()
            end_time = (current_dt + timedelta(minutes=self.duration_in_minutes)).time()
            
            # Check availability for each instructor assigned to this lesson.
            
            instructors = []
            slot_available = False
            
            if self.instructors.exists():
                instructors = self.instructors.all()
            elif self.school and self.school.instructors.exists():
                instructors = self.school.instructors.all()
            
            
            for instructor in instructors:
                # Check overlapping unavailabilities.
                overlapping_unavailabilities = Unavailability.objects.filter(
                    instructor=instructor,
                    date=date,
                    start_time__lt=end_time,
                    end_time__gt=start_time
                )
                
                # Check overlapping lessons (excluding the current lesson).
                overlapping_lessons = Lesson.objects.filter(
                    instructors__in=[instructor],
                    date=date,
                    start_time__lt=end_time,
                    end_time__gt=start_time
                ).exclude(id=self.id)
                
                # Check overlapping activities.
                overlapping_activities = Activity.objects.filter(
                    instructors__in=[instructor],
                    date=date,
                    start_time__lt=end_time,
                    end_time__gt=start_time
                )
                
                # If no conflicts, the instructor is available for this slot.
                if (not overlapping_unavailabilities.exists() and 
                    not overlapping_lessons.exists() and 
                    not overlapping_activities.exists()):
                    slot_available = True
                    break  # No need to check further instructors
            
            if slot_available:
                # Convert start_time to a string in "HH:MM" format
                available_times.append(start_time.strftime("%H:%M"))
                
            current_dt += timedelta(minutes=increment)
        
        return available_times

    def get_fixed_price(self, instructor):
        """
        Searches the instructor's fixed pricing list for a configuration matching:
         - self.duration_in_minutes equals configuration["duration"]
         - total student count (students + extra) is between configuration["min_students"] and configuration["max_students"] (inclusive)
         
        Returns the price if a match is found; otherwise, returns None.
        """
        total_students = self.students.count() # TODO (might be a problem if they dont show up) + (self.number_of_extra_students or 0)
        try:
            pricing_list = instructor.user.payment_types[self.school.name]["instructor"][f"{self.type}"]["fixed"]
        except (KeyError, TypeError):
            return None
        for pricing in pricing_list:
            if (self.duration_in_minutes == pricing.get("duration") and 
                pricing.get("min_students") <= total_students <= pricing.get("max_students")):
                return pricing.get("price")
        return None
    
    def mark_as_given(self):
        if self.is_done:
            return False
        self.is_done = True
        self.save(update_fields=["is_done"])

        if self.pack:
            self.pack.number_of_classes_left -= 1
            self.pack.save(update_fields=["number_of_classes_left"])
            self.pack.update_pack_status()
            
        for instructor in self.instructors.all():
            fixed_price = self.get_fixed_price(instructor=instructor) or 0

            try:
                commission = instructor.user.payment_types[self.school.name]["instructor"][f"{self.type}"]["commission"]
            except (KeyError, TypeError):
                commission = 0

            commission_fee = self.price * Decimal(commission) / Decimal(100) if commission else Decimal(0)
            amount_to_add = Decimal(fixed_price) + commission_fee
            
            instructor.user.update_balance(amount=amount_to_add, message=str(self))
        return True
    
    def mark_as_not_given(self):
        if not self.is_done:
            return False
        self.is_done = False
        self.save(update_fields=["is_done"])

        if self.pack:
            self.pack.number_of_classes_left += 1
            self.pack.save(update_fields=["number_of_classes_left"])
            self.pack.update_pack_status()

        for instructor in self.instructors.all():

            fixed_price = self.get_fixed_price(instructor=instructor) or 0
            try:
                commission = instructor.user.payment_types[self.school.name]["instructor"][f"{self.type}"]["commission"]
            except (KeyError, TypeError):
                commission = 0

            commission_fee = self.price * Decimal(commission) / Decimal(100) if commission else Decimal(0)
            amount_to_add = Decimal(fixed_price) + commission_fee
            
            instructor.user.update_balance(amount=-amount_to_add, message=str(self))
        return True
    
    def is_full(self):
        return self.students.count() >= self.maximum_number_of_students
    
    def get_students_name(self):
        return get_users_name(self.students.all())
    
    def get_students_ids(self):
        return get_students_ids(self.students.all())
    
    def get_instructors_name(self):
        return get_instructors_name(self.instructors.all())
    
    def get_instructors_ids(self):
        return get_instructors_ids(self.instructors.all())
    
    def get_extra_costs(self):
        """
        Calculates additional costs for extra students and equipment usage for this lesson.
        
        Expects the Lesson.extras JSONField to have the following structure:
        
            {
                "<student_id>": {
                    "extra_student_count": <int>,
                    "equipments": {
                        "<equipment_key>": {
                            "id": <optional>,
                            "name": <str>,
                            "size": <str>,
                            "is_kids_size": <bool>
                        },
                        ...
                    }
                },
                ...
            }
        
        It then uses the school's extra_prices (a dict mapping names to unit prices) to compute:
        - For each student, the extra cost for extra students: extra_student_count * extra_prices["extra_students"].
        - For each equipment entry, the cost as unit_price from extra_prices based on the equipment name.
        
        Returns a dictionary structured as:
        
            {
                "students": {
                    "<student_id>": {
                        "extra_students": "<count>x<unit_price>" (if any),
                        "equipments": { "<equipment_name>": "<1xunit_price>", ... },
                        "total": <total extra cost for that student>
                    },
                    ...
                },
                "grand_total": <sum of all extra costs>
            }
        """

        # TODO add debt after lesson completion
        # TODO do a helper function to calculate the extra price per student

        if not self.school:
            return {}
        
        extra_prices = self.school.extra_prices or {}
        # If extras is not set, assume no extra costs.
        if not self.extras:
            return {}
        
        result = {"students": {}, "grand_total": 0}
        
        # Iterate over each student_id in the extras dict.
        for student_id, extras_info in self.extras.items():
            student_detail = {}
            total_for_student = 0
            
            # Calculate extra student costs.
            extra_count = extras_info.get("extra_student_count", 0)
            if extra_count:
                # Get unit price; default is 10 if not set.
                price_per_student = extra_prices.get("extra_students", 10)
                student_detail["extra_students"] = f"{extra_count}x{price_per_student}"
                total_for_student += extra_count * price_per_student
            
            # Calculate equipment costs.
            equip_details = {}
            equipments = extras_info.get("equipments", {})
            for equip_key, equip_data in equipments.items():
                equip_name = equip_data.get("name")
                if not equip_name:
                    continue
                unit_price = extra_prices.get(equip_name, 0)
                # Here we assume count=1 per equipment item; extend as needed.
                equip_details[equip_name] = f"1x{unit_price}"
                total_for_student += unit_price
            if equip_details:
                student_detail["equipments"] = equip_details
            
            student_detail["total"] = total_for_student
            result["students"][student_id] = student_detail
            result["grand_total"] += total_for_student

        return result

    def add_student(self, student):
        """
        Add a student to this group class if there is space and no overlapping unavailability.
        """
        if self.is_full():
            return False
        
        # Check for overlapping unavailabilities
        overlapping_unavailabilities = Unavailability.objects.filter(
            student=student,
            date=self.date,
        ).filter(
            start_time__lt=self.end_time,
            end_time__gt=self.start_time,
        )
        
        if overlapping_unavailabilities:
            return False

        # If no issues, add the student
        self.students.add(student)
        self.save()
        return True

    def add_instructor(self, instructor):
        """
        Add a instructor to this group class if there is space and no overlapping unavailability.
        """
        # TODO check for instructor being a monitor
        
         # Overlapping unavailabilities
        overlapping_unavailabilities = Unavailability.objects.filter(
            instructor=instructor,
            date=self.date,
        ).filter(
            start_time__lt=self.end_time,
            end_time__gt=self.start_time,
        )

        # Overlapping private classes
        overlapping_lessons = Lesson.objects.filter(
            instructors__in=[instructor],
            date=self.date,
        ).filter(
            start_time__lt=self.end_time,
            end_time__gt=self.start_time,
        )

        overlapping_activities = Activity.objects.filter(
            instructors__in=[instructor],
            date=self.date,
            start_time__lt=self.end_time,
            end_time__gt=self.start_time,
        )
            
        if not (overlapping_unavailabilities or overlapping_lessons) or overlapping_activities:
            if self.instructors:
                # TODO notify Instructor
                pass
            self.instructors.add(instructor)
            self.save()
            return True
        return False

    def remove_student(self, student):
        if student in self.students.all():
            self.students.remove(student)
            self.save()
            return True
        return False

    def remove_instructor(self, instructor):
        if instructor in self.instructors.all():
            self.instructors.remove(instructor)
            self.save()
            return True
        return False

    def is_available(self, date, start_time, instructor = None):

        instructors = []

        if not instructor:
            for i in self.school.instructors.all():
                instructors.append(i)
        else:
            instructors.append(instructor)
        
        end_time = (datetime.combine(date, start_time) + timedelta(minutes=self.duration_in_minutes)).time()

        for i in instructors:

            # Overlapping unavailabilities
            overlapping_unavailabilities = Unavailability.objects.filter(
                instructor=instructor,
                date=date,
            ).filter(
                start_time__lt=end_time,
                end_time__gt=start_time,
            )

            # Overlapping private classes
            overlapping_lessons = Lesson.objects.filter(
                instructors__in=[instructor],
                date=date,
            ).filter(
                start_time__lt=end_time,
                end_time__gt=start_time,
            ).exclude(id=self.id)

            overlapping_activities = Activity.objects.filter(
                date=date,
                instructors__in=[instructor],
                start_time__lt=end_time,
                end_time__gt=start_time,
            )
            
            if not (overlapping_unavailabilities or overlapping_lessons or overlapping_activities):
                return True, i
        return False, instructor
    
    def can_still_reschedule(self, role):

        """
        Determines if a lesson can still be rescheduled based on the school's reschedule time limit.
        """
        if self.date and self.start_time and self.school:
            lesson_datetime = datetime.combine(self.date, self.start_time)
            lesson_datetime = make_aware(lesson_datetime)

            time_difference = lesson_datetime - now()

            # Convert time difference into hours
            number_of_hours = time_difference.total_seconds() / 3600

            if number_of_hours < self.school.reschedule_time_limit and role == "Parent":
                return False
        return True

    def schedule_lesson(self, date, time):

        # TODO (tries to find an other instructor acording to the minimum and maximum number of instructors?)

        available_instructors = []
        unavailable_instructors = []
        new_instructors = []

        if self.instructors.exists():
            for instructor in self.instructors.all():

                is_available, instructor = self.is_available(instructor=instructor, date=date, start_time=time)

                if is_available:
                    available_instructors.append(instructor)
                else:
                    unavailable_instructors.append(instructor)
        else:
            is_available, instructor = self.is_available(instructor=None, date=date, start_time=time)
            if is_available:
                available_instructors.append(instructor)
                new_instructors.append(instructor)
            else:
                unavailable_instructors.append(instructor)
                


        if len(available_instructors) > 0:
            if len(self.instructors.all()) == 0:
                self.instructors.set(new_instructors) # TODO it never passes here as it iterates through the instructors
            self.date = date
            self.start_time = time
            self.end_time = (datetime.combine(self.date, time) + timedelta(minutes=self.duration_in_minutes)).time()
            self.save()
            if self.school:
                # Notify parents
                for parent in self.pack.parents.all():
                    Notification.create_notification(
                        user=parent,
                        subject=self.school.get_notification_template(f"{self.type}_class_scheduled_subject_parent").format(
                            students=self.get_students_name()
                        ),
                        message=self.school.get_notification_template(f"{self.type}_class_scheduled_message_parent").format(
                            parent_name=parent.first_name,
                            students=self.get_students_name(),
                            class_number=self.class_number,
                            number_of_classes=self.pack.number_of_classes,
                            date=date,
                            start_time=self.start_time,
                            duration_in_minutes=self.duration_in_minutes,
                            instructor_name=f"{get_instructors_name(available_instructors)}" if len(available_instructors) > 0 else "Not Assigned yet"
                        ),
                        lessons=[self],
                        school=self.school,
                        type="Parent",
                    )

                # Notify instructor
                for instructor in available_instructors:
                    Notification.create_notification(
                        user=instructor.user,
                        subject=self.school.get_notification_template(f"{self.type}_class_scheduled_subject_instructor").format(
                            students=self.get_students_name()
                        ),
                        message=self.school.get_notification_template(f"{self.type}_class_scheduled_message_instructor").format(
                            instructor_name=f"{instructor.user.first_name} {instructor.user.last_name}",
                            students=self.get_students_name(),
                            class_number=self.class_number,
                            number_of_classes=self.pack.number_of_classes,
                            date=date,
                            start_time=self.start_time,
                            duration_in_minutes=self.duration_in_minutes
                        ),
                        lessons=[self],
                        school=self.school,
                        type="Instructor",
                    )

                # Notify school admin
                for admin in self.school.admins.all():
                    Notification.create_notification(
                        user=admin,
                        subject=self.school.get_notification_template(f"{self.type}_class_scheduled_subject_admin").format(
                            students=self.get_students_name()
                        ),
                        message=self.school.get_notification_template(f"{self.type}_class_scheduled_message_admin").format(
                            students=self.get_students_name(),
                            class_number=self.class_number,
                            number_of_classes=self.pack.number_of_classes,
                            date=date,
                            start_time=self.start_time,
                            duration_in_minutes=self.duration_in_minutes,
                            instructor_name=f"{get_instructors_name(available_instructors)}" if len(available_instructors) > 0 else "Not Assigned yet",
                            price=self.price,
                            currency=self.school.currency if self.price else ""
                        ),
                        lessons=[self],
                        school=self.school,
                        type="Admin",
                    )
            return True
        return False
    
    def unschedule_lesson(self):
        if not self.date and not self.start_time:
            return False
        self.date = None
        self.start_time = None
        self.end_time = None
        self.save()
        return True

class Voucher(models.Model):
    user = models.ForeignKey(UserAccount, on_delete=models.CASCADE, related_name="vouchers")  # Associated user
    is_paid = models.BooleanField(default=False)  # Indicates if the voucher has been paid
    packs = models.ManyToManyField(Pack, blank=True, related_name="vouchers")  
    lessons = models.ManyToManyField(Lesson, blank=True, related_name="vouchers")
    date = models.DateField(auto_now_add=True)  # Date of voucher creation
    expiration_date = models.DateField()  # Expiration date for the voucher
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='vouchers', blank=True, null=True)

    def __str__(self):
        pack_type = "Private Pack" if self.private_pack else "Group Pack"
        pack_name = self.private_pack or self.group_pack
        return f"Voucher for {self.user.username} ({pack_type}: {pack_name})"

    def is_expired(self):
        """Check if the voucher is expired."""
        return now().date() > self.expiration_date