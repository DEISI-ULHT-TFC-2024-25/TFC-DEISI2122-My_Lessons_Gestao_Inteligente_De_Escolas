from django.contrib import admin
from .models import Skill, SkillProficiency, Goal, ProgressRecord, ProgressReport


@admin.register(Skill)
class SkillAdmin(admin.ModelAdmin):
    list_display = ('name', 'sport', 'description')  # Display key fields
    search_fields = ('name', 'sport')  # Enable search by name and sport
    list_filter = ('sport',)  # Filter by sport


@admin.register(SkillProficiency)
class SkillProficiencyAdmin(admin.ModelAdmin):
    list_display = ('student', 'skill', 'level', 'last_updated')  # Show proficiency details
    search_fields = ('student__user__username', 'skill__name')  # Search by student or skill name
    list_filter = ('level', 'last_updated')  # Filter by level and date


@admin.register(Goal)
class GoalAdmin(admin.ModelAdmin):
    list_display = ('student', 'skill', 'description', 'target_date', 'is_completed')  # Display key fields
    search_fields = ('student__user__username', 'skill__name', 'description')  # Enable search
    list_filter = ('is_completed', 'target_date')  # Filter by completion status and target date


@admin.register(ProgressRecord)
class ProgressRecordAdmin(admin.ModelAdmin):
    list_display = ('student', 'lesson', 'group_class', 'date', 'notes')  # Display progress details
    search_fields = ('student__user__username', 'notes')  # Search by student or notes
    list_filter = ('date',)  # Filter by date
    autocomplete_fields = ('skills',)  # Enable skill autocomplete


@admin.register(ProgressReport)
class ProgressReportAdmin(admin.ModelAdmin):
    list_display = ('student', 'period_start', 'period_end', 'created_at')  # Display report summary
    search_fields = ('student__user__username',)  # Search by student
    list_filter = ('period_start', 'period_end')  # Filter by date range
