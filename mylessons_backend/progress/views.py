# progress/views.py
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status, permissions
from django.shortcuts import get_object_or_404
from .models import ProgressRecord, ProgressReport, SkillProficiency
from .serializers import ProgressRecordSerializer, ProgressReportSerializer, SkillProficiencySerializer

def get_student_from_user(user):
    try:
        return user.student
    except AttributeError:
        return None

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def progress_record_detail(request, lesson_id):
    """
    Returns the progress record for the given lesson_id and logged-in student.
    """
    student = get_student_from_user(request.user)
    if not student:
        return Response({'detail': 'Student profile not found.'}, status=status.HTTP_404_NOT_FOUND)
    progress_record = ProgressRecord.objects.filter(lesson__id=lesson_id, student=student).order_by('-date').first()
    if not progress_record:
        return Response({'detail': 'No progress record found for this lesson.'}, status=status.HTTP_404_NOT_FOUND)
    serializer = ProgressRecordSerializer(progress_record)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def progress_records_list(request):
    """
    Returns all progress records for the logged-in student.
    """
    student = get_student_from_user(request.user)
    if not student:
        return Response({'detail': 'Student profile not found.'}, status=status.HTTP_404_NOT_FOUND)
    records = ProgressRecord.objects.filter(student=student).order_by('-date')
    serializer = ProgressRecordSerializer(records, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def progress_reports_list(request):
    """
    Returns all progress reports for the logged-in student.
    """
    student = get_student_from_user(request.user)
    if not student:
        return Response({'detail': 'Student profile not found.'}, status=status.HTTP_404_NOT_FOUND)
    reports = ProgressReport.objects.filter(student=student).order_by('-created_at')
    serializer = ProgressReportSerializer(reports, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['PATCH'])
@permission_classes([permissions.IsAuthenticated])
def update_progress_record(request, record_id):
    """
    Allows an instructor to update a student's progress record.
    For example, updating the "notes" field.
    """
    # You may add extra permission checks to ensure request.user is an instructor.
    progress_record = get_object_or_404(ProgressRecord, id=record_id)
    serializer = ProgressRecordSerializer(progress_record, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['PATCH'])
@permission_classes([permissions.IsAuthenticated])
def update_skill_proficiency(request, proficiency_id):
    """
    Update a student's skill proficiency (e.g., level) after a lesson.
    """
    skill_proficiency = get_object_or_404(SkillProficiency, id=proficiency_id)
    serializer = SkillProficiencySerializer(skill_proficiency, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
