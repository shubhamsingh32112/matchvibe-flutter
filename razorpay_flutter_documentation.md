Integration Steps
Steps to integrate the Flutter application with Razorpay Payment Gateway.

1. Build Integration
Follow the steps given below:

1.1 Install Razorpay Flutter Plugin
Download the plugin from Pub.dev.

Add the below code to dependencies in your app's pubspec.yaml

Add Dependencies

copy

razorpay_flutter: 1.4.0
Add Proguard Rules (Android Only)
If you are using Proguard for your builds, you need to add the following lines to the Proguard files:

Add Proguard Rules

copy

-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
 public void onPayment*(...);
}
Know more about Proguard rules.

Get Packages
Run flutter packages get in the root directory of your app.

Minimum Version Requirement

For Android, ensure that the minimum API level for your app is 19 or higher.

1.2 Import Package and Create Razorpay Instance
Use the below code to import the razorpay_flutter.dart file to your project.

Import Package

copy

import 'package:razorpay_flutter/razorpay_flutter.dart';
Use the below code to create a Razorpay instance.

Instantiate

copy

_razorpay = Razorpay();
1.3 Attach Event Listeners
The plugin uses event-based communication and emits events when payments fail or succeed.

The event names are exposed via the constants EVENT_PAYMENT_SUCCESS, EVENT_PAYMENT_ERROR and EVENT_EXTERNAL_WALLET from the Razorpay class.

Use the on(String event, Function handler) method on the Razorpay instance to attach event listeners.

Attach Event Listeners

copy

_razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
_razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
_razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
The handlers would be defined in the class as:

Handlers

copy

void _handlePaymentSuccess(PaymentSuccessResponse response) {
  // Do something when payment succeeds
}

void _handlePaymentError(PaymentFailureResponse response) {
  // Do something when payment fails
}

void _handleExternalWallet(ExternalWalletResponse response) {
  // Do something when an external wallet is selected
}
To clear event listeners, use the clear method on the Razorpay instance.

Clear Event Listeners

copy

_razorpay.clear(); // Removes all listeners
1.4 Create an Order in Server
Order is an important step in the payment process.

An order should be created for every payment.
You can create an order using the Orders API. It is a server-side API call. Know how to authenticate Orders API.
The order_id received in the response should be passed to the checkout. This ties the order with the payment and secures the request from being tampered.
Watch Out!

Payments made without an order_id cannot be captured and will be automatically refunded. You must create an order before initiating payments to ensure proper payment processing.

You can create an order using:


API Sample Code


Razorpay Postman Public Workspace

Use this endpoint to create an order using the Orders API.

POST
/orders
Curl
Java
Python
Go
PHP
Ruby
Node.js
.NET

copy

var instance = new Razorpay({ key_id: 'YOUR_KEY_ID', key_secret: 'YOUR_SECRET' })

instance.orders.create({
amount: 50000,
currency: "INR",
receipt: "receipt#1",
notes: {
    key1: "value3",
    key2: "value2"
}
})
Success Response
Failure Response

copy

{
    "id": "order_IluGWxBm9U8zJ8",
    "entity": "order",
    "amount": 50000,
    "amount_paid": 0,
    "amount_due": 50000,
    "currency": "INR",
    "receipt": "rcptid_11",
    "offer_id": null,
    "status": "created",
    "attempts": 0,
    "notes": [],
    "created_at": 1642662092
}


Request Parameters
amount

mandatory

integer The transaction amount, expressed in the currency subunit. For example, for an actual amount of ₹222.25, the value of this field should be 22225.

currency

mandatory

string The currency in which the transaction should be made. See the list of supported currencies. Length must be of 3 characters.

receipt

optional

string Your receipt id for this order should be passed here. Maximum length is 40 characters.

notes

optional

json object Key-value pair that can be used to store additional information about the entity. Maximum 15 key-value pairs, 256 characters (maximum) each. For example, "note_key": "Beam me up Scotty”.

partial_payment

optional

boolean Indicates whether the customer can make a partial payment. Possible values:
true: The customer can make partial payments.
false (default): The customer cannot make partial payments.

first_payment_min_amount

optional

integer Minimum amount that must be paid by the customer as the first partial payment. For example, if an amount of ₹7,000 is to be received from the customer in two installments of #1 - ₹5,000, #2 - ₹2,000, then you can set this value as 500000. This parameter should be passed only if partial_payment is true.

Response Parameters
Descriptions for the response parameters are present in the Orders Entity parameters table.

Error Response Parameters
The error response parameters are available in the API Reference Guide.


1.5 Add Checkout Options
Pass the Checkout options. Ensure that you pass the order_id that you received in the response of the previous step.

Checkout Options

copy

var options = {
  'key': '<YOUR_KEY_ID>',
  'amount': 50000, 
  'currency': 'INR',
  'name': 'Acme Corp.',
  'order_id': 'order_EMBFqjDHEEn80l', // Generate order_id using Orders API
  'description': 'Fine T-Shirt',
  'timeout': 60, // in seconds
  'prefill': {
    'contact': '+919876543210',
    'email': 'gaurav.kumar@example.com'
  }
};
Checkout Options
You must pass these parameters in Checkout to initiate the payment.

key

mandatory

string API Key ID generated from the Dashboard.

amount

mandatory

integer Payment amount in the smallest currency subunit. For example, if the amount to be charged is ₹2,222.50, enter 222250 in this field. In the case of three decimal currencies, such as KWD, BHD and OMR, to accept a payment of 295.991, pass the value as 295990. And in the case of zero decimal currencies such as JPY, to accept a payment of 295, pass the value as 295.
Watch Out!

As per payment guidelines, you should pass the last decimal number as 0 for three decimal currency payments. For example, if you want to charge a customer 99.991 KD for a transaction, you should pass the value for the amount parameter as 99990 and not 99991.


currency

mandatory

string The currency in which the payment should be made by the customer. See the list of supported currencies.
Handy Tips

Razorpay has added support for zero decimal currencies, such as JPY, and three decimal currencies, such as KWD, BHD, and OMR, allowing businesses to accept international payments in these currencies. Know more about Currency Conversion (May 2024).


name

mandatory

string Your Business/Enterprise name shown on the Checkout form. For example, Acme Corp.

description

optional

string Description of the purchase item shown on the Checkout form. It should start with an alphanumeric character.

image

optional

string Link to an image (usually your business logo) shown on the Checkout form. Can also be a base64 string if you are not loading the image from a network.

order_id

mandatory

string Order ID generated via Orders API.

prefill

object You can prefill the following details at Checkout.
Boost Conversions and Minimise Drop-offs

Autofill customer contact details, especially phone number to ease form completion. Include customer’s phone number in the contact parameter of the JSON request's prefill object. Format: +(country code)(phone number). Example: "contact": "+919000090000".
This is not applicable if you do not collect customer contact details on your website before checkout, have Shopify stores or use any of the no-code apps.

notes

optional

object Set of key-value pairs that can be used to store additional information about the payment. It can hold a maximum of 15 key-value pairs, each 256 characters long (maximum).

theme

object Thematic options to modify the appearance of Checkout.

modal

object Options to handle the Checkout modal.

subscription_id

optional

string If you are accepting recurring payments using Razorpay Checkout, you should pass the relevant subscription_id to the Checkout. Know more about Subscriptions on Checkout.

subscription_card_change

optional

boolean Permit or restrict customer from changing the card linked to the subscription. You can also do this from the hosted page. Possible values:
true: Allow the customer to change the card from Checkout.
false (default): Do not allow the customer to change the card from Checkout.

recurring

optional

boolean Determines if you are accepting recurring (charge-at-will) payments on Checkout via instruments such as emandate, paper NACH and so on. Possible values:
true: You are accepting recurring payments.
false (default): You are not accepting recurring payments.

callback_url

optional

string Customers will be redirected to this URL on successful payment. Ensure that the domain of the Callback URL is allowlisted.

redirect

optional

boolean Determines whether to post a response to the event handler post payment completion or redirect to Callback URL. callback_url must be passed while using this parameter. Possible values:
true: Customer is redirected to the specified callback URL in case of payment failure.
false (default): Customer is shown the Checkout popup to retry the payment with the suggested next best option.

customer_id

optional

string Unique identifier of customer. Used for:
Local saved cards feature.
Static bank account details on Checkout in case of Bank Transfer payment method.

remember_customer

optional

boolean Determines whether to allow saving of cards. Can also be configured via the Dashboard. Possible values:
true: Enables card saving feature.
false (default): Disables card saving feature.

timeout

optional

integer Sets a timeout on Checkout, in seconds. After the specified time limit, the customer will not be able to use Checkout.
Watch Out!

Some browsers may pause JavaScript timers when the user switches tabs, especially in power saver mode. This can cause the checkout session to stay active beyond the set timeout duration.


readonly

object Marks fields as read-only.

hidden

object Hides the contact details.

send_sms_hash

optional

boolean Used to auto-read OTP for cards and netbanking pages. Applicable from Android SDK version 1.5.9 and above. Possible values:
true: OTP is auto-read.
false (default): OTP is not auto-read.

allow_rotation

optional

boolean Used to rotate payment page as per screen orientation. Applicable from Android SDK version 1.6.4 and above. Possible values:
true: Payment page can be rotated.
false (default): Payment page cannot be rotated.

retry

optional

object Parameters that enable retry of payment on the checkout.

config

optional

object Parameters that enable checkout configuration. Know more about how to configure payment methods on Razorpay standard checkout.

1.5.1 Enable UPI Intent on iOS (Optional)
Provide your customers with a better payment experience by enabling UPI Intent on your app's Checkout form. In the UPI Intent flow:

Customer selects UPI as the payment method in your iOS app. A list of UPI apps supporting the intent flow is displayed. For example, PhonePe, Google Pay and Paytm.
Customer selects the preferred app. The UPI app opens with pre-populated payment details.
Customer enters their UPI PIN to complete their transactions.
Once the payment is successful, the customer is redirected to your app or website.
To enable this in your iOS integration, you must make the following changes in your app's info.plist file.

info.plist

copy

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tez</string>
    <string>phonepe</string>
    <string>paytmmp</string>
    <string>credpay</string>
    <string>mobikwik</string>
    <string>in.fampay.app</string>
    <string>bhim</string>
    <string>amazonpay</string>
    <string>navi</string>
    <string>kiwi</string>
    <string>payzapp</string>
    <string>jupiter</string>
    <string>omnicard</string>
    <string>icici</string>
    <string>popclubapp</string>
    <string>sbiyono</string>
    <string>myjio</string>
    <string>slice-upi</string>
    <string>bobupi</string>
    <string>shriramone</string>
    <string>indusmobile</string>
    <string>whatsapp</string>
    <string>kotakbank</string>
</array>
Know more about UPI Intent and its benefits.

UPI Intent on Recurring Payments
Configure and initiate a recurring payment transaction on UPI Intent:

ViewController.swift


copy

let options: [String:Any] = [
  "key": "YOUR_KEY_ID",  
  "order_id": "order_DBJOWzybfXXXX", 
  "customer_id": "cust_BtQNqzmBlXXXX",  
  "prefill": [
    "contact": "+919000090000",
    "email": "gaurav.kumar@example.com"
  ],
  "image": "https://spaceplace.nasa.gov/templates/featured/sun/sunburn300.png",
  "amount": 10000,  // Amount should match the order amount 
  "currency": "INR",
  "recurring": 1  // This key value pair is mandatory for Intent Recurring Payment.
]

ViewController.m
NSDictionary *options = @{
    @"key": @"YOUR_KEY_ID",
    @"order_id": @"order_DBJOWzybfXXXX",
    @"customer_id": @"cust_BtQNqzmBlXXXX",
    @"prefill": @{
        @"contact": @"+919000090000",
        @"email": @"gaurav.kumar@example.com"
    },
    @"image": @"https://spaceplace.nasa.gov/templates/featured/sun/sunburn300.png",
    @"amount": @(10000), // Amount should match the order amount 
    @"currency": @"INR",
    @"recurring": @(1)  // This key value pair is mandatory for Intent Recurring Payment.
};

1.6 Open Checkout
Use the below code to open the Razorpay checkout.

Open Razorpay Checkout

copy

_razorpay.open(options);

1.7 Store Fields in Your Server
A successful payment returns the following fields to the Checkout form.

Success Callback
You need to store these fields in your server.
You can confirm the authenticity of these details by verifying the signature in the next step.
Success Callback

copy

{
  "razorpay_payment_id": "pay_29QQoUBi66xm2f",
  "razorpay_order_id": "order_9A33XWu170gUtm",
  "razorpay_signature": "9ef4dffbfd84f1318f6739a3ce19f9d85851857ae648f114332d8401e0949a3d"
}

razorpay_payment_id

string Unique identifier for the payment returned by Checkout only for successful payments.

razorpay_order_id

string Unique identifier for the order returned by Checkout.

razorpay_signature

string Signature returned by the Checkout. This is used to verify the payment.

1.8 Verify Payment Signature
This is a mandatory step to confirm the authenticity of the details returned to the Checkout form for successful payments.

To verify the razorpay_signature returned to you by the Checkout form:
Create a signature in your server using the following attributes:

order_id: Retrieve the order_id from your server. Do not use the razorpay_order_id returned by Checkout.
razorpay_payment_id: Returned by Checkout.
key_secret: Available in your server. The key_secret that was generated from the Dashboard.
Use the SHA256 algorithm, the razorpay_payment_id and the order_id to construct a HMAC hex digest as shown below:

HMAC Hex Digest

copy

generated_signature = hmac_sha256(order_id + "|" + razorpay_payment_id, secret);

  if (generated_signature == razorpay_signature) {
    payment is successful
  }
If the signature you generate on your server matches the razorpay_signature returned to you by the Checkout form, the payment received is from an authentic source.

Generate Signature on Your Server
Given below is the sample code for payment signature verification:

Java
Python
Go
PHP
Ruby
Node.js
.NET

copy

var instance = new Razorpay({ key_id: 'YOUR_KEY_ID', key_secret: 'YOUR_SECRET' })

var { validatePaymentVerification, validateWebhookSignature } = require('./dist/utils/razorpay-utils');
validatePaymentVerification({"order_id": razorpayOrderId, "payment_id": razorpayPaymentId }, signature, secret);
Post Signature Verification
After you have completed the integration, you can set up webhooks, make test payments, replace the test key with the live key and integrate with other APIs.

M1 MacBook Changes
If you use M1 MacBook, you need to make the following changes in your podfile.

Handy Tips

Add the following code inside post_install do |installer|.

podfile

copy

installer.pods_project.build_configurations.each do |config|
  config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
end

1.9 Verify Payment Status
Handy Tips

On the Razorpay Dashboard, ensure that the payment status is captured. Refer to the payment capture settings page to know how to capture payments automatically.

You can track the payment status using :
-Webhook Events


You can use Razorpay webhooks to configure and receive notifications when a specific event occurs. When one of these events is triggered, we send an HTTP POST payload in JSON to the webhook's configured URL. Know how to set up webhooks.

Example
If you have subscribed to the order.paid webhook event, you will receive a notification every time a customer pays you for an order.

2. Test Integration
After the integration is complete, a Pay button appears on your webpage/app.

Test integration on your webpage/app
Click the button and make a test transaction to ensure the integration is working as expected. You can start accepting actual payments from your customers once the test transaction is successful.

Watch Out!

This is a mock payment page that uses your test API keys, test card and payment details.

Ensure you have entered only your Test Mode API keys in the Checkout code.
Test mode may include OTP verification for certain payment methods to replicate the live payment experience.
No real money is deducted due to the usage of test API keys. This is a simulated transaction.
Following are all the payment modes that the customer can use to complete the payment on the Checkout. Some of them are available by default, while others may require approval from us. Raise a request from the Dashboard to enable such payment methods.

Payment Method	Code	Availability
Debit Card	debit	✓
Credit Card	credit	✓
Netbanking	netbanking	✓
UPI	upi	✓
EMI - Credit Card EMI , Debit Card EMI and No Cost EMI	emi	✓
Wallet	wallet	✓
Cardless EMI	cardless_emi	Requires Approval .
Bank Transfer	bank_transfer	Requires Approval and Integration.
Emandate	emandate	Requires Approval and Integration.
Pay Later	paylater	Requires Approval .
You can make test payments using one of the payment methods configured at the Checkout.

API Classes and Methods
API classes and methods available for the Flutter plugin.

Available in

IN
India

MY
Malaysia

SG
Singapore

Documented below is the API package for the plugin.

Razorpay Class
Method
open(map<String, dynamic> options)

Opens the checkout.

on(String eventName, Function listener)

Registers event listeners for payment events.
eventName: The name of the event.
listener: The function to be called. The listener should accept a single argument of the following type:
PaymentSuccessResponse for EVENT_PAYMENT_SUCCESS.
PaymentFailureResponse for EVENT_PAYMENT_FAILURE.
ExternalWalletResponse for EVENT_EXTERNAL_WALLET.

clear()

Clears all listeners.

Handy Tips

The options map has key as a required property in the open checkout method. All other properties are optional. Know about all the options available on checkout form.

Event Names
The event names have been exposed as strings by the Razorpay class.

Event Name	Description
EVENT_PAYMENT_SUCCESS	The payment was successful.
EVENT_PAYMENT_ERROR	The payment was not successful.
EVENT_EXTERNAL_WALLET	An external wallet was selected.
PaymentSuccessResponse
Field Name	Data Type	Description
paymentId	string	The ID for the payment.
orderId	string	The order ID if the payment was for an order, otherwise null .
signature	string	The signature to be used for payment verification. Only valid for orders, otherwise null .
PaymentFailureResponse
Field Name	Data Type	Description
code	integer	The error code .
message	string	The error message .
ExternalWalletResponse
Field Name	Data Type	Description
walletName	string	The name of the external wallet selected.


Error Codes
The error codes are exposed as integers by the Razorpay class. The error code is available as the code field of the PaymentFailureResponse instance passed to the callback.

Error Code	Description
NETWORK_ERROR	There was a network error. For example, loss of internet connectivity.
INVALID_OPTIONS	An issue with options passed in Razorpay.open .
PAYMENT_CANCELLED	User cancelled the payment.
TLS_ERROR	Device does not support TLS v1.1 or TLS v1.2.
UNKNOWN_ERROR	An unknown error occurred.


