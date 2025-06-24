from rest_framework import serializers
from .models import UserAccount, Student
from django.core.mail import send_mail
from django.conf import settings

class StudentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Student
        fields = ('id', 'first_name', 'last_name', 'birthday')

class UserAccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserAccount
        fields = ['id', 'email', 'first_name', 'last_name', 'country_code', 'phone']

class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()

class PasswordResetConfirmSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()
    new_password = serializers.CharField(min_length=8)

class GenerateKeyOutputSerializer(serializers.Serializer):
    key = serializers.UUIDField(read_only=True)


class PairByKeyInputSerializer(serializers.Serializer):
    key = serializers.UUIDField()