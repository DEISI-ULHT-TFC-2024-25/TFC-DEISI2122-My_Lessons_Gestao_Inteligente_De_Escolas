import json
import datetime
from django.utils import timezone
from django.core.management.base import BaseCommand
from django.conf import settings
from lessons.models import Lesson
from users.utils import get_calendar_service


class Command(BaseCommand):
    help = 'Sync pending Lessons to Google Calendar (instructors, monitors, parents)'

    def handle(self, *args, **options):
        pending = Lesson.objects.filter(needs_calendar_sync=True)
        total = pending.count()
        self.stdout.write(f'Found {total} lessons to sync…')

        for lesson in pending:
            # Build participant set
            instructors = {inst.user for inst in lesson.instructors.all()}
            monitors    = {mon.user  for mon  in lesson.monitors.all()}
            parents     = {parent for student in lesson.students.all() for parent in student.parents.all()}
            participants = instructors | monitors | parents


            for user in participants:
                if not user.calendar_token:
                    continue
                service = get_calendar_service(user)

                start_dt = datetime.datetime.combine(lesson.date, lesson.start_time)
                end_dt   = datetime.datetime.combine(lesson.date, lesson.end_time)

                location = None
                if lesson.location:
                    addr = getattr(lesson.location, 'address', None)
                    location = lesson.location.name + (f", {addr}" if addr else "")

                subject = ""
                if lesson.sport:
                    subject = lesson.sport.name
                body = {
                    'summary': f'{lesson.get_students_name()} {subject} Lesson',
                    'location': location,
                    'start': {'dateTime': start_dt.isoformat(), 'timeZone': 'Europe/Lisbon'},
                    'end':   {'dateTime': end_dt.isoformat(),   'timeZone': 'Europe/Lisbon'},
                    'reminders': {
                        'useDefault': False,
                        'overrides': [
                            {'method': 'popup', 'minutes': 24 * 60},
                            {'method': 'popup', 'minutes': 60},
                            {'method': 'popup', 'minutes': 10},
                        ],
                    },
                }

                uid = str(user.pk)
                existing_id = lesson.calendar_event_ids.get(uid)

                if getattr(lesson, 'is_cancelled', False):
                    if existing_id:
                        service.events().delete(calendarId='primary', eventId=existing_id).execute()
                        lesson.calendar_event_ids[uid] = ''
                else:
                    if existing_id:
                        evt = service.events().patch(
                            calendarId='primary',
                            eventId=existing_id,
                            body=body
                        ).execute()
                    else:
                        evt = service.events().insert(
                            calendarId='primary',
                            body=body
                        ).execute()
                    lesson.calendar_event_ids[uid] = evt['id']

            lesson.needs_calendar_sync = False
            lesson.last_calendar_sync = timezone.now()
            lesson.save(update_fields=['calendar_event_ids', 'needs_calendar_sync', 'last_calendar_sync'])

        self.stdout.write(self.style.SUCCESS('All pending lessons have been synced.'))
