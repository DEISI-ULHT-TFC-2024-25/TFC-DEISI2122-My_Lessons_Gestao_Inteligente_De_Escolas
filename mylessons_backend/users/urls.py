from django.urls import path
from .views import login_view, google_oauth_start

urlpatterns = [
    path('login/', login_view, name='login'),
    path('google/', google_oauth_start, name='google_oauth_start'),
    # Add more paths (e.g., /google/callback) as needed
]
