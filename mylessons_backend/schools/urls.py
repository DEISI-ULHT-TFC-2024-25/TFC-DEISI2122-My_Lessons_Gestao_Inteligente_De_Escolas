from django.urls import path
from .views import add_instructor, remove_instructor, number_of_bookings_in_timeframe, school_revenue_in_timeframe, number_of_students_in_timeframe, number_of_instructors_in_timeframe, update_pack_price_view, school_details_view, update_payment_type_view, all_schools, get_services, add_edit_service

urlpatterns = [
    path('add_instructor/', add_instructor, name='add_instructor'),
    path('remove_instructor/', remove_instructor, name='remove_instructor'),
    path('number_of_booked_lessons/<int:school_id>/<str:start_date>/<str:end_date>/', number_of_bookings_in_timeframe, name='number_of_booked_lessons_in_timeframe'),
    path('number_of_students/<int:school_id>/<str:start_date>/<str:end_date>/', number_of_students_in_timeframe, name='number_of_students_in_timeframe'),
    path('number_of_instructors/<int:school_id>/<str:start_date>/<str:end_date>/', number_of_instructors_in_timeframe, name='number_of_instructors_in_timeframe'),
    path('school-revenue/<int:school_id>/<str:start_date>/<str:end_date>/', school_revenue_in_timeframe, name='school_revenue_in_timeframe'),
    path('update_pack_price/', update_pack_price_view, name='update_pack_price'),
    path('update_payment_type/', update_payment_type_view, name='update_payment_type'),
    path('details/', school_details_view, name='school_details'),
    path('all_schools/', all_schools, name='all_schools'),
    path('<int:school_id>/services/', get_services, name='get-services'),
    path('<int:school_id>/services/add_edit/', add_edit_service, name='add-edit-service'),

]   