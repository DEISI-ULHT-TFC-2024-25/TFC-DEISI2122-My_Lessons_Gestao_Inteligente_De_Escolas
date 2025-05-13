# events/urls.py

from django.urls import path
from . import views

urlpatterns = [
    # ActivityModel
    path('activity-models/',     views.activity_model_list,   name='activity_model_list'),
    path('activity-models/<int:pk>/', views.activity_model_detail, name='activity_model_detail'),

    # Activity
    path('activities/',          views.activity_list,         name='activity_list'),
    path('activities/<int:pk>/', views.activity_detail,       name='activity_detail'),

    # Camp
    path('camps/',               views.camp_list,             name='camp_list'),
    path('camps/<int:pk>/',      views.camp_detail,           name='camp_detail'),

    # CampOrder
    path('camp-orders/',         views.camp_order_list,       name='camp_order_list'),
    path('camp-orders/<int:pk>/',views.camp_order_detail,     name='camp_order_detail'),

    # BirthdayParty
    path('birthday-parties/',    views.birthday_party_list,   name='birthday_party_list'),
    path('birthday-parties/<int:pk>/', views.birthday_party_detail, name='birthday_party_detail'),
]
