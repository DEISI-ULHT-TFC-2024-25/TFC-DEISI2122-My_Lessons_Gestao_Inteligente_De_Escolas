# Generated by Django 5.1.5 on 2025-04-23 08:07

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('events', '0002_initial'),
        ('users', '0004_instructor_locations'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='birthdayparty',
            name='student',
        ),
        migrations.AddField(
            model_name='birthdayparty',
            name='students',
            field=models.ManyToManyField(blank=True, related_name='birthday_parties', to='users.student'),
        ),
        migrations.RemoveField(
            model_name='birthdayparty',
            name='equipment',
        ),
        migrations.AddField(
            model_name='birthdayparty',
            name='equipment',
            field=models.JSONField(blank=True, default=dict, null=True),
        ),
    ]
