from events.models import Activity, BirthdayParty, CampOrder
from payments.models import Payment
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.http import JsonResponse, HttpResponseRedirect
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
from django.http import HttpResponse


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
            student_ids_list = []  # Example: you might aggregate these if needed.
            for item in cart:
                price = item.get("price", 0)
                total_price += price
                # For this example, we'll use the student_ids_list from the last item.
                student_ids_list = item.get("student_ids_list", [])
            
            # Apply discount to total price.
            final_price = max(0, total_price - discount)
            # Convert to cents (assuming price is in Euros)
            amount_in_cents = int(final_price * 100)
            
            intent = stripe.PaymentIntent.create(
                amount=amount_in_cents,
                currency="eur",
                payment_method_types=["card"],
                metadata={
                    "user_id": str(request.user.id) if request.user.is_authenticated else "anonymous",
                    "cart": json.dumps(cart),
                    "discount": str(discount),
                    "student_ids_list": json.dumps(student_ids_list),
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
    
def deeplink_payment_success(request):
    session_id = request.GET.get("session_id", "")
    html_content = f"""
    <!DOCTYPE html>
    <html>
      <head>
        <title>Redirecting...</title>
        <!-- Option A: Meta refresh -->
        <meta http-equiv="refresh" content="0; url=myapp://payment-success?session_id={session_id}" />
        
        <!-- Option B: JavaScript (uncomment if you prefer JS):
        <script>
          window.location.href = "myapp://payment-success?session_id={session_id}";
        </script>
        -->
      </head>
      <body>
        <p>Redirecting to the app...</p>
      </body>
    </html>
    """
    return HttpResponse(html_content)

def deeplink_payment_fail(request):
    session_id = request.GET.get("session_id", "")
    html_content = f"""
    <!DOCTYPE html>
    <html>
      <head>
        <title>Redirecting...</title>
        <meta http-equiv="refresh" content="0; url=myapp://payment-fail?session_id={session_id}" />
      </head>
      <body>
        <p>Redirecting to the app...</p>
      </body>
    </html>
    """
    return HttpResponse(html_content)