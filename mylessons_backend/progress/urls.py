from django.urls import path
from .views import (
    SkillViewSet, 
    SkillProficiencyViewSet, 
    GoalViewSet, 
    ProgressRecordViewSet, 
    ProgressReportViewSet
)

urlpatterns = [
    # Skills endpoints
    path('skills/', SkillViewSet.as_view({
        'get': 'list',
        'post': 'create'
    }), name='skill-list'),
    path('skills/<int:pk>/', SkillViewSet.as_view({
        'get': 'retrieve',
        'put': 'update',
        'patch': 'partial_update',
        'delete': 'destroy'
    }), name='skill-detail'),

    # Skill Proficiencies endpoints
    path('skill-proficiencies/', SkillProficiencyViewSet.as_view({
        'get': 'list',
        'post': 'create'
    }), name='skillproficiency-list'),
    path('skill-proficiencies/<int:pk>/', SkillProficiencyViewSet.as_view({
        'get': 'retrieve',
        'put': 'update',
        'patch': 'partial_update',
        'delete': 'destroy'
    }), name='skillproficiency-detail'),
    path('skill-proficiencies/<int:pk>/update-level/', SkillProficiencyViewSet.as_view({
        'post': 'update_level'
    }), name='skillproficiency-update-level'),

    # Goals endpoints
    path('goals/', GoalViewSet.as_view({
        'get': 'list',
        'post': 'create'
    }), name='goal-list'),
    path('goals/<int:pk>/', GoalViewSet.as_view({
        'get': 'retrieve',
        'put': 'update',
        'patch': 'partial_update',
        'delete': 'destroy'
    }), name='goal-detail'),
    path('goals/<int:pk>/mark-completed/', GoalViewSet.as_view({
        'post': 'mark_completed'
    }), name='goal-mark-completed'),
    path('goals/<int:pk>/mark-uncompleted/', GoalViewSet.as_view({
        'post': 'mark_uncompleted'
    }), name='goal-mark-uncompleted'),
    path('goals/<int:pk>/extend-deadline/', GoalViewSet.as_view({
        'post': 'extend_deadline'
    }), name='goal-extend-deadline'),

    # Progress Records endpoints
    path('progress-records/', ProgressRecordViewSet.as_view({
        'get': 'list',
        'post': 'create'
    }), name='progressrecord-list'),
    path('progress-records/<int:pk>/', ProgressRecordViewSet.as_view({
        'get': 'retrieve',
        'put': 'update',
        'patch': 'partial_update',
        'delete': 'destroy'
    }), name='progressrecord-detail'),
    path('progress-records/<int:pk>/add-covered-skill/', ProgressRecordViewSet.as_view({
        'post': 'add_covered_skill'
    }), name='progressrecord-add-covered-skill'),
    path('progress-records/<int:pk>/update-notes/', ProgressRecordViewSet.as_view({
        'post': 'update_notes'
    }), name='progressrecord-update-notes'),

    # Progress Reports endpoints
    path('progress-reports/', ProgressReportViewSet.as_view({
        'get': 'list',
        'post': 'create'
    }), name='progressreport-list'),
    path('progress-reports/<int:pk>/', ProgressReportViewSet.as_view({
        'get': 'retrieve',
        'put': 'update',
        'patch': 'partial_update',
        'delete': 'destroy'
    }), name='progressreport-detail'),
    path('progress-reports/generate-report/', ProgressReportViewSet.as_view({
        'post': 'generate_report'
    }), name='progressreport-generate-report'),
    path('progress-reports/latest-report/', ProgressReportViewSet.as_view({
        'get': 'latest_report'
    }), name='progressreport-latest-report'),
]
