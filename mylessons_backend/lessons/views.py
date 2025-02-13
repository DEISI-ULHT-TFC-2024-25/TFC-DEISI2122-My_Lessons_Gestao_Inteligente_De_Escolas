from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import PrivateClass, GroupClass
from datetime import datetime


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def upcoming_lessons(request):
    user = request.user  # Get the logged-in parent

    # Fetch upcoming private lessons
    private_lessons = PrivateClass.objects.filter(
        student__parent=user,
        date__gte=datetime.today()
    ).order_by('date', 'time')
    '''
    # Fetch upcoming group lessons where the student is enrolled
    group_lessons = GroupClass.objects.filter(
        students__parent=user,
        date__gte=datetime.today()
    ).order_by('date', 'time')

    # Serialize private lessons
    private_lessons_data = [
        {
            "id": lesson.id,
            "title": f"{lesson.get_students_first_name()}'s Private Lesson {lesson.class_number} of {lesson.pack.number_of_classes}",
            "date": lesson.date.strftime("%d %b"),
            "time": lesson.start_time.strftime("%I:%M %p"),
            "instructor_name": lesson.instructor.get_full_name() if lesson.instructor else "Unknown",
            "instructor_phone": lesson.instructor.get_phone() if lesson.instructor else "Unknown",
            "location_name": lesson.location.name if lesson.location else "Unknown",
            "location_link": lesson.location.link if lesson.location else "Unknown"
        }
        for lesson in private_lessons
    ]

    # Serialize group lessons
    group_lessons_data = [
        {
            "id": ticket.id,
            "title": f"{ticket.student.first_name}'s Group Lesson {ticket.lesson_number} of {lesson.})",
            "date": lesson.date.strftime("%d %b"),
            "time": lesson.time.strftime("%I:%M %p"),
            "instructor_name": lesson.instructor.get_full_name() if lesson.instructor else "Unknown",
            "instructor_phone": lesson.instructor.get_phone() if lesson.instructor else "Unknown",
            "location_name": lesson.location.name if lesson.location else "Unknown"
        }
        for ticket in group_lessons_tickets
    ]
    '''
    

    # Combine both lessons into a single response
    #lessons_data = private_lessons_data + group_lessons_data

    #return Response(lessons_data)
    return False

def last_lessons(request):
    return False

def reschedule_lesson(request):
    return False

def active_packs(request):
    return False

def pack_datails(request):
    return False