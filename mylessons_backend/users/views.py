from django.contrib.auth import authenticate, get_user_model
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status
from django.views.decorators.csrf import csrf_exempt
from rest_framework.permissions import AllowAny
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import logging
from django.contrib.auth.hashers import make_password
from .models import UserAccount
from .serializers import UserAccountSerializer

logger = logging.getLogger(__name__)


User = get_user_model()

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    # Expecting JSON body with "username" and "password"
    username = request.data.get('username')
    password = request.data.get('password')

    user = authenticate(username=username, password=password)
    if user is not None:
        return Response({'message': 'Login successful'}, status=status.HTTP_200_OK)
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