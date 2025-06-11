# lessons/serializers.py
from rest_framework import serializers

class CSVUploadSerializer(serializers.Serializer):
    file = serializers.FileField()
    target = serializers.ChoiceField(choices=[
        ('student', 'Students'),
        ('pack', 'Packs'),
        ('lesson', 'Lessons'),
        ('payment', 'Payments'),
    ])

class CapabilitiesSerializer(serializers.Serializer):
    call = serializers.BooleanField()
    text = serializers.BooleanField()

class PhoneSerializer(serializers.Serializer):
    country_code  = serializers.CharField(max_length=5)
    number        = serializers.CharField(max_length=32)
    capabilities  = CapabilitiesSerializer()

class TeamSerializer(serializers.Serializer):
    label  = serializers.CharField(max_length=100)
    emails = serializers.ListField(
        child=serializers.EmailField(),
        allow_empty=True
    )
    phones = PhoneSerializer(many=True)

class ContactsSerializer(serializers.Serializer):
    teams = TeamSerializer(many=True)

class UpdateContactsSerializer(serializers.Serializer):
    contacts = ContactsSerializer()
