from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils.dateparse import parse_date
from rest_framework.permissions import IsAuthenticated
from .models import ProgressRecord, ProgressReport
from .serializers import ProgressRecordSerializer, ProgressReportSerializer

# List/Create progress records for the current student
class ProgressRecordListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = ProgressRecordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Assumes that request.user has a related student profile.
        student = self.request.user.student
        return ProgressRecord.objects.filter(student=student).order_by('-date')

    def perform_create(self, serializer):
        student = self.request.user.student
        serializer.save(student=student)

# Get the latest progress report for the current student.
class ProgressReportLatestAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        student = request.user.student
        try:
            report = ProgressReport.get_latest_report(student)
            serializer = ProgressReportSerializer(report)
            return Response(serializer.data, status=status.HTTP_200_OK)
        except ProgressReport.DoesNotExist:
            return Response({"detail": "No progress report available."},
                            status=status.HTTP_404_NOT_FOUND)

# Generate a progress report for a given period.
class ProgressReportGenerateAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        student = request.user.student
        start_date_str = request.data.get('start_date')
        end_date_str = request.data.get('end_date')
        if not start_date_str or not end_date_str:
            return Response({"detail": "start_date and end_date are required."},
                            status=status.HTTP_400_BAD_REQUEST)
        start_date = parse_date(start_date_str)
        end_date = parse_date(end_date_str)
        if not start_date or not end_date:
            return Response({"detail": "Invalid date format. Use YYYY-MM-DD."},
                            status=status.HTTP_400_BAD_REQUEST)
        report = ProgressReport.generate_report(student, start_date, end_date)
        serializer = ProgressReportSerializer(report)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
