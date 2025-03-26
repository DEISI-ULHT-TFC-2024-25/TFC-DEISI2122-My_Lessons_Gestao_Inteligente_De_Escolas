# progress/views.py
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status, permissions
from django.shortcuts import get_object_or_404
from .models import ProgressRecord, ProgressReport
from .serializers import ProgressRecordSerializer, ProgressReportSerializer

# Helper: assume each user has a related Student instance (e.g., request.user.student)
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
    
    # Optionally, if more than one record can exist per lesson, you may choose the latest one.
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
