from django.db import models
from users.models import Student, Instructor
from lessons.models import Lesson
from sports.models import Sport
from django.utils.timezone import now

class Skill(models.Model):
    name = models.CharField(max_length=255, unique=True)
    description = models.TextField(blank=True, null=True)
    sport = models.ForeignKey(Sport, related_name='skills', on_delete=models.SET_NULL, blank=True, null=True)

    def __str__(self):
        return f"{self.name} ({self.sport})"


class Goal(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name="goals")
    skill = models.ForeignKey(Skill, on_delete=models.CASCADE, related_name="goals")
    description = models.TextField()
    start_datetime = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    target_date = models.DateField()
    level = models.PositiveIntegerField(default=1)  # Example: 1 = Beginner, 5 = Expert
    last_updated = models.DateTimeField(auto_now=True)
    is_completed = models.BooleanField(default=False)
    completed_date = models.DateField(null=True, blank=True)

    def mark_completed(self):
        self.is_completed = True
        self.completed_date = now().date()
        self.save()
    
    def mark_uncompleted(self):
        self.is_completed = False
        self.completed_date = None
        self.save()

    def extend_deadline(self, new_date):
        if new_date > self.target_date:
            self.target_date = new_date
            self.save()
            
    def update_level(self, level):
        self.level = level
        self.last_updated = now()
        self.save()


    @classmethod
    def get_active_goals(cls, student):
        return cls.objects.filter(student=student, is_completed=False)

    def __str__(self):
        status = "Completed" if self.is_completed else "In Progress"
        return f"Goal: {self.description} ({status})"

class ProgressRecord(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name="progress_records")
    lesson = models.ForeignKey(
        Lesson, 
        on_delete=models.CASCADE, 
        related_name="progress_records",
        null=True, 
        blank=True
    )
    date = models.DateField(auto_now_add=True)
    goals = models.ManyToManyField(Goal, related_name="progress_records", blank=True)
    notes = models.TextField(blank=True, null=True)

    def add_covered_skill(self, skill):
        self.skills.add(skill)
        self.save()

    def update_notes(self, new_notes):
        self.notes = new_notes
        self.save()

    def __str__(self):
        return f"Progress Record for {self.student} on {self.date}"

class ProgressReport(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name="progress_reports")
    period_start = models.DateField()
    period_end = models.DateField()
    summary = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    @classmethod
    def generate_report(cls, student, start_date, end_date):
        goals = Goal.objects.filter(
            student=student
        ).exclude(
            target_date__lt=start_date
        ).exclude(
            start_date__gt=end_date
        )

        progress_records = ProgressRecord.objects.filter(
            student=student,
            date__range=(start_date, end_date)
        )

        summary = f"Progress report for {student} from {start_date} to {end_date}\n\n"

        summary += "Goals:\n"
        for goal in goals:
            status = "Completed" if goal.is_completed else "In Progress"
            summary += f"- {goal.skill.name}: {goal.description} ({status})\n"

        summary += "\nProgress Records:\n"
        for record in progress_records:
            lesson_info = f"Lesson ID: {record.lesson.id}" if record.lesson else f"Lesson Not Assigned"
            summary += f"- Date: {record.date} | {lesson_info} | Skills Covered: {[skill.skill.name for skill in record.skills.all()]}\n"

        return cls.objects.create(
            student=student,
            period_start=start_date,
            period_end=end_date,
            summary=summary
        )


    @classmethod
    def get_latest_report(cls, student):
        return cls.objects.filter(student=student).latest('created_at')

    def __str__(self):
        return f"Progress Report for {self.student} ({self.period_start} to {self.period_end})"
