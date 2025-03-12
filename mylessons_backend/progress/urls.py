from django.urls import path
from .views import (
    ProgressRecordListCreateAPIView,
    ProgressReportLatestAPIView,
    ProgressReportGenerateAPIView
)

urlpatterns = [
    path('records/', ProgressRecordListCreateAPIView.as_view(), name='progress-records'),
    path('reports/latest/', ProgressReportLatestAPIView.as_view(), name='progress-report-latest'),
    path('reports/generate/', ProgressReportGenerateAPIView.as_view(), name='progress-report-generate'),
]
