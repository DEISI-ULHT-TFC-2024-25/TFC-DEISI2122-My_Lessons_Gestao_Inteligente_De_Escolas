"""
Django settings for MyLessons project.
"""

from pathlib import Path

import os

# Base Directory
BASE_DIR = Path(__file__).resolve().parent.parent

# Security Settings
SECRET_KEY = 'your-secret-key'
DEBUG = True  # Change to False in production
ALLOWED_HOSTS = ['*']  # Adjust for production

# Installed Apps
INSTALLED_APPS = [
    # Django default apps
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Third-party apps
    'rest_framework',        # Django REST Framework
    'rest_framework.authtoken',
    'corsheaders',           # Handle CORS
    'drf_yasg',              # API Documentation with Swagger
    'django.contrib.sites',  # Required for django-allauth
    'allauth',
    'allauth.account',
    'allauth.socialaccount',
    'allauth.socialaccount.providers.google',

    # Project apps
    'users',                 # User management and roles
    'schools',               # School configuration and settings
    'lessons',               # Lesson scheduling and booking
    'progress',              # Progress tracking and reports
    'payments',              # Payment processing and history
    'events',                # Events like camps and birthdays
    'equipment',            
    'notifications',
    'locations',
    'sports',
]

# Middleware
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    # Required for allauth
    'allauth.account.middleware.AccountMiddleware',
]



CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True

# URL Configuration
ROOT_URLCONF = 'mylessons.urls'

# Templates
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# WSGI Configuration
WSGI_APPLICATION = 'mylessons.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'mylessons$default',  # Replace with your actual database name
        'USER': 'mylessons',  # Your PythonAnywhere username
        'PASSWORD': 'hUWmTMZwK@X6v8r',  # Your MySQL password (set in PythonAnywhere)
        'HOST': 'mylessons.mysql.pythonanywhere-services.com',  # PythonAnywhere MySQL host
        'PORT': '3306',
    }
}

AUTH_USER_MODEL = 'users.UserAccount'


# Password Validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

SILENCED_SYSTEM_CHECKS = ["models.W036"]

AUTHENTICATION_BACKENDS = [
    'django.contrib.auth.backends.ModelBackend',
    'allauth.account.auth_backends.AuthenticationBackend',
]

SITE_ID = 1

STRIPE_SECRET_KEY = "sk_test_51QmkhvFKR0fDDDqcsd2utmLdfoOdnklem57fsmfJsgRwCoNGryqo2RhvOGpL0yz02MmF1tlXqcMukiflZ8toJnAs0047NSwiWB"

STRIPE_PUBLISHABLE_KEY = "pk_test_51QmkhvFKR0fDDDqcMPjzGLnTRzcF73xgfXA7bQ2Z2LmHND06TQqgq9wG9fM3SPqRP9bpkFTSCovRagcFxjrkkR7L00hLeKz2Lf"

STRIPE_WEBHOOK_SECRET = 'whsec_86b4d0b973573dabf6dc25baa2fd061397f6a5f2335c51ed313c3decb15634d7'

SUCCESS_URL = "https://mylessons.pythonanywhere.com/api/payments/payment-success"
CANCEL_URL = "https://mylessons.pythonanywhere.com/api/payments/payment-failed"


LOGIN_REDIRECT_URL = '/'
LOGOUT_REDIRECT_URL = '/'

SOCIALACCOUNT_PROVIDERS = {
    'google': {
        'SCOPE': [
            'profile',
            'email',
        ],
        'AUTH_PARAMS': {
            'access_type': 'online',
        },
        'APP': {
            'client_id': '147437937321-v39oeirc3e8hjgiejeugp3eia6vlmjbg.apps.googleusercontent.com',
            'secret': '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',
            'key': ''
        }
    }
}

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_L10N = True
USE_TZ = True
# Ensure UTF-8 encoding
DEFAULT_CHARSET = 'utf-8'


# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'

# Collects all static files here
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# Additional locations for static files
STATICFILES_DIRS = [
    os.path.join(BASE_DIR, 'static'),
]

# Media files (for user uploads)
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,  # keep Django's default loggers
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'DEBUG',  
    },
    'loggers': {
        '': {  # This configures all loggers
            'handlers': ['console'],
            'level': 'DEBUG',
            'propagate': True,
        },
    },
}


# Swagger Settings
SWAGGER_SETTINGS = {
    'USE_SESSION_AUTH': True,
    'SECURITY_DEFINITIONS': {
        'Bearer': {
            'type': 'apiKey',
            'name': 'Authorization',
            'in': 'header',
        },
    },
}

# Default Primary Key Field Type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'


EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = 'mylessons.test@gmail.com'
EMAIL_HOST_PASSWORD = 'ckhn lcmd nwnp cgfn'  # Google App Password


# Import local settings for local development overrides
try:
    from .local_settings import *
except ImportError:
    pass
