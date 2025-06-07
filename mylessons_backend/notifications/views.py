from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from .models import Notification
from rest_framework import permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from fcm_django.models import FCMDevice

class RegisterDeviceToken(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        token = request.data.get("token")
        if not token:
            return Response({"error": "Token required"}, status=status.HTTP_400_BAD_REQUEST)

        # 1) See if some user already has this token
        try:
            existing = FCMDevice.objects.get(registration_id=token)
            # If it exists, reassign it to the current user and update its type
            existing.user = request.user
            existing.type = "ios"
            existing.save(update_fields=["user", "type"])
            created = False
            device = existing
        except FCMDevice.DoesNotExist:
            # 2) If nobody has this token yet, create a fresh one
            device = FCMDevice.objects.create(
                user=request.user,
                registration_id=token,
                type="ios",
            )
            created = True

        return Response({"status": "registered"})

    
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_notification_as_read(request):
    """
    Marks a notification as read.
    """
    notifications = []
    notifications_ids = request.data.get("notifications_ids", [])

    for id in notifications_ids:
        notification = get_object_or_404(Notification, id=id, user=request.user)
        notifications.append(notification)
        notification.mark_as_read()

    return Response({"message": "All notifications marked as read."}, status=200)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_unread_notifications(request):
    user = request.user  # Obtém o utilizador autenticado

    # Busca todas as notificações não lidas
    unread_notifications = Notification.objects.filter(user=user, date_read=None, type=user.current_role).order_by('-created_at')

    # Serializa os dados manualmente
    data = [
        {
            "id": notification.id,
            "subject": notification.subject,
            "message" : notification.message,
            "created_at": notification.created_at.strftime("%Y-%m-%d %H:%M:%S"),
            "type": notification.type,
        }
        for notification in unread_notifications
    ]

    return Response(data)