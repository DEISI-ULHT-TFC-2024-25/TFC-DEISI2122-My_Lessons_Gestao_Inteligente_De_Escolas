

from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.utils import timezone
from .models import *
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
import json
from google.auth.transport.requests import Request
from datetime import timedelta, datetime
import pytz
import re

"""
def update_calendar(user, classes, group_class):

    service = get_calendar_service(user)

    if service is None:
        return

    lisbon_tz = pytz.timezone('Europe/Lisbon')
    now = timezone.now().astimezone(lisbon_tz)

    # Calculate the end date, 3 months from now, in the Lisbon timezone
    a_year_later = now + timedelta(days=365)

    # Convert both times to UTC for querying Google Calendar
    # Get the current time in UTC
    now = now.astimezone(pytz.utc)

    # Calculate the time for a week ago
    a_week_ago = now - timedelta(weeks=1)

    # Convert it to ISO 8601 format
    time_min = a_week_ago.isoformat()
    time_max = a_year_later.astimezone(pytz.utc).isoformat()

    try:
        # Fetch the events from Google Calendar
        events_result = service.events().list(
            calendarId='primary',
            timeMin=time_min,
            timeMax=time_max,
            singleEvents=True,
            orderBy='startTime'
        ).execute()

        events = events_result.get('items', [])

        if group_class:
            # Filter events where the title ends with "class" and the description starts with "Group class"
            filtered_events = [
                event for event in events
                if event.get('summary', '').lower().endswith('class') and event.get('description', '').startswith('Group class')
            ]
        else:
            filtered_events = [
                event for event in events
                if re.search(r'class number \d+ of \d+', event.get('summary', '').lower())
            ]

        matched_classes = set()

        # Check each event against the class database
        for event in filtered_events:
            event_id = event['id']
            date_time_str = event['start'].get('dateTime', event['start'].get('date'))
            date_time = parse_event_datetime(date_time_str).astimezone(lisbon_tz)
            event_summary = event.get('summary', '')
            event_description = event.get('description', '')

            matched_class = None
            for class_instance in classes:
                if group_class:
                    tickets = class_instance.tickets.all()
                    expected_summary = ", ".join([str(ticket.student.first_name) for ticket in tickets])
                    expected_summary += "'s class"
                    expected_description = f"Group class | id:{class_instance.id}"
                else:
                    expected_summary = f"{class_instance.pack.student_group}'s class number {class_instance.class_number} of {class_instance.pack.number_of_classes}"
                    expected_description = event_description

                if expected_summary == event_summary and expected_description == event_description:
                    if not group_class and event_description != class_instance.feedback:
                        if event_description:
                            # Update class_instance feedback
                            class_instance.feedback = event_description
                            class_instance.save()
                        elif class_instance.feedback:
                            # Update the Google Calendar event description with class_instance feedback
                            event = service.events().get(calendarId='primary', eventId=event_id).execute()
                            event['description'] = class_instance.feedback

                            # Use the Google Calendar API to update the event
                            updated_event = service.events().update(calendarId='primary', eventId=event_id, body=event).execute()

                            # Optionally log or print the updated event
                            print(f"Event description updated to: {updated_event['description']}")

                    matched_class = class_instance
                    matched_classes.add(class_instance.id)
                    break

            if matched_class:
                # Handle classes with missing date or time
                if not matched_class.date or not matched_class.time:
                    if group_class:
                        tickets = matched_class.tickets.all()
                        student_names = ", ".join([str(ticket.student.first_name) for ticket in tickets])
                        print(
                            f"Class '{student_names}' no longer has a date or time, deleting event '{event_summary}' from calendar."
                        )
                    else:
                        print(
                            f"Class '{matched_class.pack.student_group}' no longer has a date or time, deleting event '{event_summary}' from calendar."
                        )
                    # Delete the event
                    response = service.events().delete(calendarId='primary', eventId=event_id).execute()
                    if response == {}:
                        print(f"Successfully deleted event: {event_summary}")
                    continue

                # Check for date/time mismatches between event and class
                if matched_class.date != date_time.date() or matched_class.time != date_time.time():
                    print(
                        f"Event mismatch: '{event_summary}' scheduled on {date_time.date()} at {date_time.time()} "
                        f"but class is scheduled for {matched_class.date} at {matched_class.time}."
                    )
                    # Delete the mismatched event
                    response = service.events().delete(calendarId='primary', eventId=event_id).execute()
                    if response == {}:
                        print(f"Successfully deleted mismatched event: {event_summary}")
            else:
                print(f"Orphaned event: '{event_summary}' on {date_time.date()} at {date_time.time()}")
                response = service.events().delete(calendarId='primary', eventId=event_id).execute()
                if response == {}:
                    print(f"Successfully deleted orphaned event: {event_summary}")

        # Check for classes that are not scheduled in Google Calendar
        for class_instance in classes:
            if class_instance.id not in matched_classes:
                if group_class:
                    tickets = class_instance.tickets.all()
                    student_names = ", ".join([str(ticket.student.first_name) for ticket in tickets])
                    print(
                        f"Class not scheduled in Google Calendar: '{student_names}' "
                        f"on {class_instance.date} at {class_instance.time}."
                    )
                else:
                    print(
                        f"Class not scheduled in Google Calendar: '{class_instance.pack.student_group}' "
                        f"on {class_instance.date} at {class_instance.time}."
                    )

                # Create the missing event
                start_datetime = datetime.combine(class_instance.date, class_instance.time)
                if group_class:
                    end_datetime = start_datetime + timedelta(hours=1)
                else:
                    if class_instance.end_time:
                        end_datetime = datetime.combine(class_instance.date, class_instance.end_time)
                    else:
                        end_datetime = start_datetime + timedelta(hours=1)  # Assuming 1-hour class
                create_google_event(service, class_instance, start_datetime, end_datetime, lisbon_tz, group_class)
                print(f"Created event for class {class_instance} | {user} | {user.first_name} {user.last_name}")

        return

    except Exception as e:
        print(f"Error fetching events: {e}")
        return
"""

def parse_event_datetime(start_time_str):
    # If the time ends with 'Z', replace 'Z' with '+00:00' for UTC
    if start_time_str.endswith('Z'):
        start_time_str = start_time_str.replace('Z', '+00:00')
    # Parse the ISO 8601 string into a datetime object
    return datetime.fromisoformat(start_time_str)

"""
def create_google_event(service, class_instance, start_datetime, end_datetime, lisbon_tz, group_class):
    # Localize the start and end datetime objects to the Lisbon timezone
    localized_start_time = lisbon_tz.localize(start_datetime)
    localized_end_time = lisbon_tz.localize(end_datetime)

    if group_class:
        tickets = class_instance.tickets.all()
        student_names = ", ".join([str(ticket.student.first_name) for ticket in tickets])
        event = {
            'summary': f"{student_names}'s class",
            'location': "PDG",
            'description': f"Group class | id:{class_instance.id}",
            'start': {
                'dateTime': localized_start_time.isoformat(),
                'timeZone': 'Europe/Lisbon',
            },
            'end': {
                'dateTime': localized_end_time.isoformat(),
                'timeZone': 'Europe/Lisbon',
            },
            'reminders': {
                'useDefault': False,
                'overrides': [
                    {'method': 'popup', 'minutes': 60},  # 1 hour before
                    {'method': 'popup', 'minutes': 10},  # 10 minutes before
                ],
            },
        }
    else:
        # Prepare the event details with Lisbon time zone
        event = {
            'summary': f"{class_instance.pack.student_group}'s class number {class_instance.class_number} of {class_instance.pack.number_of_classes}",
            'location': class_instance.location,
            'description': class_instance.feedback,
            'start': {
                'dateTime': localized_start_time.isoformat(),
                'timeZone': 'Europe/Lisbon',
            },
            'end': {
                'dateTime': localized_end_time.isoformat(),
                'timeZone': 'Europe/Lisbon',
            },
            'reminders': {
                'useDefault': False,
                'overrides': [
                    {'method': 'popup', 'minutes': 60},  # 1 hour before
                    {'method': 'popup', 'minutes': 10},  # 10 minutes before
                ],
            },
        }

    service.events().insert(calendarId='primary', body=event).execute()
"""

def get_calendar_service(user):
    """
    Retrieves the Google Calendar service for a given user.
    Refreshes the credentials if they are expired.
    """
    try:
        user_credentials = UserCredentials.objects.get(user=user)
        creds = user_credentials.get_credentials()

        if creds:
            # Build and return the Google Calendar service object
            service = build('calendar', 'v3', credentials=creds)
            return service

        return None

    except UserCredentials.DoesNotExist:
        # Handle the case where no credentials are stored for the user
        return None


def get_users_name(users_list):
    
    if len(users_list) == 1:
        return str(users_list[0])
    elif len(users_list) > 1:
        users_names = ", ".join([f"{users.first_name}" for users in users_list])
        return users_names
    else:
        return "No Students"
    
def get_students_ids(students_list):

    students_ids = [f"{student.id}" for student in students_list]
    return students_ids

def get_instructors_ids(instructors_list):

    instructors_ids = [f"{instructor.id}" for instructor in instructors_list]
    return instructors_ids

def get_phone(user):
    if user.country_code and user.phone:
        return f"{user.country_code}{user.phone}"
    
def get_instructors_name(instructors_list):
    
    if len(instructors_list) == 1:
        return str(instructors_list[0].user)
    elif len(instructors_list) > 1:
        users_names = ", ".join([f"{instructor.user.first_name}" for instructor in instructors_list])
        return users_names
    else:
        return "No Instructors"
    
