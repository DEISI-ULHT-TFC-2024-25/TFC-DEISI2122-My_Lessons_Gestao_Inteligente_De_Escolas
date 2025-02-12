from django.urls import path
from .views import payment_success, payment_failed, start_test_checkout, test_payment

urlpatterns = [
    path("payment-success/", payment_success, name="payment_success"),
    path("payment-failed/", payment_failed, name="payment_failed"),
    path("start-checkout/", start_test_checkout, name="start_checkout"),
    path("test-payment/", test_payment, name="test_payment"),
]