from django.db import models

class ActivityModel(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    photo = models.ImageField(upload_to='activity_photos/', blank=True, null=True)
    location = models.ForeignKey('locations.Location', on_delete=models.CASCADE, related_name='activities')
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='activity_models', blank=True, null=True)

    def __str__(self):
        return self.name

class Activity(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    student_price = models.DecimalField(max_digits=10, decimal_places=2)
    monitor_price = models.DecimalField(max_digits=10, decimal_places=2)
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField(null=True, blank=True)
    duration_in_minutes = models.PositiveIntegerField()
    students = models.ManyToManyField('users.Student', related_name='activities')
    instructors = models.ManyToManyField('users.Instructor', related_name='activities')
    monitors = models.ManyToManyField('users.UserAccount', related_name='activities')
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='activities', blank=True, null=True)
    activity_model = models.ForeignKey(ActivityModel, on_delete=models.CASCADE, related_name='activities', blank=True, null=True 
                                       )
    def __str__(self):
        return f"{self.name} on {self.date} at {self.start_time}"
    
    def add_instructor(self, instructor):
        from lessons.models import GroupClass, PrivateClass
        from users.models import Unavailability
   
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

class CampOrder(models.Model):
    user = models.ForeignKey('users.UserAccount', on_delete=models.CASCADE, related_name='camp_orders')
    student = models.ForeignKey('users.Student', on_delete=models.CASCADE, related_name='camp_orders')
    is_half_paid = models.BooleanField(default=False)
    is_fully_paid = models.BooleanField(default=False)
    date = models.DateField()
    time = models.TimeField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    activities = models.ManyToManyField(Activity, related_name='camp_orders')
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='camp_orders', blank=True, null=True)

    def __str__(self):
        return f"CampOrder by {self.user} for {self.student} on {self.date} at {self.time}"

class Camp(models.Model):
    name = models.CharField(max_length=255)
    start_date = models.DateField()
    end_date = models.DateField()
    is_finished = models.BooleanField(default=False)
    activities = models.ManyToManyField(Activity, related_name="camps")
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='camps', blank=True, null=True)

    def __str__(self):
        return self.name

class BirthdayParty(models.Model):
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField(null=True, blank=True)
    duration_in_minutes = models.PositiveIntegerField()
    activities = models.ManyToManyField(Activity, related_name='birthday_parties')
    student = models.ForeignKey('users.Student', on_delete=models.CASCADE, related_name='birthday_parties')
    number_of_guests = models.PositiveIntegerField()
    equipment = models.ManyToManyField('equipment.Equipment', related_name='birthday_parties')
    price = models.DecimalField(max_digits=10, decimal_places=2)

    def __str__(self):
        return f"Birthday Party for {self.student} on {self.date} at {self.starting_time} with {self.number_of_guests} guests"
