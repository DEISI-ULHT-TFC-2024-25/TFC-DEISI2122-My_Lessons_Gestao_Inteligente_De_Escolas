from django.urls import path
from .utils import create_checkout_session
from .views import payment_success, payment_failed, start_test_checkout, test_payment, new_payment

urlpatterns = [
    path("payment-success/", payment_success, name="payment_success"),
    path("payment-failed/", payment_failed, name="payment_failed"),
    path("start-checkout/", start_test_checkout, name="start_checkout"),
    path('create_checkout_session/', create_checkout_session, name='create_checkout_session'),
    path("test-payment/", test_payment, name="test_payment"),
    path("new_payment/", new_payment, name="new_payment"),
]