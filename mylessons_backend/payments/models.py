from django.db import models
from django.utils.timezone import localtime
from django.template.loader import render_to_string
from django.core.mail import send_mail
from django.conf import settings
    
class Payment(models.Model):
    value = models.DecimalField(max_digits=10, decimal_places=2)
    time = models.TimeField(auto_now_add=True)
    date = models.DateField(auto_now_add=True)
    user = models.ForeignKey(
        'users.UserAccount', 
        on_delete=models.CASCADE, 
        related_name="payments"
    )
    group_pack = models.ManyToManyField(
        'lessons.GroupPack',  
        blank=True, 
        related_name="payments"
    )
    private_pack = models.ManyToManyField(
        'lessons.PrivatePack',
        blank=True, 
        related_name="payments"
    )
    camp = models.ManyToManyField(
        'events.CampOrder',
        blank=True, 
        related_name="payments"
    )
    birthday_party = models.ManyToManyField(
        'events.BirthdayParty',
        blank=True, 
        related_name="payments"
    )
    instructor = models.ForeignKey(
        'users.Instructor', 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name="payments"
    )
    monitor = models.ForeignKey(
        'users.Monitor', 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name="payments"
    )
    voucher = models.ManyToManyField(
        'lessons.Voucher',  
        blank=True, 
        related_name="payments"
    )
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='payments', null=True, blank=True)
    description = models.JSONField()  # For additional metadata or custom notes about the payment

    def __str__(self):
        """Readable representation of the payment"""
        if self.instructor:
            return f"Payment of €{self.value} to instructor {self.instructor.user.username} on {self.date}"
        elif self.monitor:
            return f"Payment of €{self.value} to monitor {self.monitor.user.username} on {self.date}"
        else:
            return f"Payment of €{self.value} by {self.user.username} on {self.date}"
        
    def generate_receipt(self):
        """
        Generates a receipt for the payment, including all relevant details.
        """
        receipt_data = {
            "receipt_number": f"RCP-{self.id}",
            "school_name": self.school.name if self.school else "N/A",
            "school_contact": self.school.contact if self.school and hasattr(self.school, "contact") else "N/A",
            "school_email": self.school.email if self.school and hasattr(self.school, "email") else "N/A",
            "date": self.date.strftime("%Y-%m-%d"),
            "time": localtime(self.time).strftime("%H:%M:%S"),
            "payer_name": f"{self.user.first_name} {self.user.last_name}",
            "payer_email": self.user.email,
            "payment_method": "Online" if self.description.get("method") else "Unknown",
            "items": [],
            "total_price": self.value,
            "currency": self.school.currency if self.school else "EUR",
        }

        # Add purchased services to the receipt
        if self.private_pack.exists():
            for pack in self.private_pack.all():
                receipt_data["items"].append({
                    "type": "Private Lesson Pack",
                    "name": f"{pack.number_of_classes} Lessons - {pack.duration_in_minutes} min",
                    "price": f"{pack.price:.2f} {receipt_data['currency']}"
                })

        if self.group_pack.exists():
            for pack in self.group_pack.all():
                receipt_data["items"].append({
                    "type": "Group Lesson Pack",
                    "name": f"{pack.number_of_classes} Lessons - {pack.duration_in_minutes} min",
                    "price": f"{pack.price:.2f} {receipt_data['currency']}"
                })

        if self.camp.exists():
            for camp in self.camp.all():
                receipt_data["items"].append({
                    "type": "Camp Enrollment",
                    "name": camp.name,
                    "price": f"{camp.price:.2f} {receipt_data['currency']}"
                })

        if self.birthday_party.exists():
            for party in self.birthday_party.all():
                receipt_data["items"].append({
                    "type": "Birthday Party",
                    "name": party.name,
                    "price": f"{party.price:.2f} {receipt_data['currency']}"
                })

        if self.voucher.exists():
            for voucher in self.voucher.all():
                receipt_data["items"].append({
                    "type": "Voucher",
                    "name": voucher.code,
                    "price": f"-{voucher.value:.2f} {receipt_data['currency']}"
                })

        return receipt_data

    def send_receipt_email(self):
        """
        Sends the payment receipt to the user's email.
        """
        receipt_data = self.generate_receipt()
        subject = f"Payment Receipt - {receipt_data['receipt_number']}"

        message = render_to_string("payments/receipt_email.html", {"receipt": receipt_data})

        send_mail(
            subject,
            message,
            settings.DEFAULT_FROM_EMAIL,
            [self.user.email],
            fail_silently=False,
        )

    class Meta:
        ordering = ['-date', '-time']  # Newest payments appear first

