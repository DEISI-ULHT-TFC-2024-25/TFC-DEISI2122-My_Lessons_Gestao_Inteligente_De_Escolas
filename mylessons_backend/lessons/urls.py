from django.urls import path
from .views import upcoming_lessons, last_lessons, schedule_private_lesson, active_packs, private_pack_details, group_pack_details, private_lesson_details, group_lesson_details

urlpatterns = [
    path('upcoming-lessons/', upcoming_lessons, name='upcoming-lessons'),
    path('last-lessons/', last_lessons, name='last-lessons'),
    path('schedule-private-lesson/', schedule_private_lesson, name='schedule-private-lesson'),
    path('active-packs/', active_packs, name='active-packs'),
    path('private-pack-details/<int:id>/', private_pack_details, name='private-pack-details'),
    path('private-lesson-details/<int:id>/', private_lesson_details, name='private-lesson-details'),
    path('group-pack-details/<int:id>/', group_pack_details, name='group-pack-details'),
    path('group-lesson-details/<int:id>/', group_lesson_details, name='group-lesson-details'),
]
