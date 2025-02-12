from django.contrib import admin
from .models import GroupPack, GroupClass, ClassTicket, PrivateClass, PrivatePack, Voucher


@admin.register(GroupPack)
class GroupPackAdmin(admin.ModelAdmin):
    list_display = ('student', 'date', 'number_of_classes', 'number_of_classes_left', 'is_done', 'is_paid', 'debt')
    list_filter = ('is_done', 'is_paid', 'is_suspended', 'date')
    search_fields = ('student__user__username', 'parents__username')
    ordering = ('-date',)


@admin.register(GroupClass)
class GroupClassAdmin(admin.ModelAdmin):
    list_display = ('date', 'start_time', 'end_time', 'level', 'maximum_number_of_students', 'is_done')
    list_filter = ('level', 'is_done', 'date')
    search_fields = ('students__user__first_name', 'instructors__user__first_name')
    ordering = ('-date', '-start_time')
    filter_horizontal = ('students', 'instructors')


@admin.register(ClassTicket)
class ClassTicketAdmin(admin.ModelAdmin):
    list_display = ('student', 'group_class', 'is_used')
    list_filter = ('is_used',)
    search_fields = ('student__user__username', 'group_class__date')
    ordering = ('group_class',)


@admin.register(PrivateClass)
class PrivateClassAdmin(admin.ModelAdmin):
    list_display = ('class_number', 'date', 'start_time', 'end_time', 'price', 'is_done')
    list_filter = ('is_done', 'date')
    search_fields = ('students__name', 'instructor__username')
    ordering = ('date', 'start_time')
    filter_horizontal = ('equipments', 'extra_students')


@admin.register(PrivatePack)
class PrivatePackAdmin(admin.ModelAdmin):
    list_display = ('date', 'number_of_classes', 'is_done', 'is_paid', 'debt')
    list_filter = ('is_done', 'is_paid', 'is_suspended', 'date')
    search_fields = ('students__name', 'parents__username')
    ordering = ('-date',)


@admin.register(Voucher)
class VoucherAdmin(admin.ModelAdmin):
    list_display = ('user', 'private_pack', 'group_pack', 'is_paid', 'expiration_date')
    list_filter = ('is_paid', 'expiration_date')
    search_fields = ('user__username',)
    ordering = ('-date',)
