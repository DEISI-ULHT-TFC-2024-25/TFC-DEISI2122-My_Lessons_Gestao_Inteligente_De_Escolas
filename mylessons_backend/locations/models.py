from django.db import models

class Location(models.Model):
    name = models.CharField(max_length=255)  # Name of the location
    description = models.TextField(blank=True, null=True)  # Optional description of the location
    address = models.CharField(max_length=500, blank=True, null=True)  # Address of the location
    photo = models.ImageField(upload_to='location_photos/', blank=True, null=True)  # Optional photo of the location
    link = models.CharField(max_length=500, blank=True, null=True)

    def __str__(self):
        return self.name