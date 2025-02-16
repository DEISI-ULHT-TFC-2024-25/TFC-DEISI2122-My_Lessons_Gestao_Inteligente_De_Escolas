from django.db import models
from django.utils.timezone import now
from schools.models import School

class Notification(models.Model):
    id = models.AutoField(primary_key=True)
    user = models.ForeignKey(
        'users.UserAccount', 
        on_delete=models.CASCADE, 
        related_name="notifications"
    )
    school = models.ForeignKey(
        School, 
        on_delete=models.CASCADE, 
        related_name="notifications", 
        null=True, 
        blank=True
    )
    private_classes = models.ManyToManyField('lessons.PrivateClass', related_name="notifications", blank=True)
    group_classes = models.ManyToManyField('lessons.GroupClass', related_name="notifications", blank=True)
    activities = models.ManyToManyField('events.Activity', related_name="notifications", blank=True)
    private_packs = models.ManyToManyField('lessons.PrivatePack', related_name="notifications", blank=True)
    group_packs = models.ManyToManyField('lessons.GroupPack', related_name="notifications", blank=True)
    type = models.CharField(max_length=255, null=True, blank=True)
    subject = models.CharField(max_length=255, default="Notification from MyLessons")
    message = models.TextField()
    sent_at = models.DateTimeField(null=True, blank=True)
    date_read = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Notification for {self.user} - {self.message[:30]}"

    class Meta:
        ordering = ['-sent_at']

    def send(self):
        """
        Marks the notification as sent, records the timestamp, and sends an email if needed.
        """
        self.sent_at = now()
        self.save()

        # Send email if needed
        if hasattr(self.user, 'email') and self.user.email:
            from django.core.mail import send_mail

            send_mail(
                self.subject,
                self.message,
                'mylessons.test@gmail.com',  # Sender email address
                [self.user.email],
                fail_silently=False,
            )

    def mark_as_read(self):
        """
        Marks the notification as read and records the timestamp.
        """
        self.date_read = now()
        self.save()

    @classmethod
    def create_notification(cls, user, subject, message, school=None, private_classes=None, group_classes=None, activities=None, private_packs=None, group_packs=None, type=None):
        """
        Creates a notification with optional associations.
        """
        notification = cls.objects.create(
            user=user,
            subject=subject,
            message=message,
            school=school,
            type=type,
            created_at=now(),
        )

        if private_classes:
            notification.private_classes.set(private_classes)
        if group_classes:
            notification.group_classes.set(group_classes)
        if activities:
            notification.activities.set(activities)
        if private_packs:
            notification.private_packs.set(private_packs)
        if group_packs:
            notification.group_packs.set(group_packs)

        notification.save()
        return notification

    @classmethod
    def bulk_send_notifications(cls, notifications):
        """
        Sends multiple notifications in bulk.
        """
        for notification in notifications:
            notification.send()
