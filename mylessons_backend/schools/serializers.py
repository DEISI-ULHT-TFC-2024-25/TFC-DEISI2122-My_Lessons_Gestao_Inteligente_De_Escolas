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
