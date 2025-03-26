# progress/serializers.py
from rest_framework import serializers
from lessons.models import Lesson
from users.models import Student
from .models import ProgressRecord, ProgressReport, SkillProficiency, Skill 

class SkillSerializer(serializers.ModelSerializer):
    class Meta:
        model = Skill
        fields = ['id', 'name']

class SkillProficiencySerializer(serializers.ModelSerializer):
    skill = SkillSerializer(read_only=True)

    class Meta:
        model = SkillProficiency
        fields = ['id', 'skill', 'level', 'last_updated']

class LessonSerializer(serializers.ModelSerializer):
    class Meta:
        model = Lesson
        fields = ['id', 'students_name', 'date', 'start_time']  # Adjust fields as needed

class ProgressRecordSerializer(serializers.ModelSerializer):
    lesson = LessonSerializer(read_only=True)
    skills = SkillProficiencySerializer(many=True, read_only=True)

    class Meta:
        model = ProgressRecord
        fields = ['id', 'date', 'lesson', 'notes', 'skills']

class ProgressReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProgressReport
        fields = ['id', 'period_start', 'period_end', 'summary', 'created_at']
