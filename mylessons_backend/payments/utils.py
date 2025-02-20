import stripe
import json
from django.conf import settings
from users.models import UserAccount
from schools.models import School
from lessons.models import Pack

stripe.api_key = settings.STRIPE_SECRET_KEY  # Store this in settings.py

def create_checkout_session(user, cart, discount=0):
    """
    Creates a Stripe Checkout session for the user's cart.
    """
    line_items = []
    total_price = 0

    for item in cart:
        pack_type = item["type"]  # "group_pack" or "private_pack"
        num_classes = item["number_of_classes"]
        duration = item["duration_in_minutes"]
        price = item["price"]  # Price BEFORE discount
        student_ids_list = item["student_ids_list"]

        total_price += price  # Sum up total price

        # TODO later, change currency, name and description, discount

        line_items.append({
            "price_data": {
                "currency": "eur",
                "unit_amount": int(price * 100),  # Convert to cents
                "product_data": {
                    "name": f"{pack_type.replace('_', ' ').title()}",
                    "description": f"School: {item['school_name']}",
                },
            },
            "quantity": 1,
        })

    # Apply discount to total
    final_price = max(0, total_price - discount)

    session = stripe.checkout.Session.create(
        payment_method_types=["card"],
        line_items=line_items,
        mode="payment",
        success_url=settings.SUCCESS_URL + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url=settings.CANCEL_URL,
        metadata={
            "user_id": str(user.id),
            "cart": json.dumps(cart),
            "discount": str(discount),
            "student_ids_list": json.dumps(student_ids_list),
        }
    )
    print("Created session:", session)  # or use logging.info

    return session.url
