from django.urls import path
from .views import add_instructor, remove_instructor, number_of_bookings_in_timeframe, school_revenue_in_timeframe, number_of_students_in_timeframe, number_of_instructors_in_timeframe

urlpatterns = [
    path('add_instructor/', add_instructor, name='add_instructor'),
    path('remove_instructor/', remove_instructor, name='remove_instructor'),
    path('number_of_booked_lessons/<int:school_id>/<str:start_date>/<str:end_date>/', number_of_bookings_in_timeframe, name='number_of_booked_lessons_in_timeframe'),
    path('number_of_students/<int:school_id>/<str:start_date>/<str:end_date>/', number_of_students_in_timeframe, name='number_of_students_in_timeframe'),
    path('number_of_instructors/<int:school_id>/<str:start_date>/<str:end_date>/', number_of_instructors_in_timeframe, name='number_of_instructors_in_timeframe'),
    path('school-revenue/<int:school_id>/<str:start_date>/<str:end_date>/', school_revenue_in_timeframe, name='school_revenue_in_timeframe'),

]   