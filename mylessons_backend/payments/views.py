from django.http import JsonResponse
from django.shortcuts import redirect, render
from django.views.decorators.csrf import csrf_exempt
import stripe
import json
from users.models import Student, UserAccount
from schools.models import School
from lessons.models import GroupPack, PrivatePack
from mylessons import settings
from .utils import create_checkout_session
import logging
logger = logging.getLogger(__name__)

stripe.api_key = settings.STRIPE_SECRET_KEY

#stripe listen --forward-to 127.0.0.1:8000/stripe/webhook

def test_payment(request):
    return render(request, 'payments/test-payment.html')

def start_test_checkout(request):
    """
    Simulate adding an item to a cart and initiating a Stripe Checkout session.
    """
    user = request.user  # Assuming authentication is in place
    cart = [
        {
            "type": "private_pack",
            "number_of_classes": 4,
            "duration_in_minutes": 60,
            "price": 100.00,  # Test price
            "school_name": "Test School",
            "student_ids_list": [1, 2],  # Dummy student IDs
        }
    ]
    discount = 10  # Test discount

    session_url = create_checkout_session(user, cart, discount)

    return redirect(session_url)

def payment_success(request):
    session_id = request.GET.get("session_id")
    session = None
    if session_id:
        try:
            session = stripe.checkout.Session.retrieve(session_id)
            # Log or print the payment status
            print("Payment status:", session.payment_status)
        except Exception as e:
            print("Error retrieving session:", e)
    return render(request, "payments/success.html", {"session": session})

def payment_failed(request):
    return render(request, "payments/fail.html")

# TODO now seccess and cancel url and views

@csrf_exempt
def stripe_webhook(request):
    """
    Handles Stripe webhook for successful payments.
    """
    print(">>> Webhook endpoint was hit!")
    logger.info("Webhook endpoint hit.")
    payload = request.body
    logger.info("Webhook received with payload: %s", payload)
    event = None

    try:
        event = json.loads(payload)
    except json.JSONDecodeError as e:
        logger.error("JSON decode error: %s", e)
        return JsonResponse({'error': str(e)}, status=400)

    if event.get("type") == "checkout.session.completed":
        logger.info("Checkout session completed event received")
        session = event["data"]["object"]
        user_id = session["metadata"]["user_id"]
        cart = json.loads(session["metadata"]["cart"])
        discount = float(session["metadata"]["discount"])
        student_ids_list = list(session["metadata"]["student_ids_list"])
        user = UserAccount.objects.get(id=user_id)
        students_list = []

        for id in student_ids_list:
            student = Student.objects.get(id = id)
            if student:
                students_list.append(student)

        for item in cart:
            pack_type = item["type"]  # "group_pack" or "private_pack"
            school = School.objects.get(name=item["school_name"])


            if pack_type == "group_pack":
                # TODO book_new_pack(?):
                pass
            elif pack_type == "private_pack":
                instructor = item['instructor']
                pack = PrivatePack.book_new_pack(students_list, school, None, item["number_of_classes"], item["duration_in_minutes"], instructor, item["price"], item["price"], discount)
                if not pack:
                    JsonResponse({"status": "cancel"}, status=200)
    return JsonResponse({"status": "success"}, status=200)
