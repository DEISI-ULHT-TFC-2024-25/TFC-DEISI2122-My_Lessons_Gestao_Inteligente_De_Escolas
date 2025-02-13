from django.urls import path
from .views import login_view, google_oauth_start, register_user

urlpatterns = [
    path('login/', login_view, name='login'),
    path('google/', google_oauth_start, name='google_oauth_start'),
    path('register/', register_user, name='register-user'),

    # Add more paths (e.g., /google/callback) as needed
]
