from datetime import datetime
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Lesson, Pack
from django.utils.timezone import now
from rest_framework import status
from django.shortcuts import get_object_or_404


# TODO change all views to work on specific roles (user.current_role)
# TODO refactor packs data
# on instructor or admin schedule private lesson if the time is unavailable because of his unavailability or pecause its in the past there should be an alert message and an option to override



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
    lessons = list(set(Lesson.objects.filter(
        students__id__in=student_ids,
        is_done=is_done_flag,
        **date_lookup  # expects key like date__gte or date__lte with value today
    ).order_by('date', 'start_time')))

    # Process private lessons data.
    lessons_data = [
        {
            "lesson_id": lesson.id,
            "date": lesson.date.strftime("%d %b") if lesson.date else "None",
            "start_time": lesson.start_time.strftime("%I:%M %p") if lesson.start_time else "None",
            "lesson_number": lesson.class_number if lesson.class_number else "None", # TODO fix for group lessons
            "number_of_lessons": lesson.pack.number_of_classes if lesson.pack else "None", # TODO fix for group lessons
            "students_name": lesson.get_students_name(),
            "type": lesson.type,
            "duration_in_minutes": lesson.duration_in_minutes,
        }
        for lesson in lessons
    ]
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

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def schedule_private_lesson(request):
    """
    Permite aos pais/instrutores reagendarem uma aula privada.
    """
    user = request.user
    current_role = user.current_role
    lesson_id = request.data.get("lesson_id")
    new_date = request.data.get("new_date")  # Formato esperado: 'YYYY-MM-DD'
    new_time = request.data.get("new_time")  # Formato esperado: 'HH:MM'
    """
    {
    "lesson_id": 1,
    "new_date": "2025-02-21",
    "new_time": "16:00"
}

    """
    

    # Validação inicial
    if not lesson_id or not new_date or not new_time:
        return Response({"error": "É necessário fornecer lesson_id, date e time."},
                        status=status.HTTP_400_BAD_REQUEST)

    try:
        lesson = Lesson.objects.get(id=lesson_id)
    except Lesson.DoesNotExist:
        return Response({"error": "Aula não encontrada."}, status=status.HTTP_404_NOT_FOUND)

    # Verifica se o utilizador pode reagendar esta aula (somente pais da pack ou instrutores ou admins)
    if not lesson.pack.parents.filter(id=user.id).exists() and not lesson.instructors.filter(user=user).exists():
        return Response({"error": "Não tem permissão para agendar esta aula."},
                        status=status.HTTP_403_FORBIDDEN)

    # Converte strings para objetos `datetime`
    try:
        new_date_obj = datetime.strptime(new_date, "%Y-%m-%d").date()
        new_time_obj = datetime.strptime(new_time, "%H:%M").time()
    except ValueError:
        return Response({"error": "Formato de data ou hora inválido."}, status=status.HTTP_400_BAD_REQUEST)


    # Verifica se ainda é possível reagendar esta aula

    # Verifica se ainda é possível reagendar esta aula

    # TODO make aware

    if new_date_obj < now().date():
        return Response({"error": "Não é possível agendar para uma data no passado."},
                        status=status.HTTP_400_BAD_REQUEST)
    
    if current_role == "Parent" and not lesson.can_still_reschedule():
        return Response({"error": "O período permitido para agendamento já passou."},
                        status=status.HTTP_400_BAD_REQUEST)

    # Tenta reagendar a aula
    reschedule_success = lesson.schedule_lesson(new_date_obj, new_time_obj)

    if reschedule_success:
        return Response({"message": "Aula agendada com sucesso!"}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "Não foi possível agendar. Data e horário não disponíveis."},
                        status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def active_packs(request):
    today = now().date()
    user = request.user  # Get authenticated user
    current_role = user.current_role

    if current_role == "Parent":
        # Fetch active packs
        student_ids = user.students.values_list('id', flat=True)
        packs = list(set(Pack.objects.filter(students__id__in=student_ids, is_done=False)))
    elif current_role == "Instructor":
        packs = list(set(Pack.objects.filter(lessons__instructors__in=[user.instructor_profile], is_done=False))) # TODO combile those filters with pack.instructors__in=[user.instructor_profile]
    elif current_role == "Admin":
        packs = list(set(Pack.objects.filter(school__in=user.school_admins.all(), is_done=False)))
    else:
        packs = []

    packs_data = [
        {
            "pack_id": pack.id,
            "lessons_remaining": pack.number_of_classes_left,
            "unscheduled_lessons": pack.get_number_of_unscheduled_lessons(),
            "days_until_expiration": (pack.expiration_date - today).days if pack.expiration_date else None,
            "students_name": pack.get_students_name(),
            "type": pack.type
        }
        for pack in packs
    ]
    return Response(packs_data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def pack_details(request, id):
    today = now().date()
    user = request.user
    pack = get_object_or_404(Pack, id=id)

    # TODO      students : {
    #               student_id : {
    #                   student_first_name,
    #                   student_last_name,
    #                   parents?
    #               } 
    #           }
    # TODO add parents
    # TODO structure students and instructors better

    data = {
        "pack_id": pack.id,
        "date": pack.date,
        "type": pack.type,
        "number_of_classes": pack.number_of_classes,
        "lessons_remaining": pack.number_of_classes_left,
        "unscheduled_lessons": pack.get_number_of_unscheduled_lessons(),
        "days_until_expiration": (pack.expiration_date - today).days if pack.expiration_date else None,
        "expiration_date": pack.expiration_date,
        "duration_in_minutes": pack.duration_in_minutes,
        "price": str(pack.price),
        "is_done": pack.is_done,
        "is_paid": pack.is_paid,
        "is_suspended": pack.is_suspended,
        "debt": str(pack.debt),
        "students_name": pack.get_students_name(),
        "students_ids": pack.get_students_ids(),
        "instructors_name": pack.get_instructors_name() if pack.instructors.exists() else "Unknown",
        "instructors_ids": pack.get_instructors_ids() if pack.instructors.exists() else "Unknown",
        "finished_date": pack.finished_date,
        "school_name": str(pack.school) if pack.school else "Unknown",
        "school_id": pack.school.id if pack.school else "Unknown",
        "sport": pack.sport.name if pack.sport else None,
    }
    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def lesson_details(request, id):
    today = now().date()
    user = request.user
    lesson = get_object_or_404(Lesson, id=id)

    # TODO      students : {
    #               student_id : {
    #                   student_first_name,
    #                   student_last_name,
    #                   parents?
    #               } 
    #           }
    # TODO add parents
    # TODO structure students and instructors better

    data = {
            "lesson_id": lesson.id,
            "date": lesson.date.strftime("%d %b") if lesson.date else "None",
            "start_time": lesson.start_time.strftime("%I:%M %p") if lesson.start_time else "None",
            "end_time": lesson.end_time.strftime("%I:%M %p") if lesson.end_time else "None",
            "duration_in_minutes": lesson.duration_in_minutes,
            "lesson_number": lesson.class_number,
            "number_of_lessons": lesson.pack.number_of_classes if lesson.pack else "None",
            "price": lesson.price,
            "is_done": lesson.is_done,
            "extras": lesson.extras,
            "students_name": lesson.get_students_name(),
            "students_ids": lesson.get_students_ids(),
            "type": lesson.type,
            "instructors_name": lesson.get_instructors_name() if lesson.instructors.exists() else "Unknown",
            "instructors_ids": lesson.get_instructors_ids() if lesson.instructors.exists() else "Unknown",
            "location_name": lesson.location.name if lesson.location else "Unknown",
            "location_link": lesson.location.link if lesson.location else "Unknown",
            "minimum_age": lesson.minimum_age,
            "maximum_age": lesson.maximum_age,
            "maximum_number_of_students": lesson.maximum_number_of_students,
            "school_name": str(lesson.school) if lesson.school else "Unknown",
            "school_id": lesson.school.id if lesson.school else "Unknown",
            "pack_id": lesson.pack.id if lesson.pack else "Unknown",
            "sport_name": lesson.sport.name if lesson.sport else "Unknown",
        }
    return Response(data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def todays_lessons(request):
    """
    Return lessons that have already occurred today
    """

    user = request.user
    current_role = user.current_role
    today = now().date()

    if current_role == "Instructor":

        lessons = list(set(Lesson.objects.filter(
            instructors__in=[user.instructor_profile],
            date=today
        ).order_by('date', 'start_time')))

        # Process private lessons data.
        lessons_data = [
            {
                "lesson_id": lesson.id,
                "start_time": lesson.start_time.strftime("%I:%M %p") if lesson.start_time else "None",
                "lesson_number": lesson.class_number,
                "number_of_lessons": lesson.pack.number_of_classes,
                "students_name": lesson.get_students_name(),
                "location_name": lesson.location.name if lesson.location else "None",
            }
            for lesson in lessons
        ]
    elif current_role == "Admin":

        lessons = list(set(Lesson.objects.filter(
            school__in=[user.school_admins],
            date=today
        ).order_by('date', 'start_time')))

        # Process private lessons data.
        lessons_data = [
            {
                "lesson_id": lesson.id,
                "start_time": lesson.start_time.strftime("%I:%M %p") if lesson.start_time else "None",
                "instructors_name": lesson.get_instructors_name() if lesson.instructors.exists() else "Unknown",
                "location_name": lesson.location.name if lesson.location else "None",
            }
            for lesson in lessons
        ]
    
    
    
    
    return Response(lessons_data)

def process_lesson_status(request, mark_as_done=True):
    """
    Função auxiliar para marcar uma aula como feita ou não feita.
    """
    user = request.user
    current_role = user.current_role
    lesson_id = request.data.get("lesson_id")
    
    if not lesson_id:
        return Response({"error": "É necessário fornecer lesson_id"}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        lesson = Lesson.objects.get(id=lesson_id)
    except Lesson.DoesNotExist:
        return Response({"error": "Aula não encontrada."}, status=status.HTTP_404_NOT_FOUND)
    
    if current_role == "Parent":
        return Response({"error": "Não tem permissão para alterar esta aula."}, status=status.HTTP_403_FORBIDDEN)
    
    success = lesson.mark_as_given() if mark_as_done else lesson.mark_as_not_given()
    
    if success:
        return Response({"message": "Aula alterada com sucesso!"}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "Não foi possível alterar a aula."}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_lesson_as_done(request):
    """
    Permite aos instrutores ou admins marcar uma aula como realizada.
    """
    return process_lesson_status(request, mark_as_done=True)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_lesson_as_not_done(request):
    """
    Permite aos instrutores ou admins marcar uma aula como não realizada.
    """
    return process_lesson_status(request, mark_as_done=False)
