from datetime import datetime, timedelta
from django.contrib.auth import authenticate, get_user_model
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework import status
from django.views.decorators.csrf import csrf_exempt
from rest_framework.permissions import AllowAny, IsAuthenticated
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import logging
from django.contrib.auth.hashers import make_password
from .models import UserAccount, Instructor
from .serializers import UserAccountSerializer
from notifications.models import Notification
from lessons.models import Lesson, Pack
from schools.models import School
from django.db.models import Q
from django.utils.timezone import now

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
@permission_classes([AllowAny])  # Permite acesso sem autenticação
def register_user(request):
    """
    Regista um novo utilizador na base de dados.
    """
    data = request.data

    required_fields = ['email', 'password', 'first_name', 'last_name', 'country_code', 'phone']
    missing_fields = [field for field in required_fields if field not in data]

    if missing_fields:
        return Response({'error': f'Missing fields: {", ".join(missing_fields)}'}, status=status.HTTP_400_BAD_REQUEST)

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

        return Response({'message': 'User registered successfully'}, status=status.HTTP_201_CREATED)

    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_profile(request):
    user = request.user  # Obtém o utilizador autenticado

    # Conta as notificações não lidas
    unread_notifications = Notification.objects.filter(user=user, date_read=None).count()

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
    current_school_id = user.current_school_id if user.current_school_id else 0

    available_schools = []

    # Check and retrieve schools based on the user's role
    if current_role == "Admin":
        available_schools = [
            {"id": school.id, "name": school.name} for school in user.school_admins.all().exclude(id=current_school_id)
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

