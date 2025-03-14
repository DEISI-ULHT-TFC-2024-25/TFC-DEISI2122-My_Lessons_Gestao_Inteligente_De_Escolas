from datetime import datetime, timedelta, time
import json
from django.contrib.auth import authenticate, get_user_model
from events.models import Activity
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from rest_framework.authtoken.models import Token
from rest_framework import status
from django.views.decorators.csrf import csrf_exempt
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import logging
from django.contrib.auth.hashers import make_password
from .models import GoogleCredential, Student, Unavailability, UserAccount, Instructor
from .serializers import UserAccountSerializer, StudentSerializer
from notifications.models import Notification
from lessons.models import Lesson, Pack
from schools.models import School
from django.db.models import Q
from django.utils.timezone import now
from django.utils.dateparse import parse_date, parse_time
import firebase_admin
from firebase_admin import auth as firebase_auth, initialize_app, credentials as firebase_credentials
import os

logger = logging.getLogger(__name__)



User = get_user_model()

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    username = request.data.get('username')
    password = request.data.get('password')

    user = authenticate(username=username, password=password)

    if user is not None:
        # Get or create token for the user
        token, created = Token.objects.get_or_create(user=user)
        
        return Response({
            'message': 'Login successful',
            'token': token.key  # Return the token here
        }, status=status.HTTP_200_OK)
    else:
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def google_oauth_start(request):
    token = request.data.get('token')
    logger.info(f'entrou no google oauth start com o token: {token}')
    if not token:
        return Response({'error': 'Token não fornecido.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        idinfo = id_token.verify_oauth2_token(token, google_requests.Request(), '147437937321-v39oeirc3e8hjgjeiugp3eia6vlmjbg.apps.googleusercontent.com')

        if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
            raise ValueError('Emissor inválido.')

        email = idinfo.get('email')
        first_name = idinfo.get('given_name')
        last_name = idinfo.get('family_name')

        user, created = User.objects.get_or_create(email=email, defaults={
            'username': email,
            'first_name': first_name,
            'last_name': last_name
        })

        if created:
            user.set_unusable_password()
            user.save()

        return Response({'message': 'Login com Google bem-sucedido', 'user': {'email': email}}, status=status.HTTP_200_OK)

    except ValueError as e:
        logger.error(f'Erro ao validar o token do Google: {e}')
        return Response({'error': f'Token inválido: {str(e)}'}, status=status.HTTP_401_UNAUTHORIZED)

    except Exception as e:
        logger.error(f'Erro inesperado: {e}')
        return Response({'error': f'Erro inesperado: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    
@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def register_user(request):
    """
    Registers a new user and returns an authentication token.
    """
    data = request.data

    required_fields = ['email', 'password', 'first_name', 'last_name', 'country_code', 'phone']
    missing_fields = [field for field in required_fields if field not in data]

    if missing_fields:
        return Response(
            {'error': f'Missing fields: {", ".join(missing_fields)}'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        user = UserAccount.objects.create(
            username=data['email'],
            email=data['email'],
            first_name=data['first_name'],
            last_name=data['last_name'],
            country_code=data['country_code'],
            phone=data['phone'],
            password=make_password(data['password']),
        )

        # Create token for the new user.
        token, created = Token.objects.get_or_create(user=user)

        return Response(
            {'message': 'User registered successfully', 'token': token.key},
            status=status.HTTP_201_CREATED
        )

    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_profile(request):
    user = request.user  # Obtém o utilizador autenticado

    # Conta as notificações não lidas
    unread_notifications = Notification.objects.filter(user=user, type=user.current_role, date_read=None).count()

    data = {
        "id": user.id,
        "first_name": user.first_name,
        "notifications_count": str(unread_notifications)
    }

    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def current_role(request):
    user = request.user  # Obtém o utilizador autenticado

    data = {
        "current_role": user.current_role
    }

    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def available_schools(request):
    user = request.user
    current_role = user.current_role

    available_schools = []

    # Check and retrieve schools based on the user's role
    if current_role == "Admin":
        available_schools = [
            {"id": school.id, "name": school.name} for school in user.school_admins.all()
        ]
    elif current_role == "Parent":
        available_schools = [
            {"id": school.id, "name": school.name} for school in user.schools.all() # TODO maybe follow the exclude above
        ]
    elif current_role == "Instructor":
        if hasattr(user, "instructor_profile"):
            available_schools = [
                {"id": school.id, "name": school.name} for school in user.instructor_profile.schools.all()
            ]

    return Response({"available_schools": available_schools})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def current_school_id(request):
    user = request.user  # Obtém o utilizador autenticado
    current_school_id = user.current_school_id
    school = School.objects.get(id=current_school_id) if current_school_id else None
    current_school_name = school.name if school else None

    data = {
        "current_school_id": str(user.current_school_id),
        "current_school_name": current_school_name
    }

    return Response(data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_school_id(request):
    user = request.user
    new_school_id = request.data.get("new_school_id")
    school = School.objects.get(id=new_school_id) if new_school_id else None
    school_name = school.name if school else None
    
    if new_school_id and school and school_name:
        user.current_school_id = new_school_id
        user.save(update_fields=["current_school_id"])
        return Response({"message": f"School changed to {school_name}!"}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "School was not changed!"},
                        status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_role(request):
    user = request.user  # Obtém o utilizador autenticado
    new_role = request.data.get("new_role")

    # TODO change strings inplementation for more flexible roles across the whole app

    role_changed = False

    if new_role == "Parent":
        user.current_role = "Parent"
        user.save(update_fields=["current_role"])

    elif new_role == "Instructor":
        instructors = Instructor.objects.filter(user=user)
        if instructors:
            user.current_role = "Instructor"
            user.save(update_fields=["current_role"])

    elif new_role == "Admin":
        schools = School.objects.filter(admins__in=[user])
        if schools:
            user.current_role = "Admin"
            user.save(update_fields=["current_role"])

    # gets the new role and checks if it can be changed, if so then updates the role 

    if user.current_role == new_role:
        role_changed = True

    if role_changed:
        return Response({"message": f"Role changed to {new_role}!"}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "Role was not changed!"},
                        status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def number_of_active_students(request):

    # number of students with active packs or packs that finished in less than a month
    # for admins, students are in packs registered to the admins school
    # for instructors, students that were in lessons given by the instructor in less than a month

    # TODO  make a month ago aware

    user = request.user
    current_role = user.current_role
    a_month_ago = (datetime.now() - timedelta(weeks=4)).date()

    students = []


    if current_role == "Instructor":
        lessons = Lesson.objects.filter(
            instructors__in=[user.instructor_profile]
        ).filter(
            Q(date__gte=a_month_ago) |
            Q(date=None)
        )
        for l in lessons:
            for student in l.students.all():
                students.append(student)

    elif current_role == "Admin":
        lessons = Lesson.objects.filter(
            Q(date__gte=a_month_ago) |
            Q(date=None)
        )
        for l in lessons:
            for student in l.students.all():
                students.append(student)

    data = {
        "number_of_active_students" : len(set(students))
    }

    return Response(data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def current_balance(request):
    user = request.user

    data = {
        "current_balance": user.balance
    }
    
    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def available_roles(request):
    user = request.user
    current_role = user.current_role

    available_roles = []
    
    if hasattr(user, 'instructor_profile') and current_role != "Instructor":
        available_roles.append("Instructor")
    
    if current_role != "Parent":
        available_roles.append("Parent")
    
    if user.school_admins.exists() and current_role != "Admin":
        available_roles.append("Admin")
    
    data = {
        "available_roles": available_roles
    }
    
    return Response(data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_student(request):

    print("Incoming data:", request.data)

    user = request.user
    current_role = user.current_role

    # Expecting only first_name, last_name, and birthday in the request data.
    first_name = request.data.get('first_name')
    last_name = request.data.get('last_name')
    birthday_str = request.data.get('birthday')

    if not all([first_name, last_name, birthday_str]):
        return Response({'error': 'Missing required fields.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        # Convert the birthday string (expected in 'YYYY-MM-DD') to a date object.
        birthday_date = datetime.strptime(birthday_str, '%Y-%m-%d').date()
    except ValueError:
        return Response({'error': 'Birthday must be in YYYY-MM-DD format.'}, status=status.HTTP_400_BAD_REQUEST)


    try:
        # Create the student.
        student = Student.objects.create(
            first_name=first_name,
            last_name=last_name,
            birthday=birthday_date,
            level=1
        )
        if current_role == "Parent":
            # Add the current user as a parent.
            student.parents.add(request.user)
        # Prepare a response with the created student's details.
        response_data = {
            "id": student.id,
            "first_name": student.first_name,
            "last_name": student.last_name,
            "birthday": birthday_str
        }
        return Response(response_data, status=status.HTTP_201_CREATED)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def students(request):
    user = request.user

    # Assuming user.students.all() returns the associated students.
    associated_students = user.students.all()  
    all_students = Student.objects.all()

    data = {
        "associated_students": StudentSerializer(associated_students, many=True).data,
        "all_students": StudentSerializer(all_students, many=True).data,
    }

    return Response(data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def get_selected_students(request):
    lesson_id = request.data.get("lesson_id")
    pack_id = request.data.get("pack_id")

    if lesson_id:
        lesson = get_object_or_404(Lesson, id=lesson_id)
        associated_students = lesson.students.all()
        all_students = lesson.school.students.all()
    elif pack_id:
        pack = get_object_or_404(Pack, id=pack_id)
        associated_students = pack.students.all()
        all_students = pack.school.students.all()
    else:
        associated_students = Student.objects.none()
        all_students = Student.objects.all()

    

    data = {
        "associated_students": StudentSerializer(associated_students, many=True).data,
        "all_students": StudentSerializer(all_students, many=True).data,
    }
    return Response(data)




@api_view(['POST'])
@permission_classes([IsAuthenticated])
def book_pack_view(request):
    """
    Expects a JSON payload with a key "packs" that is a list of booking requests.
    Each booking request should include:
      - students (list of dicts with at least an "id" key)
      - school (School id or a valid identifier; if 'default_school_id' or 'Test School' is provided, use a fallback)
      - expiration_date (in YYYY-MM-DD format)
      - number_of_classes
      - duration_in_minutes
      - instructors
      - price
      - payment (if "cash", will be converted to 0)
      - discount_id (optional)
      - type (e.g. either a string like "private" or a dict with a key "pack")
    """
    data = request.data
    logger.debug("Received payload: %s", data)
    today = now().date()
    
    packs_data = data.get('packs', None)
    if packs_data is None or not isinstance(packs_data, list):
        error_msg = "Invalid payload. Expected a 'packs' list."
        logger.error(error_msg)
        return Response({"error": error_msg},
                        status=status.HTTP_400_BAD_REQUEST)

    booked_packs = []
    errors = []

    for pack_req in packs_data:
        logger.debug("Processing pack request: %s", pack_req)
        try:
            # Convert student dicts to Student model instances.
            raw_students = pack_req.get('students', [])
            students = []
            for student_data in raw_students:
                if isinstance(student_data, dict):
                    student_obj = get_object_or_404(Student, id=student_data.get('id'))
                    students.append(student_obj)
                else:
                    students.append(student_data)
            
            # Convert school id (or identifier) to a School instance.
            school_identifier = pack_req.get('school')
            if school_identifier in ['default_school_id', 'Test School']:
                # Fallback: use the first available School instance.
                school_obj = School.objects.first()
                if not school_obj:
                    raise ValueError("No School available for fallback.")
            else:
                # Assume school_identifier is a numeric ID.
                school_obj = get_object_or_404(School, id=school_identifier)
            
            # Convert the expiration_date if needed.
            # (Assuming it's already in YYYY-MM-DD format from the payload.)
            expiration_date = pack_req.get('expiration_date')
            if not expiration_date:
                expiration_date = now().date().strftime("%Y-%m-%d")
            
            # Convert payment: if payment is "cash", use 0.
            payment_value = pack_req.get('payment')
            if isinstance(payment_value, str) and payment_value.lower() == 'cash':
                payment_value = 0

            # Ensure the booking type is a string.
            final_type = "private"  # default value
            raw_type = pack_req.get('type')
            if isinstance(raw_type, dict) and raw_type.get('pack'):
                final_type = raw_type.get('pack')
            elif isinstance(raw_type, str):
                final_type = raw_type

            raw_expiration_date = pack_req.get('expiration_date')
            if raw_expiration_date:
                expiration_date = datetime.strptime(raw_expiration_date, "%Y-%m-%d").date()

            new_pack = Pack.book_new_pack(
                students=students,
                school=school_obj,
                date=expiration_date,  # using expiration_date if that is what you want as the booking date
                number_of_classes=pack_req.get('number_of_classes'),
                duration_in_minutes=pack_req.get('duration_in_minutes'),
                instructors=pack_req.get('instructors'),
                price=pack_req.get('price'),
                payment=payment_value,
                discount_id=pack_req.get('discount_id'),
                type=final_type,
                expiration_date=expiration_date if expiration_date else None
            )
            booked_packs.append(
                {
                    "pack_id": new_pack.id,
                    "lessons": [
                                    {
                                        "lesson_id" : lesson.id,
                                        "lesson_str": str(lesson),
                                        "expiration_date": lesson.pack.expiration_date if lesson.pack and lesson.pack.expiration_date else "None",
                                    }
                                    for lesson in new_pack.lessons.all()
                                ],
                    "lessons_remaining": str(new_pack.number_of_classes_left),
                    "unscheduled_lessons": str(new_pack.get_number_of_unscheduled_lessons()),
                    "days_until_expiration": str((new_pack.expiration_date - today).days) if new_pack.expiration_date else None,
                    "students_name": new_pack.get_students_name(),
                    "type": new_pack.type
                }
            )
            logger.debug("Successfully booked pack with ID: %s", new_pack.id)
        except Exception as e:
            error_str = f"Error processing pack request {pack_req}: {str(e)}"
            errors.append(error_str)
            logger.exception(error_str)

    if errors:
        logger.error("Booking errors: %s", errors)
        return Response({"errors": errors}, status=status.HTTP_400_BAD_REQUEST)
    
    logger.debug("Booked packs successfully: %s", booked_packs)
    return Response({"booked_packs": booked_packs}, status=status.HTTP_201_CREATED)


# Initialize Firebase Admin using the service account key from an environment variable
if not firebase_admin._apps:
    service_account_path = os.environ.get('FIREBASE_SERVICE_ACCOUNT_KEY')
    if service_account_path is None:
        raise Exception("FIREBASE_SERVICE_ACCOUNT_KEY environment variable is not set.")
    cred = firebase_credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred)


@api_view(['POST'])
def store_google_credentials(request):
    id_token_value = request.data.get('idToken')
    access_token = request.data.get('accessToken')

    if not id_token_value or not access_token:
        return Response({'error': 'Missing tokens'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Verify the ID token using Firebase Admin SDK
    try:
        decoded_token = firebase_auth.verify_id_token(id_token_value)
    except Exception as e:
        return Response({'error': 'Invalid token', 'details': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    
    # Extract user details from the decoded token
    email = decoded_token.get('email')
    if not email:
        return Response({'error': 'Email not found in token'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Optionally extract additional info (e.g., display name)
    display_name = decoded_token.get('name', email.split('@')[0])
    
    # Create or retrieve the user
    user, created = UserAccount.objects.get_or_create(
        email=email,
        defaults={'username': email.split('@')[0], 'first_name': display_name}
    )
    
    # Serialize the tokens as a JSON string (or any format you prefer)
    serialized_credentials = json.dumps({
        'idToken': id_token_value,
        'accessToken': access_token,
    })
    
    # Create or update the GoogleCredential for the user
    google_credential, created_gc = GoogleCredential.objects.update_or_create(
        user=user,
        defaults={'credentials': serialized_credentials},
    )
    
    return Response(
        {
            'message': 'Credentials stored successfully.',
            'user_created': created,
            'google_credential_created': created_gc,
        },
        status=status.HTTP_200_OK
    )
    
    
    
# Helper to map weekday names to Python's date.weekday() indices
DAY_NAME_TO_INDEX = {
    "Monday": 0,
    "Tuesday": 1,
    "Wednesday": 2,
    "Thursday": 3,
    "Friday": 4,
    "Saturday": 5,
    "Sunday": 6,
}



def unify_intervals(time_ranges):
    """
    Given a list of (start_time, end_time) tuples (Python time objects),
    returns a list of merged, non-overlapping intervals.
    """
    if not time_ranges:
        return []
    # Sort intervals by start time (converted to minutes since midnight)
    sorted_ranges = sorted(time_ranges, key=lambda r: (r[0].hour * 60 + r[0].minute))
    merged = []
    current_start, current_end = sorted_ranges[0]
    for s, e in sorted_ranges[1:]:
        if (s.hour * 60 + s.minute) <= (current_end.hour * 60 + current_end.minute):
            if (e.hour * 60 + e.minute) > (current_end.hour * 60 + current_end.minute):
                current_end = e
        else:
            merged.append((current_start, current_end))
            current_start, current_end = s, e
    merged.append((current_start, current_end))
    return merged

@api_view(['POST'])
def update_availability(request):
    """
    Handles both "save as available" (remove unavailability)
    and "save as unavailability" (add unavailability),
    according to the frontend payload structure.
    
    For each interval processed, a summary message is recorded.
    If end_time is smaller than start_time, it is set to 23:59.
    The final response includes a "summary" of the changes.
    """
    logger.info("update_availability called with payload: %s", request.data)
    
    mode = request.data.get("mode")  # e.g. "single_day_list"
    action = request.data.get("action")  # "add_unavailability" or "remove_unavailability"
    current_role = request.data.get("role")
    logger.info("Mode: %s, Action: %s, Role: %s", mode, action, current_role)
    
    instructor = None
    if current_role == "Instructor":
        instructor = request.user.instructor_profile
        
    student_id = request.data.get("student_id")
    school_id = request.data.get("school_id")
    
    student = None
    if student_id:
        student = Student.objects.get(pk=student_id)
    school = None
    if school_id:
        school = School.objects.get(pk=school_id)
        
    is_add_unavailability = (action == "add_unavailability")
    logger.info("is_add_unavailability: %s", is_add_unavailability)
    
    summary_list = []  # Collect summary messages
    
    try:
        if mode == "single_day_list":
            items = request.data.get("items", [])
            logger.info("Processing single_day_list with %d items", len(items))
            for day_item in items:
                date_str = day_item["date"]
                date_obj = parse_date(date_str)
                logger.debug("Processing date: %s", date_str)
                for t in day_item["times"]:
                    start_str = t["start_time"]
                    end_str = t["end_time"]
                    start_time = parse_time(start_str)
                    end_time = parse_time(end_str)
                    if end_time < start_time:
                        end_time = time(23, 59)
                    logger.debug("Time range: %s - %s", start_str, end_str)
                    if is_add_unavailability:
                        logger.info("Creating unavailability for %s", date_str)
                        Unavailability.define_unavailability(
                            instructor=instructor,
                            student=student,
                            date=date_obj,
                            start_time=start_time,
                            end_time=end_time,
                            school=school
                        )
                        summary_list.append(f"Created unavailability on {date_str} from {start_str} to {end_str}.")
                    else:
                        logger.info("Removing unavailability for %s", date_str)
                        Unavailability.define_availability(
                            instructor=instructor,
                            student=student,
                            date=date_obj,
                            start_time=start_time,
                            end_time=end_time,
                            school=school
                        )
                        summary_list.append(f"Made available on {date_str} from {start_str} to {end_str}.")
                        
        elif mode == "date_interval_day_times":
            from_str = request.data["from_date"]
            to_str   = request.data["to_date"]
            days_map = request.data.get("days", {})
            from_date = parse_date(from_str)
            to_date   = parse_date(to_str)
            logger.info("Processing date_interval_day_times from %s to %s", from_str, to_str)
            current = from_date
            while current <= to_date:
                weekday_idx = current.weekday()  # Monday=0, Sunday=6
                for day_name, time_list in days_map.items():
                    if DAY_NAME_TO_INDEX.get(day_name) == weekday_idx:
                        logger.debug("Processing %s on %s", day_name, current)
                        for t in time_list:
                            start_str = t["start_time"]
                            end_str   = t["end_time"]
                            start_time = parse_time(start_str)
                            end_time   = parse_time(end_str)
                            if end_time < start_time:
                                end_time = time(23, 59)
                            if is_add_unavailability:
                                logger.info("Creating unavailability for %s", current)
                                Unavailability.define_unavailability(
                                    instructor=instructor,
                                    student=student,
                                    date=current,
                                    start_time=start_time,
                                    end_time=end_time,
                                    school=school
                                )
                                summary_list.append(f"Created unavailability on {current} from {start_str} to {end_str}.")
                            else:
                                logger.info("Removing unavailability for %s", current)
                                Unavailability.define_availability(
                                    instructor=instructor,
                                    student=student,
                                    date=current,
                                    start_time=start_time,
                                    end_time=end_time,
                                    school=school
                                )
                                summary_list.append(f"Made available on {current} from {start_str} to {end_str}.")
                current += timedelta(days=1)
                
        elif mode == "date_interval_time_ranges":
            from_str = request.data["from_date"]
            to_str   = request.data["to_date"]
            ranges   = request.data.get("ranges", [])
            from_date = parse_date(from_str)
            to_date   = parse_date(to_str)
            logger.info("Processing date_interval_time_ranges from %s to %s", from_str, to_str)
            current = from_date
            while current <= to_date:
                weekday_idx = current.weekday()  # Monday=0, Tuesday=1, etc.
                for rng in ranges:
                    for day_name in rng["days"]:
                        if DAY_NAME_TO_INDEX.get(day_name) == weekday_idx:
                            start_time = parse_time(rng["start_time"])
                            end_time   = parse_time(rng["end_time"])
                            if end_time < start_time:
                                end_time = time(23, 59)
                            if is_add_unavailability:
                                logger.info("Creating unavailability for %s", current)
                                Unavailability.define_unavailability(
                                    instructor=instructor,
                                    student=student,
                                    date=current,
                                    start_time=start_time,
                                    end_time=end_time,
                                    school=school
                                )
                                summary_list.append(f"Created unavailability on {current} from {rng['start_time']} to {rng['end_time']}.")
                            else:
                                logger.info("Removing unavailability for %s", current)
                                Unavailability.define_availability(
                                    instructor=instructor,
                                    student=student,
                                    date=current,
                                    start_time=start_time,
                                    end_time=end_time,
                                    school=school
                                )
                                summary_list.append(f"Made available on {current} from {rng['start_time']} to {rng['end_time']}.")
                current += timedelta(days=1)
        else:
            logger.error("Unknown mode: %s", mode)
            return Response({"detail": f"Unknown mode: {mode}"}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.exception("Exception during update_availability:")
        return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    logger.info("update_availability completed successfully")
    summary_text = "\n".join(summary_list)
    return Response({"status": "success", "summary": summary_text}, status=status.HTTP_200_OK)

def split_overlaps(intervals):
    """
    Given a list of intervals as (start, end, type, title) sorted by start time,
    returns a new list where overlapping intervals of different types are split so
    that both appear in the final timeline.
    
    For example, if we have:
      - Unavailability: 09:00–12:00
      - Lesson: 10:00–11:00
    This function will produce:
      - 09:00–10:00 (unavailability)
      - 10:00–11:00 (lesson)
      - 11:00–12:00 (unavailability)
    """
    final_intervals = []
    for (start, end, block_type, title) in intervals:
        if not final_intervals:
            final_intervals.append((start, end, block_type, title))
            continue

        last_start, last_end, last_type, last_title = final_intervals[-1]

        # If there is no overlap or they are the same type, simply append.
        if start >= last_end or block_type == last_type:
            final_intervals.append((start, end, block_type, title))
        else:
            # There is an overlap and the types differ.
            # First, if there is a gap at the beginning of the last interval, adjust it.
            if last_start < start:
                # Modify the last interval to end at the new block's start.
                final_intervals[-1] = (last_start, start, last_type, last_title)
            else:
                # If last_start is not less than start, remove it.
                final_intervals.pop()
            # Insert the new block fully.
            final_intervals.append((start, end, block_type, title))
            # If the last interval extended past the new block, add the remaining part.
            if last_end > end:
                final_intervals.append((end, last_end, last_type, last_title))
    # Re-sort the intervals by start time.
    final_intervals.sort(key=lambda x: (x[0].hour * 60 + x[0].minute))
    return final_intervals

@api_view(['GET'])
def daily_timeline(request):
    """
    Returns a merged timeline for a single day combining unavailabilities, lessons, and activities.
    Query parameter: ?date=YYYY-MM-DD

    The timeline is returned as a list of blocks, each with:
      - type: "unavailability", "lesson", "activity", or "available"
      - title: for lessons/activities (or null)
      - start_time: "HH:MM" (string)
      - end_time: "HH:MM" (string)
    """
    date_str = request.GET.get("date")
    if not date_str:
        return Response({"error": "Missing 'date' parameter (YYYY-MM-DD)."}, status=status.HTTP_400_BAD_REQUEST)
    date_obj = parse_date(date_str)
    if not date_obj:
        return Response({"error": "Invalid date format."}, status=status.HTTP_400_BAD_REQUEST)

    # Use the logged-in instructor's profile
    try:
        instructor = request.user.instructor_profile
    except Exception as e:
        logger.exception("Unable to get instructor profile.")
        return Response({"error": "Instructor profile not found."}, status=status.HTTP_400_BAD_REQUEST)

    # 1. Fetch unavailabilities for the day and merge overlapping intervals.
    unavails = Unavailability.objects.filter(instructor=instructor, date=date_obj).order_by("start_time")
    unavail_intervals = []
    for u in unavails:
        start_t = u.start_time
        if u.end_time:
            end_t = u.end_time
        else:
            end_dt = datetime.combine(date_obj, start_t) + timedelta(minutes=u.duration_in_minutes)
            end_t = end_dt.time()
        unavail_intervals.append((start_t, end_t))
    merged_unavails = unify_intervals(unavail_intervals)

    # 2. Fetch lessons for the day where instructor is assigned.
    lessons = Lesson.objects.filter(date=date_obj, instructors=instructor).order_by("start_time")
    lesson_intervals = []
    for lesson in lessons:
        s = lesson.start_time
        if lesson.end_time:
            e = lesson.end_time
        else:
            e = (datetime.combine(date_obj, s) + timedelta(minutes=lesson.duration_in_minutes)).time()
        lesson_intervals.append((s, e, "lesson", "Lesson"))
    
    # 3. Fetch activities for the day where instructor is assigned.
    activities = Activity.objects.filter(date=date_obj, instructors=instructor).order_by("start_time")
    activity_intervals = []
    for act in activities:
        s = act.start_time
        if act.end_time:
            e = act.end_time
        else:
            e = (datetime.combine(date_obj, s) + timedelta(minutes=act.duration_in_minutes)).time()
        activity_intervals.append((s, e, "activity", act.name))

    # 4. Build a list of all intervals.
    intervals = []
    for (s, e) in merged_unavails:
        intervals.append((s, e, "unavailability", None))
    intervals.extend(lesson_intervals)
    intervals.extend(activity_intervals)
    intervals.sort(key=lambda x: (x[0].hour * 60 + x[0].minute))

    # 5. Split overlaps so that lessons/activities remain visible even when overlapping unavailability.
    intervals = split_overlaps(intervals)

    # 6. Build the final timeline from 00:00 to 24:00.
    day_start = time(0, 0)
    day_end = time(23, 59)  # Treat 23:59 as end of day.
    final_timeline = []
    current_time = day_start

    def time_to_minutes(t):
        return t.hour * 60 + t.minute

    def minutes_to_time(m):
        h, m = divmod(m, 60)
        return time(h, m)

    def fmt_time(t):
        return t.strftime("%H:%M")

    for (s, e, typ, title) in intervals:
        s_min = max(time_to_minutes(s), time_to_minutes(day_start))
        e_min = min(time_to_minutes(e), 24 * 60)
        if time_to_minutes(current_time) < s_min:
            # There is a gap – mark as available.
            final_timeline.append({
                "type": "available",
                "title": None,
                "start_time": fmt_time(current_time),
                "end_time": fmt_time(minutes_to_time(s_min)),
            })
            current_time = minutes_to_time(s_min)
        if time_to_minutes(current_time) < e_min:
            final_timeline.append({
                "type": typ,
                "title": title,
                "start_time": fmt_time(current_time),
                "end_time": fmt_time(minutes_to_time(e_min)),
            })
            current_time = minutes_to_time(e_min)
        if time_to_minutes(current_time) >= 24 * 60:
            break

    if time_to_minutes(current_time) < 24 * 60:
        difference = 24 * 60 - time_to_minutes(current_time)
        # Only add an available block if the gap is more than 1 minute.
        if difference > 1:
            final_timeline.append({
                "type": "available",
                "title": None,
                "start_time": fmt_time(current_time),
                "end_time": "24:00",
            })

    return Response(final_timeline, status=status.HTTP_200_OK)

@api_view(['GET'])
def get_all_usernames(request):
    # Query the UserAccount model and extract all usernames as a list.
    usernames = list(UserAccount.objects.values_list('username', flat=True))
    return Response(usernames, status=status.HTTP_200_OK)