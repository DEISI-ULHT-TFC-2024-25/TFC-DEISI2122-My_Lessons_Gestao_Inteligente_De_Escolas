from django.test import TestCase
from django.utils.timezone import now
from datetime import date, timedelta, time, datetime
from schools.models import School
from users.models import Instructor, Student, UserAccount
from lessons.models import PrivateClass
from sports.models import Sport
from .models import Skill, SkillProficiency, Goal, ProgressRecord, ProgressReport

class SkillModelTests(TestCase):

    def setUp(self):
        self.sport = Sport.objects.create(name="Skateboarding")
        self.skill = Skill.objects.create(name="Ollie", sport=self.sport, description="Jump with the skateboard.")

    def test_skill_creation(self):
        self.assertEqual(self.skill.name, "Ollie")
        self.assertEqual(self.skill.sport, self.sport)
        self.assertEqual(self.skill.description, "Jump with the skateboard.")

class SkillProficiencyTests(TestCase):

    def setUp(self):
        user = UserAccount.objects.create(username="test_student")
        self.student = Student.objects.create(user=user, level=1, birthday=date(2000, 1, 1))
        self.sport = Sport.objects.create(name="Skateboarding")
        self.skill = Skill.objects.create(name="Ollie", sport=self.sport)
        self.proficiency = SkillProficiency.objects.create(student=self.student, skill=self.skill, level=2)

    def test_update_level(self):
        self.proficiency.update_level(4)
        self.assertEqual(self.proficiency.level, 4)
        self.assertAlmostEqual(self.proficiency.last_updated, now().date())

class GoalTests(TestCase):

    def setUp(self):
        user = UserAccount.objects.create(username="test_student")
        self.student = Student.objects.create(user=user, level=1, birthday=date(2000, 1, 1))
        self.sport = Sport.objects.create(name="Skateboarding")
        self.skill = Skill.objects.create(name="Kickflip", sport=self.sport)
        self.goal = Goal.objects.create(
            student=self.student,
            skill=self.skill,
            description="Land a kickflip",
            target_date=now().date() + timedelta(days=30),
        )

    def test_mark_completed(self):
        self.goal.mark_completed()
        self.assertTrue(self.goal.is_completed)

    def test_extend_deadline(self):
        new_date = self.goal.target_date + timedelta(days=10)
        self.goal.extend_deadline(new_date)
        self.assertEqual(self.goal.target_date, new_date)

    def test_get_active_goals(self):
        active_goals = Goal.get_active_goals(self.student)
        self.assertIn(self.goal, active_goals)

class ProgressRecordTests(TestCase):

    def setUp(self):
        self.school = School.objects.create(name="Test School")
        self.instructor = Instructor.objects.create(user=UserAccount.objects.create(username="instructor"))
        user = UserAccount.objects.create(username="test_student")
        self.student = Student.objects.create(user=user, level=1, birthday=date(2000, 1, 1))
        self.sport = Sport.objects.create(name="Skateboarding")
        self.skill = Skill.objects.create(name="Manual", sport=self.sport)
        self.proficiency = SkillProficiency.objects.create(student=self.student, skill=self.skill)
        self.private_class = PrivateClass.objects.create(
            date=date(2025,1,2),
            start_time=time(12, 0),
            end_time=time(13, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            instructor=self.instructor,
            school=self.school,
        )
        self.private_class.students.set([self.student])
        self.record = ProgressRecord.objects.create(student=self.student, lesson=self.private_class)

    def test_add_covered_skill(self):
        self.record.add_covered_skill(self.proficiency)
        self.assertIn(self.proficiency, self.record.skills.all())

    def test_update_notes(self):
        notes = "Improved balance and control."
        self.record.update_notes(notes)
        self.assertEqual(self.record.notes, notes)

class ProgressReportTests(TestCase):

    def setUp(self):
        self.school = School.objects.create(name="Test School")
        self.instructor = Instructor.objects.create(user=UserAccount.objects.create(username="instructor"))
        user = UserAccount.objects.create(username="test_student")
        self.student = Student.objects.create(user=user, level=1, birthday=date(2000, 1, 1))
        self.sport = Sport.objects.create(name="Skateboarding")
        self.skill = Skill.objects.create(name="Ollie", sport=self.sport)
        self.goal = Goal.objects.create(
            student=self.student,
            skill=self.skill,
            description="Land a proper Ollie",
            target_date=now().date() + timedelta(days=30),
        )
        self.goal2 = Goal.objects.create(
            student=self.student,
            start_date=date(2024,1,2),
            skill=self.skill,
            description="Land a proper Kickflip",
            target_date=date(2024,1,5),
        )
        self.goal3 = Goal.objects.create(
            student=self.student,
            start_date=date(2024,1,2),
            skill=self.skill,
            description="Land a proper 360 Flip",
            target_date=date(2026,1,5),
        )
        self.private_class = PrivateClass.objects.create(
            date=date(2025,1,2),
            start_time=time(12, 0),
            end_time=time(13, 0),
            duration_in_minutes=60,
            class_number=1,
            price=50.00,
            instructor=self.instructor,
            school=self.school,
        )
        self.private_class.students.set([self.student])
        self.record = ProgressRecord.objects.create(student=self.student, lesson=self.private_class)

    def test_generate_report(self):
        report = ProgressReport.generate_report(
            student=self.student, 
            start_date=now().date() - timedelta(days=1), 
            end_date=now().date() + timedelta(days=1)
        )
        self.assertEqual(report.student, self.student)
        self.assertIn("Land a proper Ollie", report.summary)
        self.assertIn("Land a proper 360 Flip", report.summary)
        self.assertNotIn("Land a proper Kickflip", report.summary)
        self.assertIn("Lesson ID", report.summary)

    def test_get_latest_report(self):
        report = ProgressReport.generate_report(
            student=self.student, 
            start_date=now().date() - timedelta(days=1), 
            end_date=now().date() + timedelta(days=1)
        )
        latest_report = ProgressReport.get_latest_report(self.student)
        self.assertEqual(report, latest_report)