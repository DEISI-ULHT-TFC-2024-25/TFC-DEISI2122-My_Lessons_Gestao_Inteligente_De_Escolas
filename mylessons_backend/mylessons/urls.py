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
from payments.views import deeplink_payment_success, deeplink_payment_fail

urlpatterns = [
    path('admin/', admin.site.urls),
    path('accounts/', include('allauth.urls')),
    path('api/payments/', include('payments.urls')), 
    path('api/users/', include('users.urls')), 
    path('api/lessons/', include('lessons.urls')), 
    path('api/notifications/', include('notifications.urls')),
    path('api/schools/', include('schools.urls')),
    path("deeplink/payment-success/", deeplink_payment_success, name="deeplink_payment_success"),
    path("deeplink/payment-fail/", deeplink_payment_fail, name="deeplink_payment_fail"),
]
