from django.db import models

class Sport(models.Model):
    name = models.CharField(max_length=255)
    photo = models.ImageField(upload_to="sports_photos/")
    description = models.TextField()
    benefits = models.TextField()
    locations = models.ManyToManyField('sports.Sport', related_name='sports', blank=True)

    def __str__(self):
        return self.name
