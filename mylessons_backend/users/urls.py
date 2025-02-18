from django.urls import path
from .views import login_view, google_oauth_start, register_user, user_profile, current_role, number_of_active_students

urlpatterns = [
    path('login/', login_view, name='login'),
    path('google/', google_oauth_start, name='google_oauth_start'),
    path('register/', register_user, name='register-user'),
    path('profile/', user_profile, name='user-profile'),
    path('current_role/', current_role, name='current-role'),
    path('number_of_active_students/', number_of_active_students, name='number-of-students')

    # Add more paths (e.g., /google/callback) as needed
]
