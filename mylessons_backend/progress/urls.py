from django.urls import path
from .views import *

urlpatterns = [
    path('active_goals/<int:student_id>/', get_active_goals, name='active_goals'),
    path('skills/<int:subject_id>/', get_skills_for_subject, name='get_skills_for_subject'),
    path('goal/<int:goal_id>/update-level/', 
         update_goal_level, name='update_skill_proficiency_level'),
    path('skills/', create_skill, name='create_skill'),
    path('create_goal/', create_goal, name='create_goal'),
    path('progress-records/', create_progress_record, name='create_progress_record'),
    path('progress-records/<int:record_id>/', update_progress_record, name='update_progress_record'),
    path('progress-record/', get_progress_record, name='update_progress_record'),
]
