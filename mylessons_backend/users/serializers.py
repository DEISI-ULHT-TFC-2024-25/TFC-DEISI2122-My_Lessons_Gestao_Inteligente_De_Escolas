from rest_framework import serializers
from .models import UserAccount, Student

class StudentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Student
        fields = ('id', 'first_name', 'last_name', 'birthday')

class UserAccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserAccount
        fields = ['id', 'email', 'first_name', 'last_name', 'country_code', 'phone']

