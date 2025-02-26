from django.urls import path
from .views import upcoming_lessons, last_lessons, schedule_private_lesson, active_packs, pack_details, lesson_details, todays_lessons, mark_lesson_as_done, mark_lesson_as_not_done, available_lesson_times, can_still_reschedule

urlpatterns = [
    path('upcoming_lessons/', upcoming_lessons, name='upcoming_lessons'),
    path('last_lessons/', last_lessons, name='last_lessons'),
    path('schedule_private_lesson/', schedule_private_lesson, name='schedule_private_lesson'),
    path('active_packs/', active_packs, name='active_packs'),
    path('pack_details/<int:id>/', pack_details, name='pack_details'),
    path('lesson_details/<int:id>/', lesson_details, name='lesson_details'),
    path('todays_lessons/', todays_lessons, name='todays_lessons'),
    path("mark_lesson_as_done/", mark_lesson_as_done, name="mark_lesson_as_done"),
    path("mark_lesson_as_not_done/", mark_lesson_as_not_done, name="mark_lesson_as_not_done"),
    path("available_lesson_times/", available_lesson_times, name="available_lesson_times"),
    path("can_still_reschedule/<int:id>/", can_still_reschedule, name="can_still_reschedule"),
    
]
