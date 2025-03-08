import json
from django.shortcuts import render, get_object_or_404
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

logger = logging.getLogger(__name__)

@permission_classes([IsAuthenticated])
@api_view(['GET'])
def get_services(request, school_id):
    """
    GET /api/schools/<school_id>/services/
    Returns the list of services for the specified school.
    """
    school = get_object_or_404(School, pk=school_id)
    return Response(school.services, status=200)


@permission_classes([IsAuthenticated])
@api_view(['POST'])
def add_edit_service(request, school_id):
    """
    POST /api/schools/<school_id>/services/add_edit/
    
    Request Body (JSON):
    {
      "id": "optional-service-id",  // Omit or provide to update an existing service.
      "name": "Private Lessons",
      "photos": ["https://link1", "https://link2"],
      "benefits": ["One-on-one coaching", "Customized curriculum"],
      "description": "Intensive private lessons for faster skill development.",
      "sports": ["tennis", "soccer"],
      "locations": ["Court 1", "Room 101"],
      "type": {
        // Provide EITHER "pack" OR "activity", not both.
        "pack": "private"
        // OR
        // "activity": "birthday party"
      }
    }

    If a service with the given 'id' exists, it will be updated.
    Otherwise, a new service is appended.

    Returns the updated list of services.
    """

    # TODO checks for conflicts with missing payment types, for example a service for private lessons with pricing option for 60min 4 people and not payment types for all the roles for those details 

    school = get_object_or_404(School, pk=school_id)
    service_data = request.data  # JSON payload

    try:
        updated_services = school.add_or_edit_service(service_data)
    except ValueError as e:
        return Response({"detail": str(e)}, status=400)

    return Response(updated_services, status=200)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def all_schools(request):
    schools = School.objects.all()
    data = []
    for school in schools:
        data.append({
            'school_id': school.id,
            'school_name': school.name,
            'list_of_locations': [
                {'id': location.id, 'name': location.name}
                for location in school.locations.all()
            ],
            'list_of_activities': [
                {'id': sport.id, 'name': sport.name}
                for sport in school.sports.all()
            ],
            'services': school.services,
            'currency': school.currency if school.currency else "EUR"
        })
    return Response(data, status=status.HTTP_200_OK)

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
            'services': {},
            'payment_types': {},
            'currency': ""
        })
    return Response({
        'success': True,
        'school_id': school.id,
        'school_name': school.name,
        'services': school.services,
        'payment_types': school.payment_types,
        'currency': school.currency,
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_payment_type_view(request):
    """
    Update the default payment types for the school, not a specific user
    
    """

    # TODO check for conflicts within the payment types, example an instructor payment type for private lessons for 60 min 1 to 4 people and an other for private lessons 60 min 1 to 2 people, if so, asks to override or edit
    # TODO it has to go through the school services and checks if there are any conflicts example having a service and not having a payment type to cover for that service details
    
    try:
        data = json.loads(request.body)
        logger.debug("Received payload: %s", data)
    except json.JSONDecodeError as e:
        logger.error("JSON decode error: %s", str(e))
        return JsonResponse({'success': False, 'error': 'Invalid JSON'}, status=400)
    
    school_id = data.get('school_id')
    school_name = data.get('school_name')
    user = request.user
    logger.debug("User: %s", user)
    
    if school_id:
        try:
            school = School.objects.get(id=school_id)
            logger.debug("Found school by id: %s", school)
        except School.DoesNotExist:
            logger.error("School not found for id: %s", school_id)
            return JsonResponse({'success': False, 'error': 'School not found'}, status=404)
    elif school_name:
        school = School.objects.create(name=school_name)
        school.admins.add(user)
        user.current_school_id = school.id
        user.save()
        logger.debug("Created school with name: %s", school_name)
    else:
        logger.error("Neither school_id nor school_name provided.")
        return JsonResponse({'success': False, 'error': 'Either school_id or school_name must be provided'}, status=400)
    
    key_path = data.get('key_path')
    new_value = data.get('new_value')
    logger.debug("key_path: %s, new_value: %s", key_path, new_value)
    
    if not key_path or new_value is None:
        logger.error("Missing key_path or new_value. key_path=%s, new_value=%s", key_path, new_value)
        return JsonResponse({'success': False, 'error': 'key_path and new_value must be provided'}, status=400)
    
    try:
        result = school.update_payment_type_value(key_path, new_value, user_obj=None)
        logger.debug("update_payment_type_value result: %s", result)
    except Exception as e:
        logger.exception("Error during update_payment_type_value:")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)
    
    logger.debug("Updated payment_types: %s", school.payment_types)
    return JsonResponse({
        'success': True,
        'school_id': school.id,
        'school_name': school.name,
        'payment_types': school.payment_types
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


