from rest_framework import serializers
from .models import ProgressRecord, ProgressReport, SkillProficiency
from lessons.models import Lesson  # adjust the import if needed

class SkillProficiencySerializer(serializers.ModelSerializer):
    class Meta:
        model = SkillProficiency
        fields = ['id', 'skill', 'level', 'last_updated']

class LessonSerializer(serializers.ModelSerializer):
    class Meta:
        model = Lesson
        fields = ['id', 'title']  # include additional fields as needed

class ProgressRecordSerializer(serializers.ModelSerializer):
    lesson = LessonSerializer(read_only=True)
    skills = SkillProficiencySerializer(many=True, read_only=True)

    class Meta:
        model = ProgressRecord
        fields = ['id', 'date', 'lesson', 'skills', 'notes']

class ProgressReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProgressReport
        fields = ['id', 'period_start', 'period_end', 'summary', 'created_at']
