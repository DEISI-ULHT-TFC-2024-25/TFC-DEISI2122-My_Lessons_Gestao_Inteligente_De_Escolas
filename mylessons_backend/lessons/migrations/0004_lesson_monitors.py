# Generated by Django 5.1.5 on 2025-04-23 08:07

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('lessons', '0003_lesson_packs'),
        ('users', '0004_instructor_locations'),
    ]

    operations = [
        migrations.AddField(
            model_name='lesson',
            name='monitors',
            field=models.ManyToManyField(blank=True, related_name='lessons', to='users.monitor'),
        ),
    ]
