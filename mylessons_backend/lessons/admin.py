from django.contrib import admin
from .models import  Lesson, Pack, Voucher


@admin.register(Pack)
class PackAdmin(admin.ModelAdmin):
    list_display = ('date', "type", 'number_of_classes', 'number_of_classes_left', 'is_done', 'is_paid', 'debt')
    list_filter = ('is_done', 'is_paid', 'is_suspended', 'date')
    search_fields = ('students__first_name', 'students__last_name', 'instructors__user__first_name', 'instructors__user__last_name')
    ordering = ('-date',)
    filter_horizontal = ('students', 'instructors')


@admin.register(Lesson)
class LessonAdmin(admin.ModelAdmin):
    list_display = ('date', "type", 'start_time', 'end_time', 'level', 'maximum_number_of_students', 'is_done')
    list_filter = ('level', 'is_done', 'date')
    search_fields = ('students__first_name', 'students__last_name', 'instructors__user__first_name', 'instructors__user__last_name')
    ordering = ('-date', '-start_time')
    filter_horizontal = ('students', 'instructors')


@admin.register(Voucher)
class VoucherAdmin(admin.ModelAdmin):
    list_display = ('user', 'is_paid', 'expiration_date')
    list_filter = ('is_paid', 'expiration_date')
    search_fields = ('user__username',)
    ordering = ('-date',)
    filter_horizontal = ('packs', 'lessons')
