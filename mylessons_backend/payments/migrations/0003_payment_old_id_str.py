# Generated by Django 5.1.5 on 2025-06-12 16:39

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('payments', '0002_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='payment',
            name='old_id_str',
            field=models.CharField(blank=True, max_length=255, null=True, unique=True),
        ),
    ]
