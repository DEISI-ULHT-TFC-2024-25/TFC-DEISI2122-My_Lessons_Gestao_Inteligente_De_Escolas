import os
import firebase_admin
from firebase_admin import credentials
from fcm_django.models import FCMDevice
from firebase_admin.messaging import Message, Notification
from django.conf import settings


def notify_user(user, title, body):
    # Build the FCM Message object
    msg = Message(
        notification=Notification(
            title=title,
            body=body,
        ),
        # you could also add .data={...} or other fields here
    )

    # Bulk-send to all of this user’s devices
    devices = FCMDevice.objects.filter(user=user)
    devices.send_message(msg)