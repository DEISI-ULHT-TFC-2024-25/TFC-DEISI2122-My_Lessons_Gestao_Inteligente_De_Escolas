from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.utils.dateparse import parse_date
from django.utils.timezone import now

# Import your models
from .models import Skill, SkillProficiency, Goal, ProgressRecord, ProgressReport
# Import your serializers (make sure these are defined appropriately)
from .serializers import (
    SkillSerializer, 
    SkillProficiencySerializer, 
    GoalSerializer, 
    ProgressRecordSerializer, 
    ProgressReportSerializer
)

class SkillViewSet(viewsets.ModelViewSet):
    """
    Provides CRUD operations for Skills.
    """
    queryset = Skill.objects.all()
    serializer_class = SkillSerializer


class SkillProficiencyViewSet(viewsets.ModelViewSet):
    """
    Provides CRUD operations for Skill Proficiencies.
    """
    queryset = SkillProficiency.objects.all()
    serializer_class = SkillProficiencySerializer
    
    @action(detail=True, methods=['post'])
    def update_level(self, request, pk=None):
        """
        Custom endpoint to update the proficiency level.
        Expects a 'level' in the request data.
        """
        proficiency = self.get_object()
        level = request.data.get('level')
        if level is None:
            return Response({'error': 'Level not provided'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            level = int(level)
            if not (1 <= level <= 5):
                return Response({'error': 'Level must be between 1 and 5'}, status=status.HTTP_400_BAD_REQUEST)
            proficiency.update_level(level)
            serializer = self.get_serializer(proficiency)
            return Response(serializer.data)
        except ValueError:
            return Response({'error': 'Invalid level provided'}, status=status.HTTP_400_BAD_REQUEST)


class GoalViewSet(viewsets.ModelViewSet):
    """
    Provides CRUD operations for Goals.
    """
    queryset = Goal.objects.all()
    serializer_class = GoalSerializer

    @action(detail=True, methods=['post'])
    def mark_completed(self, request, pk=None):
        """
        Marks a goal as completed.
        """
        goal = self.get_object()
        goal.mark_completed()
        serializer = self.get_serializer(goal)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def mark_uncompleted(self, request, pk=None):
        """
        Reverts a goal to 'in progress'.
        """
        goal = self.get_object()
        goal.mark_uncompleted()
        serializer = self.get_serializer(goal)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def extend_deadline(self, request, pk=None):
        """
        Extends the target date of a goal.
        Expects a 'new_date' in the request data formatted as YYYY-MM-DD.
        """
        goal = self.get_object()
        new_date_str = request.data.get('new_date')
        if not new_date_str:
            return Response({'error': 'New date not provided'}, status=status.HTTP_400_BAD_REQUEST)
        new_date = parse_date(new_date_str)
        if not new_date:
            return Response({'error': 'Invalid date format. Use YYYY-MM-DD.'}, status=status.HTTP_400_BAD_REQUEST)
        if new_date <= goal.target_date:
            return Response({'error': 'New date must be after the current target date'}, status=status.HTTP_400_BAD_REQUEST)
        goal.extend_deadline(new_date)
        serializer = self.get_serializer(goal)
        return Response(serializer.data)


class ProgressRecordViewSet(viewsets.ModelViewSet):
    """
    Provides CRUD operations for Progress Records.
    """
    queryset = ProgressRecord.objects.all()
    serializer_class = ProgressRecordSerializer

    @action(detail=True, methods=['post'])
    def add_covered_skill(self, request, pk=None):
        """
        Adds a covered skill (by skill proficiency ID) to a progress record.
        """
        progress_record = self.get_object()
        skill_proficiency_id = request.data.get('skill_proficiency_id')
        if not skill_proficiency_id:
            return Response({'error': 'skill_proficiency_id not provided'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            from .models import SkillProficiency  # In case not imported already
            skill_proficiency = SkillProficiency.objects.get(pk=skill_proficiency_id)
            progress_record.add_covered_skill(skill_proficiency)
            serializer = self.get_serializer(progress_record)
            return Response(serializer.data)
        except SkillProficiency.DoesNotExist:
            return Response({'error': 'Skill proficiency not found'}, status=status.HTTP_404_NOT_FOUND)
    
    @action(detail=True, methods=['post'])
    def update_notes(self, request, pk=None):
        """
        Updates the notes on a progress record.
        """
        progress_record = self.get_object()
        new_notes = request.data.get('notes')
        if new_notes is None:
            return Response({'error': 'Notes not provided'}, status=status.HTTP_400_BAD_REQUEST)
        progress_record.update_notes(new_notes)
        serializer = self.get_serializer(progress_record)
        return Response(serializer.data)


class ProgressReportViewSet(viewsets.ModelViewSet):
    """
    Provides CRUD operations for Progress Reports.
    """
    queryset = ProgressReport.objects.all()
    serializer_class = ProgressReportSerializer

    @action(detail=False, methods=['post'])
    def generate_report(self, request):
        """
        Custom endpoint to generate a progress report.
        Expects 'student_id', 'start_date', and 'end_date' in the request data.
        """
        student_id = request.data.get('student_id')
        start_date = request.data.get('start_date')
        end_date = request.data.get('end_date')
        if not student_id or not start_date or not end_date:
            return Response(
                {'error': 'student_id, start_date, and end_date are required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            from users.models import Student
            student = Student.objects.get(pk=student_id)
        except Student.DoesNotExist:
            return Response({'error': 'Student not found'}, status=status.HTTP_404_NOT_FOUND)
        
        report = ProgressReport.generate_report(student, start_date, end_date)
        serializer = self.get_serializer(report)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def latest_report(self, request):
        """
        Returns the latest progress report for a student.
        Expects 'student_id' as a query parameter.
        """
        student_id = request.query_params.get('student_id')
        if not student_id:
            return Response({'error': 'student_id is required as a query parameter'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            from users.models import Student
            student = Student.objects.get(pk=student_id)
        except Student.DoesNotExist:
            return Response({'error': 'Student not found'}, status=status.HTTP_404_NOT_FOUND)
        report = ProgressReport.get_latest_report(student)
        serializer = self.get_serializer(report)
        return Response(serializer.data)
