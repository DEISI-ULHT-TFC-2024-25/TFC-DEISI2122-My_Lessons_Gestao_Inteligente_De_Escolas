# progress/urls.py
from django.urls import path
from .views import progress_record_detail, progress_records_list, progress_reports_list

urlpatterns = [
    path('record/<int:lesson_id>/', progress_record_detail, name='progress-record-detail'),
    path('records/', progress_records_list, name='progress-records-list'),
    path('reports/', progress_reports_list, name='progress-reports-list'),
]
