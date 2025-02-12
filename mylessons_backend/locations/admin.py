from django.contrib import admin
from .models import Location


@admin.register(Location)
class LocationAdmin(admin.ModelAdmin):
    list_display = ('name', 'address', 'description')  # Columns displayed in the admin list view
    search_fields = ('name', 'address')  # Enable search by name and address
    ordering = ('name',)  # Default ordering by name
    list_filter = ('address',)  # Sidebar filter for the address field
