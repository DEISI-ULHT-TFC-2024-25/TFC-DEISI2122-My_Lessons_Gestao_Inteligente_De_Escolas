from django.contrib import admin
from .models import Payment


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ('user', 'value', 'date', 'time', 'description')  # Fields displayed in the list view
    list_filter = ('date',)  # Filters for easy navigation
    search_fields = ('user__username', 'description')  # Enable search by username and description
    ordering = ('-date', '-time')  # Default ordering by newest payments
    autocomplete_fields = ('user', 'packs', 'lessons', 'camp_orders', 'vouchers', 'instructor', 'monitor')  # Enable autocomplete for related fields
    filter_horizontal = ('packs', 'lessons', 'camp_orders', 'vouchers')