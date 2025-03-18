from decimal import Decimal
from events.models import Activity, BirthdayParty, CampOrder
from payments.models import Payment
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.http import JsonResponse, HttpResponseRedirect
from django.shortcuts import redirect, render, get_object_or_404
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
from django.http import HttpResponse
from django.db.models import Q


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

@csrf_exempt
def create_payment_intent_view(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            cart = data.get('cart', [])
            discount = data.get('discount', 0)
            
            total_price = 0
            # Calculate the total price from the cart.
            for item in cart:
                price = item.get("price", 0)
                total_price += price
            
            # Apply discount to total price.
            final_price = max(0, total_price - discount)
            # Convert to cents (assuming price is in Euros)
            amount_in_cents = int(final_price * 100)
            
            # Create a summary of the cart.
            cart_summary = {
                "item_count": len(cart),
                "total_price": total_price,
            }
            
            # Calculate total student count (aggregated across all cart items).
            student_count = sum(len(item.get("student_ids_list", [])) for item in cart)
            
            intent = stripe.PaymentIntent.create(
                amount=amount_in_cents,
                currency="eur",
                payment_method_types=["card"],
                metadata={
                    "user_id": str(request.user.id) if request.user.is_authenticated else "anonymous",
                    "cart_summary": json.dumps(cart_summary),
                    "discount": str(discount),
                    "student_count": str(student_count),
                }
            )
            return JsonResponse({"clientSecret": intent.client_secret}, status=200)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=400)
    
    return JsonResponse({"error": "Method not allowed"}, status=405)


@csrf_exempt
def create_checkout_session_view(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)

            # 1) Extract cart & discount from the JSON payload:
            cart = data.get('cart', [])
            discount = data.get('discount', 0)

            # 2) Get the user.
            # If using Django’s session auth:
            user = request.user
            # or if your user is not logged in via session, you might parse user ID from data:
            # user_id = data.get('user_id')
            # user = MyUser.objects.get(id=user_id)

            # 3) Now call your existing helper function:
            session_url = create_checkout_session(user, cart, discount)
            
            # 4) Return the session URL in JSON:
            return JsonResponse({'url': session_url}, status=200)

        except Exception as e:
            return JsonResponse({'error': str(e)}, status=400)

    return JsonResponse({'error': 'Method not allowed'}, status=405)

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

stripe.api_key = 'sk_test_51QmkhlJwT5CCGmges88003pOz7TdN6vzhZquphq13zUEAm9PJqncJU7kcYgKhpYu1cUGjlIsPveyXYn7hKjpOnhG00jYIoinVr'
endpoint_secret = 'whsec_5EcGjLPpcfMjRNDpGVbahPjQWAyZgGmZ'

# Using Django
@csrf_exempt
def my_webhook_view(request):
    logger.debug("WEBHOOK WAS HIT!!")
    payload = request.body
    sig_header = request.META['HTTP_STRIPE_SIGNATURE']
    event = None

    try:
        event = stripe.Webhook.construct_event(
        payload, sig_header, endpoint_secret
        )
    except ValueError as e:
        # Invalid payload
        logger.debug('Error parsing payload: {}'.format(str(e)))
        return HttpResponse(status=400)
    except stripe.error.SignatureVerificationError as e:
        # Invalid signature
        logger.debug('Error verifying webhook signature: {}'.format(str(e)))
        return HttpResponse(status=400)

    # Handle the event
    if event.type == 'payment_intent.succeeded':
        payment_intent = event.data.object # contains a stripe.PaymentIntent
        logger.debug('PaymentIntent was successful!')
    elif event.type == 'payment_method.attached':
        payment_method = event.data.object # contains a stripe.PaymentMethod
        logger.debug('PaymentMethod was attached to a Customer!')
    # ... handle other event types
    else:
        logger.debug('Unhandled event type {}'.format(event.type))

    return HttpResponse(status=200)

@csrf_exempt
def verify_payment(request):
    session_id = request.GET.get("session_id")
    if not session_id:
        return JsonResponse({"error": "No session_id provided."}, status=400)

    try:
        # Set your secret key
        stripe.api_key = settings.STRIPE_SECRET_KEY

        # Retrieve the Checkout Session
        session = stripe.checkout.Session.retrieve(session_id)

        # Check the payment status.
        # The session object has a 'payment_status' field that should be 'paid' if successful.
        if session.payment_status == "paid":
            return JsonResponse({"verified": True})
        else:
            return JsonResponse({"verified": False})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)
    
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def payments_debt_view(request):
    """
    Returns the current outstanding debt for the authenticated user.
    For Parent users, sums the debt of every pack where the user is in pack.parents.all() and the pack's debt is > 0.
    """
    user = request.user
    if getattr(user, 'current_role', None) != "Parent":
        return Response({"detail": "This endpoint is not available for your role."}, status=status.HTTP_200_OK)
    
    unpaid_packs = Pack.objects.filter(parents=user, debt__gt=0)
    total_debt = sum([pack.debt for pack in unpaid_packs]) if unpaid_packs.exists() else Decimal('0.00')
    return Response({"current_debt": str(total_debt)}, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def unpaid_items_view(request):
    """
    Returns a list of unpaid items for the current user.
    For Parent users, an unpaid item is defined as a pack where the user is among pack.parents and the debt is > 0.
    Each item returns its date, a description, and the remaining amount (debt).
    """
    user = request.user
    if getattr(user, 'current_role', None) != "Parent":
        return Response({"detail": "This endpoint is not available for your role."}, status=status.HTTP_200_OK)
    
    unpaid_packs = Pack.objects.filter(parents=user, debt__gt=0)
    items = []
    for pack in unpaid_packs:
        items.append({
            "date": pack.date.strftime("%Y-%m-%d") if pack.date else "",
            "time": pack.date_time.strftime("%H:%M") if pack.date_time else "09:00",
            "description": str(pack),  # Adjust as needed.
            "amount": str(pack.debt) if pack.debt else "0.00",
        })
    return Response(items, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def payment_history_view(request):
    """
    Returns the full payment history for the current user.
    For Parent users, for each Payment, returns:
      - date (formatted as "YYYY-MM-DD")
      - time (formatted as "HH:mm")
      - school (the school name, if available)
      - description (which is a JSON field or string)
      - amount
    Filtering is done on the front end.
    """
    user = request.user
    if getattr(user, 'current_role', None) != "Parent":
        return Response({"detail": "This endpoint is not available for your role."}, status=status.HTTP_200_OK)
    
    payments = Payment.objects.filter(user=user).order_by('-date', '-time')
    history = []
    for pay in payments:
        history.append({
            "date": pay.date.strftime("%Y-%m-%d"),
            "time": pay.time.strftime("%H:%M"),
            "school": pay.school.name if pay.school else "",
            "description": pay.description,
            "amount": str(pay.value),
        })
    
    return Response(history, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def redulate_debt_view(request):
    """
    "Redulate Debt" recalculates the current outstanding debt for the user.
    For Parent users, it sums the debt on all packs where the user is among pack.parents and debt > 0.
    """
    user = request.user
    if getattr(user, 'current_role', None) != "Parent":
        return Response({"detail": "This endpoint is not available for your role."}, status=status.HTTP_200_OK)
    
    unpaid_packs = Pack.objects.filter(parents=user, debt__gt=0)
    total_debt = sum([pack.debt for pack in unpaid_packs]) if unpaid_packs.exists() else Decimal('0.00')
    # Optionally perform additional logic (such as updating model values) here.
    return Response({"message": "Debt recalculated", "current_debt": str(total_debt)}, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def instructor_payment_history(request):
    """
    Returns the full payment history for the current user.
    For Parent users, for each Payment, returns:
      - date (formatted as "YYYY-MM-DD")
      - time (formatted as "HH:mm")
      - school (the school name, if available)
      - description (which is a JSON field or string)
      - amount
    Filtering is done on the front end.
    """
    user = request.user
    if getattr(user, 'current_role', None) != "Instructor":
        return Response({"detail": "This endpoint is not available for your role."}, status=status.HTTP_200_OK)
    
    payments = Payment.objects.filter(instructor=user.instructor_profile).order_by('-date', '-time')
    history = []
    for pay in payments:
        history.append({
            "date": pay.date.strftime("%Y-%m-%d"),
            "time": pay.time.strftime("%H:%M"),
            "school": pay.school.name if pay.school else "",
            "description": pay.description,
            "amount": str(pay.value),
        })
    
    return Response(history, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def school_unpaid_items_view(request):
    """
    Returns a list of unpaid items (packs with debt > 0) for the Admin's school.
    For each pack, returns:
      - the pack's ID,
      - the result of pack.getStudentsName(),
      - the pack's date (formatted as "YYYY-MM-DD"),
      - the pack's debt.
    Accessible only if request.user.current_role == "Admin".
    """
    if getattr(request.user, 'current_role', None) != "Admin":
        return Response({"error": "Not authorized."}, status=status.HTTP_403_FORBIDDEN)
    
    school_id = getattr(request.user, 'current_school_id', None)
    if not school_id:
        return Response({"error": "School not found for user."}, status=status.HTTP_400_BAD_REQUEST)
    
    school = get_object_or_404(School, id=school_id)
    packs = Pack.objects.filter(school=school, debt__gt=0)
    
    data = []
    for pack in packs:
        data.append({
            "id": str(pack.id),
            "students_name": pack.get_students_name(),  # Call the method to get students' names.
            "date": pack.date.strftime("%Y-%m-%d") if pack.date else "",
            "time": pack.date_time.strftime("%H:%M") if pack.date_time else "09:00",
            "amount": str(pack.debt) if pack.debt else "0.00",
            "description": str(pack),
        })
    return Response(data, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def upcoming_payouts_view(request):
    """
    Returns a list of unique UserAccount objects from the Admin's school who are in any of:
      - school.admins,
      - school.instructors (converted via Instructor.user),
      - school.monitors (converted via Monitor.user).
    For each user, returns their id, name, current_balance, and the output of
    get_balance_history_since_last_payout().
    Accessible only if request.user.current_role == "Admin".
    """
    if getattr(request.user, 'current_role', None) != "Admin":
        return Response({"error": "Not authorized."}, status=status.HTTP_403_FORBIDDEN)

    school_id = getattr(request.user, 'current_school_id', None)
    if not school_id:
        return Response({"error": "School not found for user."}, status=status.HTTP_400_BAD_REQUEST)

    school = get_object_or_404(School, id=school_id)

    # Get UserAccount objects from admins directly
    admins = set(school.admins.all())

    # Convert instructors to UserAccount objects via Instructor.user
    instructors = set()
    for instructor in school.instructors.all():
        if hasattr(instructor, 'user') and instructor.user:
            instructors.add(instructor.user)

    # Convert monitors to UserAccount objects via Monitor.user
    monitors = set()
    for monitor in school.monitors.all():
        if hasattr(monitor, 'user') and monitor.user:
            monitors.add(monitor.user)

    # Union all user objects together
    all_users = admins.union(instructors).union(monitors)

    data = []
    for user in all_users:
        data.append({
            "id": str(user.id),
            "name": str(user),
            "current_balance": str(user.balance),
            "description": user.get_balance_history_since_last_payout(),
        })

    return Response(data, status=status.HTTP_200_OK)



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def school_payment_history_view(request):
    """
    Returns a list of all Payment objects for the Admin's school.
    Each Payment includes:
      - id,
      - date (formatted as "YYYY-MM-DD"),
      - time (formatted as "HH:MM"),
      - value,
      - description.
    Accessible only if request.user.current_role == "Admin".
    """
    if getattr(request.user, 'current_role', None) != "Admin":
        return Response({"error": "Not authorized."}, status=status.HTTP_403_FORBIDDEN)
    
    school_id = getattr(request.user, 'current_school_id', None)
    if not school_id:
        return Response({"error": "School not found for user."}, status=status.HTTP_400_BAD_REQUEST)
    
    school = get_object_or_404(School, id=school_id)
    payments = Payment.objects.filter(school=school).order_by('-date', '-time')
    
    data = []
    for pay in payments:
        data.append({
            "id": str(pay.id),
            "date": pay.date.strftime("%Y-%m-%d") if pay.date else "",
            "time": pay.time.strftime("%H:%M") if pay.time else "",
            "value": str(pay.value),
            "description": pay.description,
        })
    return Response(data, status=status.HTTP_200_OK)