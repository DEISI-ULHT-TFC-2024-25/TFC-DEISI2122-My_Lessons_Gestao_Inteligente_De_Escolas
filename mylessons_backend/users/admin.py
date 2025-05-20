from django.contrib import admin
from .models import (
    GoogleCredentials, UserAccount, Student,
    Instructor, Monitor, Unavailability,
    Discount, UserCredentials
)

@admin.register(UserAccount)
class UserAccountAdmin(admin.ModelAdmin):
    list_display = ('username', 'email', 'first_name', 'last_name', 'phone', 'country_code', 'is_active', 'is_staff')
    search_fields = ('username', 'email', 'first_name', 'last_name', 'phone')
    list_filter = ('is_active', 'is_staff', 'is_superuser')
    ordering = ('-date_joined',)

@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = ('first_name', 'last_name', 'level', 'birthday')
    search_fields = ('first_name', 'last_name', 'user__username', 'level')
    list_filter = ('level', 'birthday')


@admin.register(Instructor)
class InstructorAdmin(admin.ModelAdmin):
    list_display = ('id', 'get_user_name')
    search_fields = ('user__username', 'user__first_name', 'user__last_name')

    def get_user_name(self, obj):
        return f"{obj.user.first_name} {obj.user.last_name}"
    get_user_name.short_description = 'Name'

@admin.register(Monitor)
class MonitorAdmin(admin.ModelAdmin):
    list_display = ('id', 'get_user_name')
    search_fields = ('user__username', 'user__first_name', 'user__last_name')

    def get_user_name(self, obj):
        return f"{obj.user.first_name} {obj.user.last_name}"
    get_user_name.short_description = 'Name'

@admin.register(Unavailability)
class UnavailabilityAdmin(admin.ModelAdmin):
    list_display = ('date', 'start_time', 'duration_in_minutes', 'get_details')
    search_fields = ('student__first_name', 'student__last_name', 'instructor__user__username')
    list_filter = ('date',)

    def get_details(self, obj):
        details = []
        if obj.student:
            details.append(f"Student: {obj.student}")
        if obj.instructor:
            details.append(f"Instructor: {obj.instructor}")
        return ", ".join(details)
    get_details.short_description = 'Details'

@admin.register(Discount)
class DiscountAdmin(admin.ModelAdmin):
    list_display = ('user', 'discount_percentage', 'discount_value', 'expiration_date', 'date')
    search_fields = ('user__username', 'discount_percentage', 'discount_value')
    list_filter = ('date', 'expiration_date')

@admin.register(GoogleCredentials)
class GoogleCredentialsAdmin(admin.ModelAdmin):
    list_display = ('user', )
    
@admin.register(UserCredentials)
class UserCredentialsAdmin(admin.ModelAdmin):
    list_display = ('user', )
