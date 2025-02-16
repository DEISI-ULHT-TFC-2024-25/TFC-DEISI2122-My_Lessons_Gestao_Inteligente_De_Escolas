from datetime import datetime
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import PrivateClass, ClassTicket, PrivatePack, GroupPack
from django.utils.timezone import now
from rest_framework import status
from django.shortcuts import get_object_or_404


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

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def schedule_private_lesson(request):
    """
    Permite aos pais/instrutores reagendarem uma aula privada.
    """
    user = request.user
    lesson_id = request.data.get("lesson_id")
    new_date = request.data.get("date")  # Formato esperado: 'YYYY-MM-DD'
    new_time = request.data.get("time")  # Formato esperado: 'HH:MM'

    # Validação inicial
    if not lesson_id or not new_date or not new_time:
        return Response({"error": "É necessário fornecer lesson_id, date e time."},
                        status=status.HTTP_400_BAD_REQUEST)

    try:
        lesson = PrivateClass.objects.get(id=lesson_id)
    except PrivateClass.DoesNotExist:
        return Response({"error": "Aula não encontrada."}, status=status.HTTP_404_NOT_FOUND)

    # Verifica se o utilizador pode reagendar esta aula (somente pais da pack ou instrutores)
    if not lesson.pack.parents.filter(id=user.id).exists() and lesson.instructor.user != user:
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
    if new_date_obj < now().date():
        return Response({"error": "Não é possível agendar para uma data no passado."},
                        status=status.HTTP_400_BAD_REQUEST)
    
    if not lesson.can_still_reschedule():
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
    student_ids = user.students.values_list('id', flat=True)

    # Fetch active private packs
    private_packs = PrivatePack.objects.filter(students__id__in=student_ids, is_done=False)
    # Fetch active group packs
    group_packs = GroupPack.objects.filter(student__id__in=student_ids, is_done=False)

    packs_data = []

    # Process private packs
    for pack in private_packs:
        packs_data.append({
            "pack_id": pack.id,
            "students_name": pack.get_students_name(),
            "students_ids": pack.get_students_ids(),
            "type": pack.type,
            "lessons_remaining": pack.get_number_of_lessons_remaining(),
            "unscheduled_lessons": pack.get_number_of_unscheduled_lessons(),
            "days_until_expiration": (pack.expiration_date - today).days if pack.expiration_date else None
        })

    # Process group packs
    for pack in group_packs:
        packs_data.append({
            "pack_id": pack.id,
            "students_name": str(pack.student),
            "students_ids": list(f"{pack.student.id}"),
            "type": pack.type,
            "lessons_remaining": pack.get_number_of_lessons_remaining(),
            "unscheduled_lessons": pack.get_number_of_unscheduled_lessons(),
            "days_until_expiration": (pack.expiration_date - today).days if pack.expiration_date else None
        })

    return Response(packs_data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def private_pack_details(request, id):
    user = request.user
    pack = get_object_or_404(PrivatePack, id=id, parents=user)

    data = {
        "id": pack.id,
        "date": pack.date,
        "type": pack.type,
        "number_of_classes": pack.number_of_classes,
        "duration_in_minutes": pack.duration_in_minutes,
        "price": str(pack.price),
        "is_done": pack.is_done,
        "is_paid": pack.is_paid,
        "is_suspended": pack.is_suspended,
        "debt": str(pack.debt),
        "students": [{"id": s.id, "name": str(s)} for s in pack.students.all()],
        "finished_date": pack.finished_date,
        "expiration_date": pack.expiration_date,
        "school": pack.school.name if pack.school else None,
        "sport": pack.sport.name if pack.sport else None,
        "instructor": {
            "id": pack.instructor.id,
            "name": str(pack.instructor),
        } if pack.instructor else None
    }
    
    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def group_pack_details(request, id):
    user = request.user
    pack = get_object_or_404(GroupPack, id=id, parents=user)

    data = {
        "id": pack.id,
        "date": pack.date,
        "type": pack.type,
        "number_of_classes": pack.number_of_classes,
        "number_of_classes_left": pack.number_of_classes_left,
        "duration_in_minutes": pack.duration_in_minutes,
        "price": str(pack.price),
        "is_done": pack.is_done,
        "is_paid": pack.is_paid,
        "is_suspended": pack.is_suspended,
        "debt": str(pack.debt),
        "student": {
            "id": pack.student.id,
            "name": str(pack.student),
        } if pack.student else None,
        "finished_date": pack.finished_date,
        "expiration_date": pack.expiration_date,
        "school": pack.school.name if pack.school else None,
        "sport": pack.sport.name if pack.sport else None,
    }
    
    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def private_lesson_details(request, id):
    # Get the private class object or return 404 if not found
    private_lesson = get_object_or_404(PrivateClass, id=id)

    # Construct response data
    data = {
        "id": private_lesson.id,
        "date": private_lesson.date,
        "start_time": private_lesson.start_time,
        "end_time": private_lesson.end_time,
        "duration": private_lesson.duration_in_minutes,
        "class_number": private_lesson.class_number,
        "price": str(private_lesson.price),
        "is_done": private_lesson.is_done,
        "location": private_lesson.location.name if private_lesson.location else None,
        "instructor": {
            "id": private_lesson.instructor.id,
            "name": str(private_lesson.instructor),
            
        } if private_lesson.instructor else None,
        "students": [
            {"id": student.id, "name": str(student)}
            for student in private_lesson.students.all()
        ],
        "extra_students": [
            {"id": student.id, "name": str(student)}
            for student in private_lesson.extra_students.all()
        ],
        "number_of_extra_students": private_lesson.number_of_extra_students,
        "equipments": [
            {"id": equipment.id, "name": equipment.name}
            for equipment in private_lesson.equipments.all()
        ],
        "sport": private_lesson.sport.name if private_lesson.sport else None,
        "school": private_lesson.school.name if private_lesson.school else None,
        "pack_id": private_lesson.pack.id if private_lesson.pack else None,
        "type": private_lesson.type,
    }

    return Response(data)


def group_lesson_details(response):
    return False