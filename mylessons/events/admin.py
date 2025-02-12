from django.contrib import admin
from .models import ActivityModel, Activity, CampOrder, Camp, BirthdayParty


@admin.register(ActivityModel)
class ActivityModelAdmin(admin.ModelAdmin):
    list_display = ('name', 'location')
    search_fields = ('name', 'location__name')
    ordering = ('name',)
    list_filter = ('location',)


@admin.register(Activity)
class ActivityAdmin(admin.ModelAdmin):
    list_display = ('name', 'date', 'start_time', 'end_time', 'student_price', 'monitor_price')
    list_filter = ('date', 'students', 'instructors')
    search_fields = ('name', 'students__user__first_name', 'instructors__user__first_name')
    ordering = ('date', 'start_time')
    filter_horizontal = ('students', 'instructors', 'monitors')


@admin.register(CampOrder)
class CampOrderAdmin(admin.ModelAdmin):
    list_display = ('user', 'student', 'is_half_paid', 'is_fully_paid', 'date', 'time', 'price')
    list_filter = ('is_half_paid', 'is_fully_paid', 'date')
    search_fields = ('user__username', 'student__user__first_name')
    ordering = ('-date', '-time')
    filter_horizontal = ('activities',)


@admin.register(Camp)
class CampAdmin(admin.ModelAdmin):
    list_display = ('name', 'start_date', 'end_date', 'is_finished')
    list_filter = ('is_finished',)
    search_fields = ('name',)
    ordering = ('start_date',)
    filter_horizontal = ('activities',)


@admin.register(BirthdayParty)
class BirthdayPartyAdmin(admin.ModelAdmin):
    list_display = ('student', 'date', 'start_time', 'end_time',  'number_of_guests', 'price')
    list_filter = ('date', 'student', 'number_of_guests')
    search_fields = ('student__user__first_name', 'student__user__last_name')
    ordering = ('date', 'start_time')
    filter_horizontal = ('activities', 'equipment')
