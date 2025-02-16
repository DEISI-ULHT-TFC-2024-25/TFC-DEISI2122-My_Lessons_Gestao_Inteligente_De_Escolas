from django.contrib import admin
from .models import Notification

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'type', 'user', 'subject', 'message', 'sent_at', 'date_read')
    list_filter = ('sent_at', 'date_read')
    search_fields = ('user__first_name', 'user__last_name', 'subject', 'message')
    readonly_fields = ('sent_at', 'date_read')
    
    fieldsets = (
        ('User Information', {
            'fields': ('user', 'school')
        }),
        ('Notification Details', {
            'fields': ('subject', 'message', 'sent_at', 'date_read')
        }),
        ('Related Entities', {
            'fields': ('private_classes', 'group_classes', 'activities', 'private_packs', 'group_packs')
        }),
    )

    actions = ['mark_as_read', 'resend_notification']

    def mark_as_read(self, request, queryset):
        queryset.update(date_read=now())
        self.message_user(request, "Selected notifications marked as read.")
    mark_as_read.short_description = "Mark selected notifications as read"

    def resend_notification(self, request, queryset):
        for notification in queryset:
            notification.send()
        self.message_user(request, "Selected notifications resent.")
    resend_notification.short_description = "Email selected notifications"
