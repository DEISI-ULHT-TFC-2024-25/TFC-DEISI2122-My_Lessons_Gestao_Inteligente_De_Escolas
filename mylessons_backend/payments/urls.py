from django.urls import path
from .views import create_checkout_session_view, create_debt_payment_intent_view, create_debt_payment_record_view, create_payment_intent_view, instructor_payment_history, payment_history_view, payment_success, payment_failed, my_webhook_view, payments_debt_view, redulate_debt_view, school_payment_history_view, school_unpaid_items_view, test_payment, new_payment, unpaid_items_view, upcoming_payouts_view, verify_payment

urlpatterns = [
    path("payment-success/", payment_success, name="payment_success"),
    path("payment-failed/", payment_failed, name="payment_failed"),
    path('create_checkout_session/', create_checkout_session_view, name='create_checkout_session'),
    path("test-payment/", test_payment, name="test_payment"),
    path("new_payment/", new_payment, name="new_payment"),
    path('stripe_webhook/', my_webhook_view, name='stripe_webhook'),
    path('verify_payment/', verify_payment, name='verify_payment'),
    path('create_payment_intent/', create_payment_intent_view, name='create_payment_intent'),
    path('debt/', payments_debt_view, name='payments_debt'),
    path('unpaid_items/', unpaid_items_view, name='unpaid_items'),
    path('history/', payment_history_view, name='payment_history'),
    path('redulate_debt/', redulate_debt_view, name='redulate_debt'),
    path('instructor_payment_history/', instructor_payment_history, name='instructor_payment_history'),
    path('school_unpaid_items/', school_unpaid_items_view, name='school_unpaid_items'),
    path('upcoming_payouts/', upcoming_payouts_view, name='upcoming_payouts'),
    path('school_payment_history/', school_payment_history_view, name='school_payment_history'),
    path('create_debt_payment_intent/', create_debt_payment_intent_view, name='school_payment_history'),
    path('create_debt_payment_record/', create_debt_payment_record_view, name='create_debt_payment_record'),
]
