from django.urls import path
from .views import  generate_key, pair_by_key, PasswordResetConfirmView, PasswordResetRequestView, check_username_availability, daily_timeline, firebase_login, get_selected_instructors, get_selected_students, login_view, profile_view, register_user, student, student_debt, student_lessons, student_packs, student_parents, student_progress_records, update_availability, user_profile, current_role, number_of_active_students, current_balance, change_role, available_roles, change_school_id, current_school_id, available_schools, students, create_student, book_pack_view

urlpatterns = [
    path('student/<int:id>/', student, name='student'),
    path('student/<int:id>/progress_records/', student_progress_records, name='student_progress_records'),
    path('student/<int:id>/packs/', student_packs, name='student_packs'),
    path('student/<int:id>/lessons/', student_lessons, name='student_lessons'),
    path('student/<int:id>/events/', student_parents, name='student_events'),
    path('student/<int:id>/parents/', student_parents, name='student_parents'),
    path('student/<int:id>/debt/', student_debt, name='student_debt'),
    path('login/', login_view, name='login'),
    path('register/', register_user, name='register-user'),
    path('profile/', user_profile, name='user-profile'),
    path('current_role/', current_role, name='current-role'),
    path('change_role/', change_role, name='change_role'),
    path('number_of_active_students/', number_of_active_students, name='number-of-students'),
    path("current_balance/", current_balance, name="current_balance"),
    path("available_roles/", available_roles, name="available_roles"),
    path("current_school_id/", current_school_id, name="current_school_id"),
    path("change_school_id/", change_school_id, name="change_school_id"),
    path("available_schools/", available_schools, name="available_schools"),
    path("students/", students, name="students"),
    path("get_selected_students/", get_selected_students, name="get_selected_students"),
    path("get_selected_instructors/", get_selected_instructors, name="get_selected_instructors"),
    path('students/create/', create_student, name='create_student'),
    path('book_pack/', book_pack_view, name='book_pack'),
    path('update_availability/', update_availability, name='update_availability'),
    path('daily_timeline/', daily_timeline, name='daily_timeline'),  
    path('check_username/', check_username_availability, name='check_username'),
    path('firebase_login/', firebase_login, name='firebase_login'),
    path('profile_data/', profile_view, name='profile_data'),
    path('password-reset/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password-reset-confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    path('student/<int:id>/generate-key/', generate_key, name='generate_key'),
    path('student/pair-by-key/', pair_by_key, name='pair_by_key'),


    # Add more paths (e.g., /google/callback) as needed
]
