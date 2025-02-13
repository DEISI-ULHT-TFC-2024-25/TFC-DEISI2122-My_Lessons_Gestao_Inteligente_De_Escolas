from django.urls import path
from .views import notifications, read_notification

urlpatterns = [
    path('/', notifications, name='notifications'),
    path('read/{id}/', read_notification, name='read-notification'),
]
