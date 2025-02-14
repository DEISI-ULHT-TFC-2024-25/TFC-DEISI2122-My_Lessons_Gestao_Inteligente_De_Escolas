from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import PrivateClass, ClassTicket
from django.utils.timezone import now


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def upcoming_lessons(request):
    today = now().date()
    user = request.user

    student_ids = user.students.values_list('id', flat=True)

    private_lessons = PrivateClass.objects.filter(
        students__id__in=student_ids,
        date__gte=today,
        is_done=False
    ).order_by('date', 'start_time')
    
    group_lessons_tickets = ClassTicket.objects.filter(
        student__id__in=student_ids,
        group_class__date__gte=today,
        is_used=True
    ).order_by('group_class__date', 'group_class__start_time')

    print(group_lessons_tickets)

    private_lessons_data = [
        {
            "id": lesson.id,
            "students_name": f"{lesson.get_students_name()}",
            "students_ids": f"{lesson.get_students_ids()}",
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

    group_lessons_data = [
        {
            "id": ticket.id,
            "students_name": f"{ticket.student}",
            "students_ids": f"[{ticket.student.id}]",
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
    
    lessons_data = private_lessons_data + group_lessons_data

    return Response(lessons_data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def last_lessons(request):
    today = now().date()
    user = request.user

    student_ids = user.students.values_list('id', flat=True)

    private_lessons = PrivateClass.objects.filter(
        students__id__in=student_ids,
        date__lte=today,
        is_done=True
    ).order_by('date', 'start_time')
    
    group_lessons_tickets = ClassTicket.objects.filter(
        student__id__in=student_ids,
        group_class__date__lte=today,
        is_used=True
    ).order_by('group_class__date', 'group_class__start_time')

    print(group_lessons_tickets)

    private_lessons_data = [
        {
            "id": lesson.id,
            "students_name": f"{lesson.get_students_name()}",
            "students_ids": f"{lesson.get_students_ids()}",
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

    group_lessons_data = [
        {
            "id": ticket.id,
            "students_name": f"{ticket.student}",
            "students_ids": f"[{ticket.student.id}]",
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
    
    lessons_data = private_lessons_data + group_lessons_data

    return Response(lessons_data)

def reschedule_lesson(request):
    return False

def active_packs(request):
    return False

def pack_datails(request):
    return False