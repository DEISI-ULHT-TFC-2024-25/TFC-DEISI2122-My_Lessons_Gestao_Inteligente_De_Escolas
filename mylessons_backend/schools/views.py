import json
from django.shortcuts import render
from payments.models import Payment
from users.models import Instructor
from .models import School
from datetime import datetime, timedelta
from django.contrib.auth import authenticate, get_user_model
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status
from django.views.decorators.csrf import csrf_exempt
from rest_framework.permissions import AllowAny, IsAuthenticated
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import logging
from django.contrib.auth.hashers import make_password
from notifications.models import Notification
from lessons.models import Lesson, Pack
from events.models import Activity
from schools.models import School
from django.db.models import Q, Sum
from django.utils.timezone import now
from django.http import JsonResponse


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def school_details_view(request):
    
    # TODO TEST
    user = request.user
    school = School.objects.get(pk = user.current_school_id)
    if not school:
        return Response({
            'success': True,
            'school_id': None,
            'school_name': "",
            'pack_prices': {},
            'currency': ""
        })
    return Response({
        'success': True,
        'school_id': school.id,
        'school_name': school.name,
        'pack_prices': school.pack_prices,
        'currency': school.currency,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_pack_price_view(request):
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'success': False, 'error': 'Invalid JSON'}, status=400)
    
    # Retrieve the school by ID or create one if a school_name is provided.
    school_id = data.get('school_id')
    school_name = data.get('school_name')
    user = request.user
    
    if school_id:
        try:
            school = School.objects.get(id=school_id)
        except School.DoesNotExist:
            return JsonResponse({'success': False, 'error': 'School not found'}, status=404)
    elif school_name:
        # Create a new school with the given name and add request.user to admins.
        school = School.objects.create(name=school_name)
        school.admins.add(user)
        user.current_school_id = school.id
        user.save()
        
    else:
        return JsonResponse({'success': False, 'error': 'Either school_id or school_name must be provided'}, status=400)
    
    # Extract pack price details from the request data.
    pack_type = data.get('pack_type')
    duration = data.get('duration')
    number_of_people = data.get('number_of_people')
    number_of_classes = data.get('number_of_classes')
    price = data.get('price')
    expiration_date = data.get('expiration_date')  # computed on the client based on time limit
    currency = data.get('currency')
    
    # Set the school's currency if provided.
    if currency:
        school.currency = currency
        school.save()

    try:
        school.update_pack_price(
            pack_type=pack_type,
            duration=duration,
            number_of_people=number_of_people,
            number_of_classes=number_of_classes,
            price=price,
            expiration_date=expiration_date
        )
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=400)
    
    return JsonResponse({
        'success': True,
        'school_id': school.id,
        'school_name': school.name,
        'pack_prices': school.pack_prices
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def number_of_students_in_timeframe(request, school_id, start_date, end_date):

    # TODO 
    # 
    # account for students with lessons that dont have lessons scheduled
    #
    # maybe output the students ids
    #
    # TEST

    try:
        # Convert date strings to date objects
        start_date = datetime.strptime(start_date, "%Y-%m-%d").date()
        end_date = datetime.strptime(end_date, "%Y-%m-%d").date()
    except ValueError:
        return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=400)

    user = request.user
    current_role = getattr(user, 'current_role', None)

    # Check if user has permission to view this school’s student count
    if current_role != "Admin" or school_id not in user.school_admins.values_list('id', flat=True):
        return Response({"error": "Not allowed to view this school's students data"}, status=403)

    lesson_students = Lesson.objects.filter(
        school_id=school_id
    ).filter(
        Q(date__gte=start_date, date__lte=end_date) |
        Q(date__isnull=True, pack__date__lte=end_date, pack__expiration_date__gte=start_date) |
        Q(date__isnull=True, pack__expiration_date__isnull=True, pack__date__lte=end_date)
    ).values_list('students', flat=True).distinct().count()

    activity_students = Activity.objects.filter(
        school_id=school_id,
        date__gte=start_date,
        date__lte=end_date
    ).values_list('students', flat=True).distinct().count()

    total_students = lesson_students + activity_students

    data = {"total_students": str(total_students)}
    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def number_of_instructors_in_timeframe(request, school_id, start_date, end_date):

    # TODO TEST

    try:
        # Convert date strings to date objects
        start_date = datetime.strptime(start_date, "%Y-%m-%d").date()
        end_date = datetime.strptime(end_date, "%Y-%m-%d").date()
    except ValueError:
        return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=400)

    user = request.user
    current_role = getattr(user, 'current_role', None)

    # Check if user has permission to view this school’s student count
    if current_role != "Admin" or school_id not in user.school_admins.values_list('id', flat=True):
        return Response({"error": "Not allowed to view this school's instructors data"}, status=403)

    # Count distinct students from lessons and activities in the given timeframe
    lesson_instructors = Lesson.objects.filter(
        school_id=school_id,
        date__gte=start_date,
        date__lte=end_date
    ).values_list('instructors', flat=True).distinct().count()

    activity_instructors = Activity.objects.filter(
        school_id=school_id,
        date__gte=start_date,
        date__lte=end_date
    ).values_list('instructors', flat=True).distinct().count()

    total_instructors = lesson_instructors + activity_instructors

    data = {"total_instructors": str(total_instructors)}
    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def school_revenue_in_timeframe(request, school_id, start_date, end_date):
    
    # TODO TEST

    try:
        # Convert date strings to date objects
        start_date = datetime.strptime(start_date, "%Y-%m-%d").date()
        end_date = datetime.strptime(end_date, "%Y-%m-%d").date()
    except ValueError:
        return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=400)

    user = request.user
    current_role = getattr(user, 'current_role', None)

    # Check if user has permission to view this school’s revenue
    if current_role != "Admin" or school_id not in user.school_admins.values_list('id', flat=True):
        return Response({"error": "Not allowed to view this school's revenue"}, status=403)

    # Calculate total revenue (sum of all payments linked to lessons in this school within the timeframe)
    total_revenue = Payment.objects.filter(
        school_id=school_id,
        date__gte=start_date,
        date__lte=end_date,
        instructor__isnull=True,  # Only payments where instructors are null
        monitor__isnull=True  # Only payments where monitors are null
    ).aggregate(total_income=Sum('value'))['total_income'] or 0  # Default to 0 if None

    data = {"total_revenue": str(total_revenue)}
    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def number_of_bookings_in_timeframe(request, school_id, start_date, end_date):
    try:
        # Convert date strings to datetime objects
        start_date = datetime.strptime(start_date, "%Y-%m-%d").date()
        end_date = datetime.strptime(end_date, "%Y-%m-%d").date()
    except ValueError:
        return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=400)

    user = request.user
    current_role = getattr(user, 'current_role', None)

    # Check if user has permission to view this school’s bookings count
    if current_role != "Admin" or school_id not in user.school_admins.values_list('id', flat=True):
        return Response({"error": "Not allowed to view this school's bookings"}, status=403)

    
    number_of_lessons = Lesson.objects.filter(
        school__id=school_id,
        date__gte=start_date,
        date__lte=end_date,
        start_time__isnull=False
    ).count()


    data = {"number_of_lessons_booked": str(number_of_lessons)}
    return Response(data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_instructor(request):
    """
    Permite aos administradores da escola adicionarem um instrutor
    """
    user = request.user
    current_role = user.current_role
    instructor_id = request.data.get("instructor_id")

    if not instructor_id :
        return Response({"error": "É necessário fornecer instructor_id"},
                        status=status.HTTP_400_BAD_REQUEST)
    
    if current_role == "Admin":
        instructor = Instructor.objects.get(id=instructor_id)
        school = School.objects.get(admins__in=[user])
        if school and instructor:
            success = school.add_instructor(instructor=instructor)
    else:
        return Response({"error": "Não tem permissão para adicionar o instrutor."},
                        status=status.HTTP_403_FORBIDDEN)
    if success:
        return Response({'message': 'Instrutor adicionado com sucesso!'}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "Impossivel adicionar o instrutor."}, status=status.HTTP_400_BAD_REQUEST)
    
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def remove_instructor(request):
    """
    Permite aos administradores da escola adicionarem um instrutor
    """
    user = request.user
    current_role = user.current_role
    instructor_id = request.data.get("lesson_id")

    if not instructor_id :
        return Response({"error": "É necessário fornecer instructor_id"},
                        status=status.HTTP_400_BAD_REQUEST)
    
    if current_role == "Admin":
        instructor = Instructor.objects.filter(id=instructor_id)
        school = School.objects.get(admins__in=[user])
        if school and instructor:
            success = school.remove_instructor(instructor=instructor)
    else:
        return Response({"error": "Não tem permissão para remover o instrutor."},
                        status=status.HTTP_403_FORBIDDEN)
    if success:
        return Response({'message': 'Instrutor removido com sucesso!'}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "Impossivel remover o instrutor."}, status=status.HTTP_400_BAD_REQUEST)
