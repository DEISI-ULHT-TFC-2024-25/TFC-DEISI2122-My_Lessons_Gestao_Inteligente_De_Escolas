from django.urls import path
from .views import login_view, google_oauth_start, register_user, user_profile, current_role, number_of_active_students, current_balance, change_role, available_roles, change_school_id, current_school_id, available_schools, students, create_student, book_pack_view, store_google_credentials

urlpatterns = [
    path('login/', login_view, name='login'),
    path('google/', google_oauth_start, name='google_oauth_start'),
    path('store_google_credentials/', store_google_credentials, name='store_google_credentials'),
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
    path('students/create/', create_student, name='create_student'),
    path('book_pack/', book_pack_view, name='book_pack'),
    

    # Add more paths (e.g., /google/callback) as needed
]
