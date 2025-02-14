from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import PrivateClass, ClassTicket
from django.utils.timezone import now


def get_lessons_data(user, date_lookup, is_done_flag):
    """
    Helper function to get lessons data.
    
    :param user: The current authenticated user.
    :param date_lookup: A dict with the lookup to apply on dates 
                        (e.g. {'date__gte': today} for upcoming lessons)
    :param is_done_flag: Boolean indicating if lessons are completed.
                          Used in the filter for PrivateClass.
    :return: Combined list of private and group lessons data.
    """
    today = now().date()
    student_ids = user.students.values_list('id', flat=True)
    
    # Adjust the private class filters with the given parameters.
    private_lessons = PrivateClass.objects.filter(
        students__id__in=student_ids,
        is_done=is_done_flag,
        **date_lookup  # expects key like date__gte or date__lte with value today
    ).order_by('date', 'start_time')
    
    # Adjust the group class ticket filters similarly.
    # Note: is_used flag is always True, so we don't parameterize that.
    group_date_lookup = {f'group_class__{list(date_lookup.keys())[0]}': today}
    group_lessons_tickets = ClassTicket.objects.filter(
        student__id__in=student_ids,
        is_used=is_done_flag,
        **group_date_lookup
    ).order_by('group_class__date', 'group_class__start_time')

    # Process private lessons data.
    private_lessons_data = [
        {
            "id": lesson.id,
            "students_name": lesson.get_students_name(),
            "students_ids": lesson.get_students_ids(),
            "type": lesson.type,
            "lesson_number": lesson.class_number,
            "number_of_lessons": lesson.pack.number_of_classes,
            "date": lesson.date.strftime("%d %b"),
            "time": lesson.start_time.strftime("%I:%M %p"),
            "instructor_name": str(lesson.instructor) if lesson.instructor else "Unknown",
            "location_name": lesson.location.name if lesson.location else "Unknown",
            "location_link": lesson.location.link if lesson.location else "Unknown"
        }
        for lesson in private_lessons
    ]
    
    # Process group lessons data.
    group_lessons_data = [
        {
            "id": ticket.id,
            "students_name": str(ticket.student),
            "students_ids": list(f"{ticket.student.id}"),
            "type": ticket.group_class.type,
            "lesson_number": ticket.ticket_number,
            "number_of_lessons": ticket.pack.number_of_classes,
            "date": ticket.group_class.date.strftime("%d %b"),
            "time": ticket.group_class.start_time.strftime("%I:%M %p"),
            "instructors_name": ticket.group_class.get_instructors_name() if ticket.group_class.instructors else "Unknown",
            "location_name": ticket.group_class.location.name if ticket.group_class.location else "Unknown",
            "location_link": ticket.group_class.location.link if ticket.group_class.location else "Unknown"
        }
        for ticket in group_lessons_tickets
    ]
    
    # Combine both lesson types.
    lessons_data = private_lessons_data + group_lessons_data
    return lessons_data


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def upcoming_lessons(request):
    """
    Return lessons that are upcoming (date >= today) and not completed.
    """
    # For upcoming lessons, filter for date >= today and is_done False.
    lessons_data = get_lessons_data(
        user=request.user,
        date_lookup={'date__gte': now().date()},
        is_done_flag=False
    )
    return Response(lessons_data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def last_lessons(request):
    """
    Return lessons that have already occurred (date <= today) and are completed.
    """
    # For past lessons, filter for date <= today and is_done True.
    lessons_data = get_lessons_data(
        user=request.user,
        date_lookup={'date__lte': now().date()},
        is_done_flag=True
    )
    return Response(lessons_data)

def reschedule_lesson(request):
    return False

def active_packs(request):
    return False

def pack_datails(request):
    return False