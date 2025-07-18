from django.urls import path
from .views import RegisterDeviceToken, mark_notification_as_read, get_unread_notifications

urlpatterns = [
    path('unread/', get_unread_notifications, name='notifications'),
    path('read/', mark_notification_as_read, name='read-notification'),
    path('register-token/', RegisterDeviceToken.as_view(), name='register-token'),
]
