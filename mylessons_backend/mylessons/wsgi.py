"""
WSGI config for mylessons project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.1/howto/deployment/wsgi/
"""

import os

from django.core.wsgi import get_wsgi_application

# ─── Firebase Admin init ─────────────────────────────────
import firebase_admin
from firebase_admin import credentials

if not firebase_admin._apps:
    BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # Now build the full path to the JSON file inside "mylessons_backend".
    json_path = os.path.join(BASE_DIR, "mylessons-7b4ed-firebase-adminsdk-fbsvc-9390c43ae3.json")
    cred = credentials.Certificate(json_path)
    firebase_admin.initialize_app(cred)
# ───────────────────────────────────────────────────────────


os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mylessons.settings')

application = get_wsgi_application()
