from django.urls import path
from .views import add_instructor, remove_instructor

urlpatterns = [
    path('add_instructor/', add_instructor, name='add_instructor'),
    path('remove_instructor/', remove_instructor, name='remove_instructor'),
]