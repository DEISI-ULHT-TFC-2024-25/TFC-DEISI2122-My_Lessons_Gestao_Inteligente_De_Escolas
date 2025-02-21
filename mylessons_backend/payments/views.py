from events.models import Activity, BirthdayParty, CampOrder
from payments.models import Payment
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.http import JsonResponse
from django.shortcuts import redirect, render
from django.views.decorators.csrf import csrf_exempt
import stripe
import json
from users.models import Instructor, Monitor, Student, UserAccount
from schools.models import School
from lessons.models import Lesson, Pack, Voucher
from mylessons import settings
from .utils import create_checkout_session
import logging
from datetime import datetime, timedelta
from django.utils.timezone import now
from django.db import transaction



logger = logging.getLogger(__name__)

stripe.api_key = settings.STRIPE_SECRET_KEY

#stripe listen --forward-to 127.0.0.1:8000/stripe/webhook

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def new_payment(request):
    user = request.user
    data = request.data

    # TODO 
    # change receipt info (tab the lessons of the pack to separate them from each other or from separate lessons)
    # change debt and is_paid flag
    # register request.user
    # change receipt for staff payments

    try:
        with transaction.atomic():
            # Extract and validate payment details
            value = data.get("value")
            if not value or float(value) <= 0:
                return Response({"error": "Invalid payment amount."}, status=400)
            
            school_id = data.get("school")
            school = School.objects.get(id=school_id) if school_id else None
            
            user_id = data.get("user")
            payment_user = UserAccount.objects.get(id=user_id)
            
            payment = Payment.objects.create(
                value=value,
                user=payment_user,
                school=school,
                description=data.get("description", {})
            )

            # Process individual lessons
            lessons = data.get("lessons", [])
            for lesson_id in lessons:
                lesson = Lesson.objects.get(id=lesson_id)
                payment.lessons.add(lesson)

            # Process packs and related lessons
            packs = data.get("packs", [])
            for pack_id in packs:
                pack = Pack.objects.get(id=pack_id)
                payment.packs.add(pack)
                for lesson in pack.lessons.all():
                    payment.lessons.add(lesson)

            # Process individual activities
            activities = data.get("activities", [])
            for activity_id in activities:
                activity = Activity.objects.get(id=activity_id)
                payment.activities.add(activity)

            # Process camp orders and related activities
            camp_orders = data.get("camp_orders", [])
            for camp_order_id in camp_orders:
                camp_order = CampOrder.objects.get(id=camp_order_id)
                payment.camp_orders.add(camp_order)
                for activity in camp_order.activities.all():
                    payment.activities.add(activity)

            # Process birthday parties and related activities
            birthday_parties = data.get("birthday_parties", [])
            for party_id in birthday_parties:
                party = BirthdayParty.objects.get(id=party_id)
                payment.birthday_parties.add(party)
                for activity in party.activities.all():
                    payment.activities.add(activity)

            # Process vouchers
            vouchers = data.get("vouchers", [])
            for voucher_id in vouchers:
                voucher = Voucher.objects.get(id=voucher_id)
                payment.vouchers.add(voucher)

            # Assign instructor or monitor if specified
            instructor_id = data.get("instructor")
            monitor_id = data.get("monitor")
            if instructor_id:
                payment.instructor = Instructor.objects.get(id=instructor_id)
            if monitor_id:
                payment.monitor = Monitor.objects.get(id=monitor_id)

            payment.save()
            
            # Send receipt email using Payment model's method
            payment.send_receipt_email()
            
            # TODO Create a notification
            
            return Response({"message": "Payment successfully processed."}, status=201)

    except Exception as e:
        return Response({"error": str(e)}, status=400)
    




def test_payment(request):
    return render(request, 'payments/test-payment.html')

def start_test_checkout(request):
    """
    Simulate adding an item to a cart and initiating a Stripe Checkout session.
    """
    user = request.user  # Assuming authentication is in place
    cart = [
        {
            "type": "private",
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
            instructor = item['instructor']

            # TODO check book structure (is something is missing here)

            pack = Pack.book_new_pack(students=students_list, school=school, number_of_classes=item["number_of_classes"], duration_in_minutes=item["duration_in_minutes"], instructors=[instructor], price=item["price"], discount_id=discount)
            if not pack:
                JsonResponse({"status": "cancel"}, status=200)
    return JsonResponse({"status": "success"}, status=200)
