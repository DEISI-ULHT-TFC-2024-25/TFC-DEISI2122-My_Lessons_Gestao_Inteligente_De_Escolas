# progress/urls.py
from django.urls import path
from .views import (
    progress_record_detail, 
    progress_records_list, 
    progress_reports_list,
    update_progress_record,
    update_skill_proficiency,
)

urlpatterns = [
    path('record/<int:lesson_id>/', progress_record_detail, name='progress-record-detail'),
    path('records/', progress_records_list, name='progress-records-list'),
    path('reports/', progress_reports_list, name='progress-reports-list'),
    path('record/update/<int:record_id>/', update_progress_record, name='update-progress-record'),
    path('skill/update/<int:proficiency_id>/', update_skill_proficiency, name='update-skill-proficiency'),
]
