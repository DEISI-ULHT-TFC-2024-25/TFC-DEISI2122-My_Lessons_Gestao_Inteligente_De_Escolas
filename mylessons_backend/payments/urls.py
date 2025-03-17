from django.urls import path
from .views import create_checkout_session_view, payment_success, payment_failed, my_webhook_view, test_payment, new_payment, verify_payment

urlpatterns = [
    path("payment-success/", payment_success, name="payment_success"),
    path("payment-failed/", payment_failed, name="payment_failed"),
    path('create_checkout_session/', create_checkout_session_view, name='create_checkout_session'),
    path("test-payment/", test_payment, name="test_payment"),
    path("new_payment/", new_payment, name="new_payment"),
    path('stripe_webhook/', my_webhook_view, name='stripe_webhook'),
    path('verify_payment/', verify_payment, name='verify_payment'),
]
