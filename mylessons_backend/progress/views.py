from django.http import JsonResponse
from django.shortcuts import get_object_or_404
from django.utils.dateparse import parse_date
from django.utils.timezone import now
from rest_framework.decorators import api_view
from rest_framework import status

from .models import Skill, Goal, ProgressRecord, ProgressReport
from users.models import Student


@api_view(['GET'])
def get_active_goals(request, student_id):
    """
    Returns a list of skills for a given subject.
    The URL should pass the subject_id as part of the route.
    """
    if student_id is None:
        return JsonResponse({'error': 'student_id not provided'}, status=status.HTTP_400_BAD_REQUEST)
    # Example: filtering by a foreign key relation 'sport' (subject)
    goals = Goal.objects.filter(student__id=student_id, is_completed=False)
    data = []
    for goal in goals:
        data.append({
            'id': goal.id,
            'skill_name': goal.skill.name,
            'skill_id': goal.skill.id,
            'subject': str(goal.skill.sport) if goal.skill.sport else None,
            'level': goal.level,
            'start_datetime': str(goal.start_datetime),
            'last_updated': (goal.last_updated) if goal.last_updated else None,
        })
    return JsonResponse(data, safe=False, status=status.HTTP_200_OK)

@api_view(['GET'])
def get_skills_for_subject(request, subject_id):
    """
    Returns a list of skills for a given subject.
    The URL should pass the subject_id as part of the route.
    """
    # Example: filtering by a foreign key relation 'sport' (subject)
    skills = Skill.objects.filter(sport__id=subject_id)
    data = []
    for skill in skills:
        data.append({
            'id': skill.id,
            'name': skill.name,
            'description': skill.description,
            'sport': str(skill.sport) if skill.sport else None,
        })
    return JsonResponse(data, safe=False, status=status.HTTP_200_OK)


@api_view(['POST'])
def update_goal_level(request, goal_id):
    """
    Updates the level of a goal.
    Expects a JSON body with a 'level' field.
    """
    level = request.data.get('level')
    if level is None:
        return JsonResponse({'error': 'Level not provided'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        level = int(level)
        if not (1 <= level <= 5):
            return JsonResponse({'error': 'Level must be between 1 and 5'}, status=status.HTTP_400_BAD_REQUEST)
    except ValueError:
        return JsonResponse({'error': 'Invalid level provided'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Ensure the proficiency belongs to the student.
    goal = get_object_or_404(Goal, pk=goal_id)
    goal.level = level
    goal.last_updated = now()
    goal.save()
    
    data = {
        'id': goal.id,
        'skill': goal.skill.name,
        'level': goal.level,
        'last_updated': goal.last_updated.isoformat(),
    }
    return JsonResponse(data, status=status.HTTP_200_OK)


@api_view(['POST'])
def create_skill(request):
    """
    Creates a new skill.
    Expects a JSON body with 'name', 'description' (optional), and 'sport_id' (optional).
    """
    name = request.data.get('name')
    if not name:
        return JsonResponse({'error': 'Name is required'}, status=status.HTTP_400_BAD_REQUEST)
    
    description = request.data.get('description', '')
    sport_id = request.data.get('sport_id')
    
    skill = Skill(name=name, description=description)
    if sport_id:
        from sports.models import Sport
        skill.sport = get_object_or_404(Sport, pk=sport_id)
    try:
        skill.save()
    except Exception as e:
        return JsonResponse({'error': f'Failed to create skill: {e}'}, status=status.HTTP_400_BAD_REQUEST)
    
    data = {
        'id': skill.id,
        'name': skill.name,
        'description': skill.description,
        'sport': str(skill.sport) if skill.sport else None,
    }
    return JsonResponse(data, status=status.HTTP_201_CREATED)


@api_view(['POST'])
def create_goal(request):
    """
    Creates a new goal.
    Expects a JSON body with 'student_id', 'skill_id', 'description', and 'target_date' (YYYY-MM-DD).
    """
    student_id = request.data.get('student_id')
    skill_id = request.data.get('skill_id')
    
    
    if not (student_id and skill_id):
        return JsonResponse({'error': 'student_id, skill_id, and target_date are required'},
                            status=status.HTTP_400_BAD_REQUEST)
    
    student = get_object_or_404(Student, pk=student_id)
    skill = get_object_or_404(Skill, pk=skill_id)
    
    if not (student and skill):
        return JsonResponse({'error': 'student or skill not found'},
                            status=status.HTTP_400_BAD_REQUEST)
   
    goal = Goal(student=student, skill=skill)
    try:
        goal.save()
    except Exception as e:
        return JsonResponse({'error': f'Failed to create goal: {e}'}, status=status.HTTP_400_BAD_REQUEST)
    
    data = {
        'id': goal.id,
        'student': goal.student.id,
        'skill': goal.skill.name,
        'is_completed': goal.is_completed,
        'level': goal.level,
    }
    return JsonResponse(data, status=status.HTTP_201_CREATED)


@api_view(['POST'])
def create_progress_record(request):
    """
    Creates a new progress record.
    Expects a JSON body with:
      - 'student_id' (required)
      - optionally 'lesson_id' and 'notes'
      - 'goals': a list of dictionaries with 'goal_id' and 'progress'
    For each goal provided, if the new progress (i.e. new level) differs from the current level,
    the goal’s update_level method is called, and the goal is linked to the progress record.
    """
    student_id = request.data.get('student_id')
    if not student_id:
        return JsonResponse({'error': 'student_id is required'}, status=status.HTTP_400_BAD_REQUEST)
    
    student = get_object_or_404(Student, pk=student_id)
    lesson_id = request.data.get('lesson_id')
    notes = request.data.get('notes', '')
    
    # Create the progress record.
    progress_record = ProgressRecord(student=student, notes=notes)
    if lesson_id:
        from lessons.models import Lesson
        progress_record.lesson = get_object_or_404(Lesson, pk=lesson_id)
    
    try:
        progress_record.save()
    except Exception as e:
        return JsonResponse({'error': f'Failed to create progress record: {e}'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Process and update goals if provided.
    goals_data = request.data.get('goals')
    if goals_data:
        from progress.models import Goal  # Import the Goal model.
        goal_ids = []
        for goal_data in goals_data:
            goal_id = goal_data.get('goal_id')
            new_level = goal_data.get('progress')
            if goal_id is None or new_level is None:
                continue
            try:
                goal_instance = Goal.objects.get(pk=goal_id)
                # Update the goal level if needed using the model's method.
                if goal_instance.level != new_level:
                    goal_instance.update_level(int(new_level))
                goal_ids.append(goal_instance.id)
            except Goal.DoesNotExist:
                continue
        # Associate the goals with the progress record.
        progress_record.goals.set(goal_ids)
    
    data = {
        'id': progress_record.id,
        'student': progress_record.student.id,
        'lesson': progress_record.lesson.id if progress_record.lesson else None,
        'date': progress_record.date.isoformat(),
        'notes': progress_record.notes,
    }
    return JsonResponse(data, status=status.HTTP_201_CREATED)



@api_view(['PUT'])
def update_progress_record(request, record_id):
    """
    Updates an existing progress record.
    Expects a JSON body with:
      - 'student_id' (required)
      - optionally 'lesson_id' and 'notes'
      - 'goals': a list of dictionaries with 'goal_id' and 'progress'
    For each goal provided, if the new progress (i.e. new level) differs from the current level,
    the view checks:
      - If the level was not 5 and now is 5, mark as completed.
      - If the level was 5 and now is not, mark as uncompleted.
    Then, the goal is linked to the progress record.
    """
    progress_record = get_object_or_404(ProgressRecord, pk=record_id)
    
    # Update notes and optionally lesson.
    notes = request.data.get('notes')
    if notes is not None:
        progress_record.notes = notes
    lesson_id = request.data.get('lesson_id')
    if lesson_id:
        from lessons.models import Lesson
        progress_record.lesson = get_object_or_404(Lesson, pk=lesson_id)
    
    try:
        progress_record.save()
    except Exception as e:
        return JsonResponse({'error': f'Failed to update progress record: {e}'},
                            status=status.HTTP_400_BAD_REQUEST)
    
    # Process and update goals if provided.
    goals_data = request.data.get('goals')
    if goals_data:
        from progress.models import Goal  # Import the Goal model.
        goal_ids = []
        for goal_data in goals_data:
            goal_id = goal_data.get('goal_id')
            new_level = goal_data.get('progress')
            if goal_id is None or new_level is None:
                continue
            try:
                goal_instance = Goal.objects.get(pk=goal_id)
                new_level_int = int(new_level)
                old_level = goal_instance.level
                if old_level != new_level_int:
                    goal_instance.level = new_level_int
                    goal_instance.last_updated = now()
                    if old_level != 5 and new_level_int == 5:
                        goal_instance.mark_completed()
                    elif old_level == 5 and new_level_int != 5:
                        goal_instance.mark_uncompleted()
                    else:
                        goal_instance.save()
                goal_ids.append(goal_instance.id)
            except Goal.DoesNotExist:
                continue
        progress_record.goals.set(goal_ids)
    
    data = {
        'id': progress_record.id,
        'student': progress_record.student.id,
        'lesson': progress_record.lesson.id if progress_record.lesson else None,
        'date': progress_record.date.isoformat(),
        'notes': progress_record.notes,
    }
    return JsonResponse(data, status=status.HTTP_200_OK)


@api_view(['GET'])
def get_progress_record(request):
    """
    Returns the progress record for a given student and lesson, if it exists.
    Expects query parameters: student_id and lesson_id.
    The response includes a list of goals linked to the record.
    """
    student_id = request.query_params.get('student_id')
    lesson_id = request.query_params.get('lesson_id')
    if not student_id or not lesson_id:
        return JsonResponse({'error': 'student_id and lesson_id are required'}, 
                            status=status.HTTP_400_BAD_REQUEST)
    try:
        progress_record = ProgressRecord.objects.get(student__id=student_id, lesson__id=lesson_id)
        data = {
            'id': progress_record.id,
            'student': progress_record.student.id,
            'lesson': progress_record.lesson.id if progress_record.lesson else None,
            'date': progress_record.date.isoformat(),
            'notes': progress_record.notes,
            'goals': [
                {
                    'id': goal.id,
                    'skill_name': goal.skill.name,
                    'level': goal.level,
                    'is_completed': goal.is_completed,
                }
                for goal in progress_record.goals.all()
            ]
        }
        return JsonResponse(data, status=status.HTTP_200_OK)
    except ProgressRecord.DoesNotExist:
        return JsonResponse({'error': 'Progress record not found'}, status=status.HTTP_404_NOT_FOUND)
