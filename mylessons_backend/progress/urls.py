from django.urls import path
from .views import *

urlpatterns = [
    path('skill-proficiencies/', get_skill_proficiencies, name='get_skill_proficiencies'),
    path('skills/<int:subject_id>/', get_skills_for_subject, name='get_skills_for_subject'),
    path('skill-proficiencies/<int:student_id>/<int:proficiency_id>/update-level/', 
         update_skill_proficiency_level, name='update_skill_proficiency_level'),
    path('skills/', create_skill, name='create_skill'),
    path('goals/', create_goal, name='create_goal'),
    path('progress-records/', create_progress_record, name='create_progress_record'),
    path('progress-records/<int:record_id>/', update_progress_record, name='update_progress_record'),
]
