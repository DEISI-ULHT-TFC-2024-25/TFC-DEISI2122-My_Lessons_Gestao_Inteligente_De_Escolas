from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from .models import Notification

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_notification_as_read(request, id):
    """
    Marks a notification as read.
    """
    notification = get_object_or_404(Notification, id=id, user=request.user)

    if notification.date_read:
        return Response({"message": "Notification already read."}, status=200)

    notification.mark_as_read()

    return Response({"message": "Notification marked as read."}, status=200)

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