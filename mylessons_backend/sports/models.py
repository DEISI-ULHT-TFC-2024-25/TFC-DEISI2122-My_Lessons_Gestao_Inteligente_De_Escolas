from django.db import models

class Sport(models.Model):
    name = models.CharField(max_length=255)
    photo = models.ImageField(upload_to="sports_photos/", null=True, blank=True)
    description = models.TextField(null=True, blank=True)
    benefits = models.TextField(null=True, blank=True)
    locations = models.ManyToManyField('locations.Location', related_name='sports', blank=True)

    def __str__(self):
        return self.name
