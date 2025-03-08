from datetime import datetime, timedelta
import json
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
    lessons = Lesson.objects.filter(
        students__id__in=student_ids,
        is_done=is_done_flag,
        **date_lookup  # expects key like date__gte or date__lte with value today
    ).order_by('date', 'start_time').distinct()

    # Process private lessons data.
    lessons_data = [
        {
            "lesson_id": lesson.id,
            "date": lesson.date.strftime("%d %b %Y") if lesson.date else "None",
            "start_time": lesson.start_time.strftime("%H:%M") if lesson.start_time else "None",
            "lesson_number": lesson.class_number if lesson.class_number else "None", # TODO fix for group lessons
            "number_of_lessons": lesson.pack.number_of_classes if lesson.pack else "None", # TODO fix for group lessons
            "students_name": lesson.get_students_name(),
            "type": lesson.type,
            "duration_in_minutes": lesson.duration_in_minutes,
            "expiration_date": lesson.pack.expiration_date if lesson.pack and lesson.pack.expiration_date else "None"
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


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def active_packs(request):
    today = now().date()
    user = request.user  # Get authenticated user
    current_role = user.current_role

    if current_role == "Parent":
        # Fetch active packs
        student_ids = user.students.values_list('id', flat=True)
        packs = Pack.objects.filter(students__id__in=student_ids, is_done=False).order_by("-date_time").distinct()
    elif current_role == "Instructor":
        packs = Pack.objects.filter(lessons__instructors__in=[user.instructor_profile], is_done=False).order_by("-date_time").distinct() # TODO combile those filters with pack.instructors__in=[user.instructor_profile]
    elif current_role == "Admin":
        packs = Pack.objects.filter(school__in=user.school_admins.all(), is_done=False).order_by("-date_time").distinct()
    else:
        packs = []

    packs_data = [
        {
            "pack_id": pack.id,
            "lessons": [
                            {
                                "lesson_id" : str(lesson.id),
                                "lesson_str": str(lesson)
                            }
                            for lesson in pack.lessons.all()
                        ],
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



@api_view(['POST'])
@permission_classes([IsAuthenticated])
def available_lesson_times(request):
    """
    Receives a lesson_id and a date (YYYY-MM-DD) and returns a list of available times for the lesson.
    Only works for lessons of type "private".
    """
    lesson_id = request.data.get("lesson_id")
    date_str = request.data.get("date")
    increment = request.data.get("increment")
    
    # Validate required parameters.
    if not lesson_id or not date_str or not increment:
        return Response({"error": "Missing lesson_id or date parameter."}, status=400)
    
    try:
        # Convert the date string to a date object.
        date_obj = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        return Response({"error": "Invalid date format. Expected YYYY-MM-DD."}, status=400)
    
    try:
        lesson = Lesson.objects.get(pk=lesson_id)
    except Lesson.DoesNotExist:
        return Response({"error": "Lesson not found."}, status=404)
    
    # Get available times from the lesson method.
    available_times = lesson.list_available_lesson_times(date_obj, increment)
    
    return Response({"available_times": available_times})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def can_still_reschedule(request, id):
    try:
        lesson = Lesson.objects.get(pk=id)
    except Lesson.DoesNotExist:
        return Response({"error": "Lesson not found."}, status=404)
    
    # Call the lesson's method which returns a boolean.
    result = lesson.can_still_reschedule(role=request.user.current_role)
    
    # Return the boolean value directly.
    return Response(result, status=200)


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
    
    if current_role == "Parent" and not lesson.can_still_reschedule(current_role):
        return Response({"error": "O período permitido para agendamento já passou."},
                        status=status.HTTP_400_BAD_REQUEST)

    # Tenta reagendar a aula
    reschedule_success = lesson.schedule_lesson(new_date_obj, new_time_obj)

    if reschedule_success:
        return Response({"message": "Aula agendada com sucesso!"}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "Não foi possível agendar. Data e horário não disponíveis."},
                        status=status.HTTP_400_BAD_REQUEST)
        

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def schedule_multiple_lessons(request):
    """
    Simula o agendamento múltiplo de aulas utilizando vários blocos de Data.
    
    Se o campo schedule_flag for verdadeiro, para cada aula o método
    lesson.schedule_lesson(date_obj, time_obj) é chamado para agendar a aula.
    Caso contrário, utiliza-se lesson.is_available para simular a disponibilidade.
    
    O payload de resposta para cada aula inclui:
      - "new_date", "new_time", "weekday"
      - "instructor_ids": lista dos IDs dos instrutores disponíveis (ou o utilizado no agendamento)
      - "instructors_str": lista dos respectivos valores de string
    """
    schedule_flag = request.data.get("schedule_flag", False)
    if isinstance(schedule_flag, str):
        schedule_flag = schedule_flag.lower() in ["true", "1"]

    # Obter os IDs das aulas
    lesson_ids = request.data.get("lesson_ids")
    if not lesson_ids:
        return Response({"error": "É necessário fornecer lesson_ids"}, status=400)
    if isinstance(lesson_ids, str):
        try:
            lesson_ids = json.loads(lesson_ids)
        except Exception:
            return Response({"error": "Formato inválido para lesson_ids"}, status=400)

    # Obter os dados de agendamento (blocos)
    schedule_data = request.data.get("Data")
    if not schedule_data or not isinstance(schedule_data, list) or len(schedule_data) == 0:
        return Response({"error": "É necessário fornecer a chave 'Data' com uma lista de opções."}, status=400)
    
    # Ordena os blocos por from_date (assumindo formato "YYYY-MM-DD")
    try:
        sorted_blocks = sorted(schedule_data, key=lambda b: datetime.strptime(b.get("from_date", ""), "%Y-%m-%d").date())
    except Exception:
        return Response({"error": "Erro ao ordenar os blocos de Data."}, status=400)
    
    # Mapeamento de nomes de dias para números (Monday=0, ..., Sunday=6)
    weekday_map = {
        "monday": 0, "tuesday": 1, "wednesday": 2,
        "thursday": 3, "friday": 4, "saturday": 5, "sunday": 6
    }
    
    def get_date_for_weekday(from_date_str, to_date_str, weekday_str):
        try:
            from_date = datetime.strptime(from_date_str, "%Y-%m-%d").date()
            to_date = datetime.strptime(to_date_str, "%Y-%m-%d").date()
        except ValueError:
            return None
        
        target_weekday = weekday_map.get(weekday_str.lower())
        if target_weekday is None:
            return None
        
        days_ahead = (target_weekday - from_date.weekday() + 7) % 7
        candidate_date = from_date + timedelta(days=days_ahead)
        if candidate_date > to_date:
            return None
        return candidate_date

    # Busca as aulas (na ordem dada)
    lessons = []
    for lesson_id in lesson_ids:
        try:
            lesson = Lesson.objects.get(id=lesson_id)
            lessons.append(lesson)
        except Lesson.DoesNotExist:
            return Response({"error": f"Aula com id {lesson_id} não encontrada."}, status=404)
    
    scheduled_results = {}
    unscheduled_lessons = lessons[:]
    
    for block in sorted_blocks:
        if not unscheduled_lessons:
            break
        block_from = block.get("from_date")
        block_to = block.get("to_date")
        options = block.get("options", [])
        if not block_from or not block_to or not options:
            continue
        
        try:
            block_from_date = datetime.strptime(block_from, "%Y-%m-%d").date()
            block_to_date = datetime.strptime(block_to, "%Y-%m-%d").date()
        except ValueError:
            continue
        
        block_options = []
        for option in options:
            weekday_str = option.get("weekday")
            time_str = option.get("time")
            if not weekday_str or not time_str:
                continue
            base_date = get_date_for_weekday(block_from, block_to, weekday_str)
            if base_date:
                block_options.append((base_date, time_str))
        if not block_options:
            continue
        
        sorted_options = sorted(block_options, key=lambda x: x[0])
        num_options = len(sorted_options)
        
        scheduled_this_block = []
        for j, lesson in enumerate(unscheduled_lessons):
            option_index = j % num_options
            cycle_count = j // num_options
            base_date, time_str = sorted_options[option_index]
            candidate_date = base_date + timedelta(days=7 * cycle_count)
            if candidate_date > block_to_date:
                break
            try:
                candidate_time = datetime.strptime(time_str, "%H:%M").time()
            except ValueError:
                continue
            
            available_instructors = []
            if schedule_flag:
                # Actually schedule the lesson.
                scheduled_success = lesson.schedule_lesson(candidate_date, candidate_time)
                if not scheduled_success:
                    continue
                # Use a default instructor (e.g., the first one) if available.
                if lesson.instructors.exists():
                    available_instructors = [lesson.instructors.first()]
                else:
                    available_instructors = []
            else:
                if lesson.instructors.exists():
                    for instructor in lesson.instructors.all():
                        available, ret_instructor = lesson.is_available(
                            date=candidate_date,
                            start_time=candidate_time,
                            instructor=instructor
                        )
                        if available:
                            available_instructors.append(ret_instructor)
                    if not available_instructors:
                        continue
                else:
                    available, ret_instructor = lesson.is_available(
                        date=candidate_date,
                        start_time=candidate_time,
                        instructor=None
                    )
                    if available:
                        available_instructors = [ret_instructor]
                    else:
                        continue
            
            weekday_out = candidate_date.strftime("%A")
            old_date_str = lesson.date.strftime("%Y-%m-%d") if lesson.date else ""
            old_time_str = lesson.start_time.strftime("%H:%M") if lesson.start_time else ""
            lesson_str = f"{lesson.get_students_name()} lesson number {lesson.class_number}/{lesson.pack.number_of_classes}"
            scheduled_results[lesson.id] = {
                "lesson_id": str(lesson.id),
                "lesson_str": lesson_str,
                "new_date": candidate_date.strftime("%Y-%m-%d"),
                "new_time": candidate_time.strftime("%H:%M"),
                "old_date": old_date_str,
                "old_time": old_time_str,
                "weekday": weekday_out,
                "instructor_ids": [str(instr.id) for instr in available_instructors],
                "instructors_str": [str(instr) for instr in available_instructors]
            }
            scheduled_this_block.append(lesson)
        
        unscheduled_lessons = [l for l in unscheduled_lessons if l not in scheduled_this_block]
    
    for lesson in unscheduled_lessons:
        old_date_str = lesson.date.strftime("%Y-%m-%d") if lesson.date else ""
        old_time_str = lesson.start_time.strftime("%H:%M") if lesson.start_time else ""
        lesson_str = f"{lesson.get_students_name()} lesson number {lesson.class_number}/{lesson.pack.number_of_classes}"
        scheduled_results[lesson.id] = {
            "lesson_id": str(lesson.id),
            "lesson_str": lesson_str,
            "new_date": "",
            "new_time": "",
            "old_date": old_date_str,
            "old_time": old_time_str,
            "weekday": "",
            "instructor_ids": [],
            "instructors_str": []
        }
    
    final_results = []
    for lesson in lessons:
        final_results.append(scheduled_results.get(lesson.id))
    
    return Response(final_results, status=200)