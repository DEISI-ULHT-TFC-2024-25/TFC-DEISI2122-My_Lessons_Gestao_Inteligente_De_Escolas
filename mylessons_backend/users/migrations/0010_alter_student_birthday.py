# Generated by Django 5.1.5 on 2025-06-12 18:04

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0009_instructor_old_id_str_student_old_id_str'),
    ]

    operations = [
        migrations.AlterField(
            model_name='student',
            name='birthday',
            field=models.DateField(blank=True, null=True),
        ),
    ]
