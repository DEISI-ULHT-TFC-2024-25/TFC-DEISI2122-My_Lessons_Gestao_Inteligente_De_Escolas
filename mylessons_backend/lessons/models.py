from datetime import timedelta, datetime
from django.db import models
from events.models import Activity
from notifications.models import Notification
from users.models import Discount, Unavailability, UserAccount, Student, Instructor
from users.utils import get_users_name, get_students_ids, get_instructors_name
from django.db.models import Q
from django.utils.timezone import now

class GroupPack(models.Model):
    date = models.DateField()
    type = models.CharField(max_length=50, default='Group')
    number_of_classes = models.PositiveIntegerField()
    number_of_classes_left = models.PositiveIntegerField()
    duration_in_minutes = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_done = models.BooleanField(default=False)
    is_paid = models.BooleanField(default=False)
    is_suspended = models.BooleanField(default=False)
    debt = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name="group_packs")
    finished_date = models.DateField(blank=True, null=True)
    expiration_date = models.DateField(blank=True, null=True)
    parents = models.ManyToManyField(UserAccount, blank=True, related_name="group_packs")
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='group_packs', blank=True, null=True)
    sport = models.ForeignKey('sports.Sport', related_name='group_packs', on_delete=models.SET_NULL, blank=True, null=True)

    def __str__(self):
        return f"Group Pack for {self.student} - {self.date}"
    
    def get_number_of_lessons_remaining(self):
        return self.tickets.filter(is_used=False).count()

    def get_number_of_unscheduled_lessons(self):
        return self.tickets.filter(
            is_used=False,
            group_class__isnull=True
        ).count()


    @classmethod
    def book_new_pack(cls, student, school, date, number_of_classes, duration_in_minutes, price, payment, discount_id = None):
        """
        Books a new private pack, creates the necessary associations, and sends notifications.
        """
        if not date:
            date = now().date()

        parents = list(student.parents.all())

        # Create the private pack
        pack = cls.objects.create(
            school=school,
            date=date,
            number_of_classes=number_of_classes,
            number_of_classes_left=number_of_classes,
            duration_in_minutes=duration_in_minutes,
            price=price,
            student=student,
            debt=price
        )

        # TODO expiration date

        pack.parents.set(parents)

        pack.create_group_tickets()

        if payment:
            pack.update_debt(payment=payment)


        # Notify parents
        for parent in parents:
            Notification.create_notification(
                user=parent,
                subject=school.get_notification_template("group_pack_purchased_subject_parent").format(
                    student=student
                ),
                message=school.get_notification_template("group_pack_purchased_message_parent").format(
                    parent_name=parent.first_name,
                    student=student,
                    number_of_classes=number_of_classes,
                    duration_minutes=duration_in_minutes,
                    start_date=date,
                    total_price=price,
                    currency=school.currency,
                    school_name=school.name
                ),
                group_packs=[pack],
                school=school
            )

        # Notify school admin
        for admin in school.admins.all():
            Notification.create_notification(
                user=admin,
                subject=school.get_notification_template("group_pack_purchased_subject_admin"),
                message=school.get_notification_template("group_pack_purchased_message_admin").format(
                    student=student,
                    number_of_classes=number_of_classes,
                    duration_minutes=duration_in_minutes,
                    start_date=date,
                    total_price=price,
                    currency=school.currency
                ),
                group_packs=[pack],
                school=school
            )
        
        if discount_id and pack:
            discount = Discount.objects.filter(id=discount_id)
            if discount:
                discount.delete()
        return pack

    def create_group_tickets(self):
        for i in range(self.number_of_classes):
            class_ticket = self.tickets.create(
                student=self.student,
            )
            self.tickets.add(class_ticket)
        self.save()

    def mark_done(self):
        self.is_done = True
        self.save()

    def mark_undone(self):
        self.is_done = False
        self.save()

    def update_debt(self, payment):
        self.debt -= payment
        if self.debt <= 0:
            self.is_paid = True
        self.save()

    def suspend_pack(self):
        self.is_suspended = True
        self.save()

    def resume_pack(self):
        self.is_suspended = False
        self.save()

class GroupClass(models.Model):
    date = models.DateField()
    start_time = models.TimeField(null=True, blank = True)
    end_time = models.TimeField(null=True, blank = True)
    duration_in_minutes = models.PositiveIntegerField()
    level = models.PositiveIntegerField()
    minimum_age = models.PositiveIntegerField()
    maximum_age = models.PositiveIntegerField()
    maximum_number_of_students = models.PositiveIntegerField()
    is_done = models.BooleanField(default=False)
    students = models.ManyToManyField(Student, related_name="group_classes")
    instructors = models.ManyToManyField(Instructor, related_name="group_classes")
    location = models.ForeignKey('locations.Location', on_delete=models.SET_NULL, null=True, related_name="group_classes", blank=True)
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='group_classes', blank=True, null=True)
    type = models.CharField(max_length=50, default='Group')
    sport = models.ForeignKey('sports.Sport', related_name='group_classes', on_delete=models.SET_NULL, blank=True, null=True)

    def __str__(self):
        return f"Group Class on {self.date} at {self.start_time} - Level {self.level}"
    
    def get_instructors_name(self):
        return get_instructors_name(self.instructors.all())


    def mark_done(self):
        self.is_done = True
        # mark all of the tickets as done
        for ticket in self.class_tickets.all():
            ticket.mark_done()
        self.save()

    def mark_undone(self):
        self.is_done = False
        self.save()

    def is_full(self):
        return self.students.count() >= self.maximum_number_of_students

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
        
         # Overlapping unavailabilities
        overlapping_unavailabilities = Unavailability.objects.filter(
            instructor=instructor,
            date=self.date,
        ).filter(
            start_time__lt=self.end_time,
            end_time__gt=self.start_time,
        )

        # Overlapping private classes
        overlapping_private_classes = PrivateClass.objects.filter(
            instructor=instructor,
            date=self.date,
        ).filter(
            start_time__lt=self.end_time,
            end_time__gt=self.start_time,
        )

        # Overlapping group classes
        overlapping_group_classes = GroupClass.objects.filter(
            instructors=instructor,
            date=self.date,
        ).filter(
            start_time__lt=self.end_time,
            end_time__gt=self.start_time,
        )

        overlapping_activities = Activity.objects.filter(
            date=self.date,
            start_time__lt=self.end_time,
            end_time__gt=self.start_time,
        )
            
        if not (overlapping_unavailabilities or overlapping_private_classes or overlapping_group_classes) or overlapping_activities:
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

class ClassTicket(models.Model):
    is_used = models.BooleanField(default=False)
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name="class_tickets")
    group_class = models.ForeignKey(GroupClass, on_delete=models.CASCADE, related_name="class_tickets", blank=True, null=True)
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='class_tickets', blank=True, null=True)
    pack = models.ForeignKey(GroupPack, on_delete=models.CASCADE, related_name='tickets', blank=True, null=True)
    sport = models.ForeignKey('sports.Sport', related_name='group_tickets', on_delete=models.SET_NULL, blank=True, null=True)
    ticket_number = models.PositiveIntegerField(null=True, blank=True)

    def __str__(self):
        status = "Used" if self.is_used else "Not Used"
        return f"Class Ticket for {self.student} ({status}) in {self.group_class}"

    
    def mark_done(self):
        self.is_used = True
        # TODO notify parents
        self.pack.number_of_classes_left -= 1
        if self.pack.number_of_classes_left == 0:
            self.pack.mark_done()
        self.save()

    def mark_undone(self):
        self.is_used = False
        # TODO notify parents
        self.pack.number_of_classes_left += 1
        if self.pack.number_of_classes_left == 1 and self.pack.is_done:
            self.pack.mark_undone()
        self.save()
    
class PrivatePack(models.Model):
    date = models.DateField()
    type = models.CharField(max_length=50, default='Private')
    number_of_classes = models.PositiveIntegerField()
    duration_in_minutes = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_done = models.BooleanField(default=False)
    is_paid = models.BooleanField(default=False)
    is_suspended = models.BooleanField(default=False)
    debt = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    students = models.ManyToManyField('users.Student', related_name="private_packs")
    finished_date = models.DateField(null=True, blank=True)
    expiration_date = models.DateField(null=True, blank=True)
    parents = models.ManyToManyField(UserAccount, blank=True, related_name="private_packs")
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='private_packs', blank=True, null=True)
    instructor = models.ForeignKey('users.Instructor', on_delete=models.CASCADE, related_name='private_packs', blank=True, null=True)
    sport = models.ForeignKey('sports.Sport', related_name='private_packs', on_delete=models.SET_NULL, blank=True, null=True)

    def __str__(self):
        return f"Private Pack for {self.students} starting on {self.date}"
    
    def get_number_of_lessons_remaining(self):
        return self.classes.filter(is_done=False).count()

    def get_number_of_unscheduled_lessons(self):
        today = now().date()

        return self.classes.filter(
            is_done=False
        ).filter(
            Q(date__lt=today) |
            Q(date=None) |
            Q(start_time=None)
        ).count() 
    
    def get_students_name(self):
        return get_users_name(self.students.all())
    
    def get_students_ids(self):
        return get_students_ids(self.students.all())


    @classmethod
    def book_new_pack(cls, students, school, date, number_of_classes, duration_in_minutes, instructor, price, payment, discount_id = None):
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

        # Create the private pack
        pack = cls.objects.create(
            school=school,
            date=date,
            number_of_classes=number_of_classes,
            instructor=instructor,
            duration_in_minutes=duration_in_minutes,
            price=price,
            debt=price
        )

        # TODO expiration date

        pack.students.set(students)
        pack.parents.set(parents)

        pack.create_private_classes()

        if payment:
            pack.update_debt(payment=payment)

        # Collect student names for notification messages
        student_names = ", ".join([f"{student}" for student in students])

        # Notify parents
        for parent in parents:
            Notification.create_notification(
                user=parent,
                subject=school.get_notification_template("private_pack_purchased_subject_parent").format(
                    students=student_names
                ),
                message=school.get_notification_template("private_pack_purchased_message_parent").format(
                    parent_name=parent.first_name,
                    students=student_names,
                    number_of_classes=number_of_classes,
                    duration_minutes=duration_in_minutes,
                    instructor_name=f"{instructor.user.first_name} {instructor.user.last_name}" if instructor else "Not Assigned yet",
                    start_date=date,
                    total_price=price,
                    currency=school.currency,
                    school_name=school.name
                ),
                private_packs=[pack],
                school=school
            )

        # Notify instructor
        if instructor:
            Notification.create_notification(
                user=instructor.user,
                subject=school.get_notification_template("private_pack_purchased_subject_instructor"),
                message=school.get_notification_template("private_pack_purchased_message_instructor").format(
                    instructor_name=f"{instructor.user.first_name} {instructor.user.last_name}",
                    students=student_names,
                    number_of_classes=number_of_classes,
                    duration_minutes=duration_in_minutes,
                    start_date=date
                ),
                private_packs=[pack],
                school=school
            )

        # Notify school admin
        for admin in school.admins.all():
            Notification.create_notification(
                user=admin,
                subject=school.get_notification_template("private_pack_purchased_subject_admin"),
                message=school.get_notification_template("private_pack_purchased_message_admin").format(
                    students=student_names,
                    number_of_classes=number_of_classes,
                    duration_minutes=duration_in_minutes,
                    instructor_name=f"{instructor.user.first_name} {instructor.user.last_name}" if instructor else "Not Assigned",
                    start_date=date,
                    total_price=price,
                    currency=school.currency
                ),
                private_packs=[pack],
                school=school
            )
        
        if discount_id and pack:
            discount = Discount.objects.filter(id=discount_id)
            if discount:
                discount.delete()
        return pack


    def create_private_classes(self):
        for i in range(self.number_of_classes):
            private_class = PrivateClass.objects.create(
                class_number=i + 1,
                price=self.price/self.number_of_classes,
                instructor=self.instructor,
                duration_in_minutes=self.duration_in_minutes,
                school=self.school,
            )
            private_class.students.set(self.students.all())
            self.classes.add(private_class)
        self.save()

    def mark_done(self):
        self.is_done = True
        self.save()

    def update_debt(self, payment):
        self.debt -= payment
        if self.debt <= 0:
            self.is_paid = True
        self.save()

    def suspend(self):
        self.is_suspended = True
        self.save()

    def add_class(self, private_class):
        if not self.is_done:
            self.classes.add(private_class)
            self.save()
        else:
            raise ValueError("Cannot add classes to a completed pack.")

    def remaining_classes(self):
        return self.number_of_classes - self.classes.count()

class PrivateClass(models.Model):
    id = models.AutoField(primary_key=True)
    date = models.DateField(null=True, blank = True)
    start_time = models.TimeField(null=True, blank = True)
    end_time = models.TimeField(null=True, blank = True)
    duration_in_minutes = models.PositiveIntegerField()
    class_number = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_done = models.BooleanField(default=False)
    equipments = models.ManyToManyField('equipment.Equipment', related_name="private_classes", blank=True)
    extra_students = models.ManyToManyField('users.Student', related_name="extra_private_classes", blank=True)
    number_of_extra_students = models.PositiveIntegerField(null=True, blank=True)
    students = models.ManyToManyField('users.Student', related_name="private_classes")
    instructor = models.ForeignKey(Instructor, on_delete=models.SET_NULL, null=True, blank=True, related_name="instructor_private_classes")
    location = models.ForeignKey('locations.Location', on_delete=models.SET_NULL, null=True, blank=True, related_name="private_classes")
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='private_classes', blank=True, null=True)
    pack = models.ForeignKey(PrivatePack, on_delete=models.CASCADE, related_name='classes', blank=True, null=True)
    type = models.CharField(max_length=50, default='Private')
    sport = models.ForeignKey('sports.Sport', related_name='private_classes', on_delete=models.SET_NULL, blank=True, null=True)

    def __str__(self):
        return f"Private Class {self.class_number} on {self.date} at {self.start_time}"
    
    def get_students_name(self):
        return get_users_name(self.students.all())
    
    def get_students_ids(self):
        return get_students_ids(self.students.all())
    
    def get_extra_costs(self):
        """
        Calculates additional costs for extra students and equipment usage.
        Returns a dictionary with detailed costs and total price.
        """
        if not self.school:
            return {}

        extra_costs = {}
        total_price = 0

        # Fetch school extra prices
        extra_prices = self.school.extra_prices or {}

        # Calculate extra student costs
        if self.number_of_extra_students:
            price_per_student = extra_prices.get("extra_students", 10)  # Default price: 10 if not set
            total_student_price = self.number_of_extra_students * price_per_student
            extra_costs["extra_students"] = f"{self.number_of_extra_students}x{price_per_student}"
            total_price += total_student_price

        # Calculate equipment costs using names
        equipment_count = {}
        for equipment in self.equipments.all():
            equipment_price = extra_prices.get(equipment.name, 0)  # Default price: 0 if not set
            if equipment_price > 0:
                if equipment.name in equipment_count:
                    equipment_count[equipment.name] += 1
                else:
                    equipment_count[equipment.name] = 1

        # Add equipment costs to extra_costs
        for equipment_name, count in equipment_count.items():
            unit_price = extra_prices.get(equipment_name, 0)
            extra_costs[equipment_name] = f"{count}x{unit_price}"
            total_price += count * unit_price

        # Add total price to the dictionary
        extra_costs["total_price"] = total_price

        return extra_costs
    
    def is_available(self, instructor, date, start_time):

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
            overlapping_private_classes = PrivateClass.objects.filter(
                instructor=instructor,
                date=date,
            ).filter(
                start_time__lt=end_time,
                end_time__gt=start_time,
            ).exclude(id=self.id)

            # Overlapping group classes
            overlapping_group_classes = GroupClass.objects.filter(
                instructors=instructor,
                date=date,
            ).filter(
                start_time__lt=end_time,
                end_time__gt=start_time,
            )

            overlapping_activities = Activity.objects.filter(
                date=date,
                start_time__lt=end_time,
                end_time__gt=start_time,
            )
            
            if not (overlapping_unavailabilities or overlapping_private_classes or overlapping_group_classes or overlapping_activities):
                return True, i
        return False, instructor
    
    def can_still_reschedule(self):
        """
        Determines if a lesson can still be rescheduled based on the school's reschedule time limit.
        """
        if self.date and self.start_time and self.school:
            lesson_datetime = datetime.combine(self.date, self.start_time)
            time_difference = lesson_datetime - datetime.now()

            # Convert time difference into hours
            number_of_hours = time_difference.total_seconds() / 3600

            if number_of_hours < self.school.reschedule_time_limit:
                return False
        return True

    def schedule_lesson(self, date, time):

        is_available, instructor = self.is_available(self.instructor, date, time)

        if is_available:
            if not self.instructor:
                self.instructor = instructor
            self.date = date
            self.start_time = time
            self.end_time = (datetime.combine(self.date, time) + timedelta(minutes=self.duration_in_minutes)).time()
            self.save()
            if self.school:
                self.school.add_scheduled_lesson_to_attendance(self.date, self.id, self.type, True)
            
                # Notify parents
                for parent in self.pack.parents.all():
                    Notification.create_notification(
                        user=parent,
                        subject=self.school.get_notification_template("private_class_scheduled_subject_parent").format(
                            students=self.students
                        ),
                        message=self.school.get_notification_template("private_class_scheduled_message_parent").format(
                            parent_name=parent.first_name,
                            students=self.students,
                            class_number=self.class_number,
                            number_of_classes=self.pack.number_of_classes,
                            date=date,
                            start_time=self.start_time,
                            duration_in_minutes=self.duration_in_minutes,
                            instructor_name=f"{instructor.user.first_name} {instructor.user.last_name}" if instructor else "Not Assigned yet"
                        ),
                        private_classes=[self],
                        school=self.school
                    )

                # Notify instructor
                if instructor:
                    Notification.create_notification(
                        user=instructor.user,
                        subject=self.school.get_notification_template("private_class_scheduled_subject_instructor").format(
                            students=self.students
                        ),
                        message=self.school.get_notification_template("private_class_scheduled_message_instructor").format(
                            instructor_name=f"{instructor.user.first_name} {instructor.user.last_name}",
                            students=self.students,
                            class_number=self.class_number,
                            number_of_classes=self.pack.number_of_classes,
                            date=date,
                            start_time=self.start_time,
                            duration_in_minutes=self.duration_in_minutes
                        ),
                        private_classes=[self],
                        school=self.school
                    )

                # Notify school admin
                for admin in self.school.admins.all():
                    Notification.create_notification(
                        user=admin,
                        subject=self.school.get_notification_template("private_class_scheduled_subject_admin").format(
                            students=self.students
                        ),
                        message=self.school.get_notification_template("private_class_scheduled_message_admin").format(
                            students=self.students,
                            class_number=self.class_number,
                            number_of_classes=self.pack.number_of_classes,
                            date=date,
                            start_time=self.start_time,
                            duration_in_minutes=self.duration_in_minutes,
                            instructor_name=f"{instructor.user.first_name} {instructor.user.last_name}" if instructor else "Not Assigned",
                            price=self.price,
                            currency=self.school.currency if self.price else ""
                        ),
                        private_classes=[self],
                        school=self.school
                    )

            return True
        return False
    
    def unschedule_lesson(self):
        if not self.date and not self.start_time:
            return False
        self.date = None
        self.start_time = None
        self.end_time = None
        if self.school:
            self.school.add_scheduled_lesson_to_attendance(self.date, self.id, self.type, True)
            self.save()
        return True
        

class Voucher(models.Model):
    user = models.ForeignKey(UserAccount, on_delete=models.CASCADE, related_name="vouchers")  # Associated user
    is_paid = models.BooleanField(default=False)  # Indicates if the voucher has been paid
    private_pack = models.ForeignKey(PrivatePack, on_delete=models.SET_NULL, null=True, blank=True, related_name="vouchers")  # Linked private pack
    group_pack = models.ForeignKey(GroupPack, on_delete=models.SET_NULL, null=True, blank=True, related_name="vouchers")  # Linked group pack
    date = models.DateField(auto_now_add=True)  # Date of voucher creation
    expiration_date = models.DateField()  # Expiration date for the voucher
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='vouchers', blank=True, null=True)

    def __str__(self):
        pack_type = "Private Pack" if self.private_pack else "Group Pack"
        pack_name = self.private_pack or self.group_pack
        return f"Voucher for {self.user.username} ({pack_type}: {pack_name})"

    def is_expired(self):
        """Check if the voucher is expired."""
        from django.utils.timezone import now
        return now().date() > self.expiration_date