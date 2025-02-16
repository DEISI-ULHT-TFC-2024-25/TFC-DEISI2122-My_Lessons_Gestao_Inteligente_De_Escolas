from django.urls import path
from .views import upcoming_lessons, last_lessons, schedule_private_lesson, active_packs, pack_datails

urlpatterns = [
    path('upcoming-lessons/', upcoming_lessons, name='upcoming-lessons'),
    path('last-lessons/', last_lessons, name='last-lessons'),
    path('schedule-private-lesson/', schedule_private_lesson, name='schedule-private-lesson'),
    path('active-packs/', active_packs, name='active-packs'),
#    path('pack-datails/{id}/', pack_datails, name='pack-datails'),
#    path('lesson-datails/{id}/', lesson_datails, name='lesson-datails'),
]
