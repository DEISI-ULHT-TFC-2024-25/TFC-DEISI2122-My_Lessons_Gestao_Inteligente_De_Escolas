"""
URL configuration for mylessons project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.contrib.auth import views as auth_views
from schools.views import BulkImportView, ExcelTemplateView
from users.views import exchange_code
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('calendar/oauth2/exchange/', exchange_code),
    path('accounts/', include('allauth.urls')),
    path('api/payments/', include('payments.urls')), 
    path('api/users/', include('users.urls')), 
    path('api/lessons/', include('lessons.urls')), 
    path('api/notifications/', include('notifications.urls')),
    path('api/schools/', include('schools.urls')),
    path('api/progress/', include('progress.urls')),
    path('api/events/', include('events.urls')),
    path('api/import-excel/', BulkImportView.as_view(), name='bulk-import'),
    path('api/import-excel/template/', ExcelTemplateView.as_view(), name='excel-template'),
    path(
        'password-reset-confirm/<uidb64>/<token>/',
        auth_views.PasswordResetConfirmView.as_view(
            template_name='users/password_reset_confirm.html',
            success_url='/password-reset-complete/'
        ),
        name='password_reset_confirm',
    ),
    path(
        'password-reset-complete/',
        auth_views.PasswordResetCompleteView.as_view(
            template_name='users/password_reset_complete.html'
        ),
        name='password_reset_complete',
    ),
]

if settings.DEBUG:
        urlpatterns += static(
            settings.MEDIA_URL,
            document_root=settings.MEDIA_ROOT
        )
