from rest_framework import serializers
from .models import Skill, SkillProficiency, Goal, ProgressRecord, ProgressReport

# Skill Serializer
class SkillSerializer(serializers.ModelSerializer):
    class Meta:
        model = Skill
        fields = ['id', 'name', 'description', 'sport']


# Skill Proficiency Serializer
class SkillProficiencySerializer(serializers.ModelSerializer):
    # Nested read-only representation of the skill
    skill = SkillSerializer(read_only=True)
    # Write-only field for setting the skill via its ID
    skill_id = serializers.PrimaryKeyRelatedField(
        queryset=Skill.objects.all(), source='skill', write_only=True
    )
    
    class Meta:
        model = SkillProficiency
        fields = ['id', 'student', 'skill', 'skill_id', 'level', 'last_updated']


# Goal Serializer
class GoalSerializer(serializers.ModelSerializer):
    # Nested read-only representation of the skill
    skill = SkillSerializer(read_only=True)
    # Write-only field for setting the skill via its ID
    skill_id = serializers.PrimaryKeyRelatedField(
        queryset=Skill.objects.all(), source='skill', write_only=True
    )
    
    class Meta:
        model = Goal
        fields = [
            'id', 'student', 'skill', 'skill_id', 
            'description', 'start_date', 'target_date', 
            'is_completed', 'completed_date'
        ]


# Progress Record Serializer
class ProgressRecordSerializer(serializers.ModelSerializer):
    # Nested representation for the many-to-many field to skill proficiencies
    skills = SkillProficiencySerializer(many=True, read_only=True)
    # Write-only field to allow updating the many-to-many field via list of IDs
    skills_ids = serializers.PrimaryKeyRelatedField(
        many=True, queryset=SkillProficiency.objects.all(), source='skills', write_only=True
    )
    
    class Meta:
        model = ProgressRecord
        fields = ['id', 'student', 'lesson', 'date', 'skills', 'skills_ids', 'notes']


# Progress Report Serializer
class ProgressReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProgressReport
        fields = ['id', 'student', 'period_start', 'period_end', 'summary', 'created_at']
