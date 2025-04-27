from django.contrib import admin
from .models import Review, School


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ('user', 'rating', 'is_verified', 'description')  # Show important fields
    search_fields = ('user__username', 'description')  # Enable search by user or description
    list_filter = ('is_verified', 'rating')  # Filter by verification status, rating, and date


@admin.register(School)
class SchoolAdmin(admin.ModelAdmin):
    list_display = ('name', 'description')  # Display school name and description
    search_fields = ('name', 'description')  # Enable search by name or description
    list_filter = ('instructors', 'students')  # Allow filtering by instructors and students
    filter_horizontal = (
        'instructors', 'students', 'parents', 'monitors', 'locations',
    )  # Enable better many-to-many management
    readonly_fields = ('logo',)  # Prevent accidental changes to the logo field
