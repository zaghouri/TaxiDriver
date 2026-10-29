// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get notNow => 'Not now';

  @override
  String get retry => 'Try again';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get done => 'Done';

  @override
  String get send => 'Send';

  @override
  String get confirm => 'Confirm';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get loading => 'Loading…';

  @override
  String get openSettings => 'Open settings';

  @override
  String get read => 'Read';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get share => 'Share';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get required => 'Required';

  @override
  String get optional => 'Optional';

  @override
  String priceDh(int amount) {
    return '$amount DH';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String kmShort(String km) {
    return '$km km';
  }

  @override
  String ratingWithCount(int count, String rating) {
    return '$rating ★ ($count)';
  }

  @override
  String tripsCount(int count) {
    return '$count trips';
  }

  @override
  String get newRating => 'New';

  @override
  String get statusLabel => 'Status';

  @override
  String get dateLabel => 'Date';

  @override
  String get noConnectionBanner => 'No internet connection. We keep trying…';

  @override
  String get languageTitle => 'Choose your language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageChangeLater => 'You can change it later in Profile.';

  @override
  String get bootLoading => 'Starting…';

  @override
  String bootOffline(String app) {
    return 'We could not reach $app. Check your internet connection.';
  }

  @override
  String get updateTitle => 'Update needed';

  @override
  String updateBody(String app, String version) {
    return 'This version of $app is too old. Install version $version to continue.';
  }

  @override
  String get updateDownload => 'Download the update';

  @override
  String updateDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get updateInstall => 'Install';

  @override
  String get updateOpenStore => 'Open the store';

  @override
  String updateAllowInstall(String app) {
    return 'Android will ask you to allow installing apps from $app. Allow it, then come back and tap Install.';
  }

  @override
  String get updateFailed =>
      'The download failed. Check your connection and try again.';

  @override
  String get updateAvailable => 'A new version is available.';

  @override
  String get updateNoLink => 'Ask support for the new version.';

  @override
  String welcomeTitle(String app) {
    return 'Welcome to $app';
  }

  @override
  String get welcomeRiderTagline =>
      'You choose the price. Drivers nearby answer.';

  @override
  String get welcomeDriverTagline =>
      'Receive rides near you. Accept the price or propose yours. 0% commission.';

  @override
  String get welcomeSignUp => 'Create an account';

  @override
  String get welcomeLogIn => 'I already have an account';

  @override
  String get welcomeCash => 'Pay in cash, directly to the driver.';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get passwordHint => 'At least 10 characters';

  @override
  String get showPassword => 'Show password';

  @override
  String get errorNameShort => 'Please enter your full name.';

  @override
  String get errorEmailInvalid => 'This email address is not valid.';

  @override
  String get errorPasswordShort => 'Use at least 10 characters.';

  @override
  String get errorPasswordMismatch => 'The two passwords are different.';

  @override
  String get errorCodeFormat => 'Enter the 6 digits.';

  @override
  String get consentsTitle => 'Before you start';

  @override
  String get consentsIntro =>
      'Please read and accept each item. Tap “Read” to see the full text.';

  @override
  String get consentTerms => 'I accept the Terms of use';

  @override
  String get consentPrivacy => 'I accept the Privacy policy';

  @override
  String get consentDataTransfer =>
      'I agree that some of my data is processed by services outside Morocco';

  @override
  String get consentDataTransferExplain =>
      'Google Maps shows the map, Firebase (Google) sends notifications and WhatsApp (Meta) sends your phone code. These companies may store data outside Morocco. Without them the app cannot work.';

  @override
  String consentBackgroundLocation(String app) {
    return 'I agree that $app uses my location in the background while I am online';
  }

  @override
  String get consentBackgroundExplain =>
      'Riders nearby can find you and follow the trip, even when the app is closed. When you go offline, we stop.';

  @override
  String get consentsAllRequired => 'All boxes are needed to use the app.';

  @override
  String get consentsAccept => 'Accept and create my account';

  @override
  String get consentsLoadFailed =>
      'We could not load the texts. Check your connection and try again.';

  @override
  String consentVersion(String version) {
    return 'Version $version';
  }

  @override
  String get consentsOutdated => 'A text was updated. Please read it again.';

  @override
  String get verifyEmailTitle => 'Check your email';

  @override
  String verifyEmailBody(String email) {
    return 'We sent a 6-digit code to $email. Enter it below, or tap the link in the email.';
  }

  @override
  String get verifyEmailSpam => 'Not received? Look in the Spam folder.';

  @override
  String get codeLabel => '6-digit code';

  @override
  String get verifyButton => 'Verify';

  @override
  String get resendCode => 'Send a new code';

  @override
  String resendIn(int seconds) {
    return 'New code in $seconds s';
  }

  @override
  String get codeSent => 'A new code was sent.';

  @override
  String get emailVerified => 'Email verified';

  @override
  String get iVerifiedWithLink => 'I used the link in the email';

  @override
  String get loginTitle => 'Log in';

  @override
  String get loginButton => 'Log in';

  @override
  String get forgotPasswordLink => 'Forgot your password?';

  @override
  String get noAccountLink => 'No account yet? Create one';

  @override
  String wrongAppRider(String app) {
    return 'This is a driver account. Use the $app Driver app.';
  }

  @override
  String get wrongAppDriver =>
      'This is a rider account. Create a driver account with another email.';

  @override
  String get twoFactorTitle => 'Security code';

  @override
  String get twoFactorEmailBody =>
      'We sent a code to your email. Enter it below.';

  @override
  String twoFactorTotpBody(String app) {
    return 'Open your authenticator app and enter the 6-digit code for $app.';
  }

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotBody =>
      'Enter your email. If an account exists, we will send you a code.';

  @override
  String get forgotSend => 'Send the code';

  @override
  String get resetTitle => 'Choose a new password';

  @override
  String resetBody(String email) {
    return 'Enter the code sent to $email and your new password.';
  }

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get resetDone => 'Your password was changed. You can log in now.';

  @override
  String get resetButton => 'Change password';

  @override
  String get verifyPhoneTitle => 'Verify your phone';

  @override
  String get verifyPhoneBody =>
      'We will send a code on WhatsApp to this number.';

  @override
  String get verifyPhoneWhyRider =>
      'We need a verified number before your first ride.';

  @override
  String get verifyPhoneWhyDriver =>
      'We need a verified number before you go online.';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHint => '6XXXXXXXX';

  @override
  String get errorPhoneInvalid =>
      'Enter the 9 digits after +212 (for example 612345678).';

  @override
  String get phoneCodesLimit =>
      'You can ask for up to 3 codes per day for the same number. Each code works for 10 minutes. The number must have WhatsApp.';

  @override
  String get sendCodeWhatsapp => 'Send the code on WhatsApp';

  @override
  String phoneCodeSentTo(String phone) {
    return 'Code sent on WhatsApp to $phone.';
  }

  @override
  String get changeNumber => 'Change number';

  @override
  String get phoneVerified => 'Phone verified';

  @override
  String get phonePrivacy =>
      'Your number stays private: calls go through the app.';

  @override
  String get phoneChangeHint =>
      'To change a verified number, send a correction request from Profile › My data.';

  @override
  String get locationTitle => 'Your location';

  @override
  String get locationRiderBody =>
      'We use your location while the app is open to set your pickup point.';

  @override
  String get locationRiderDetail =>
      'Your driver sees your pickup point only during a ride. You can also type your address instead.';

  @override
  String locationDriverBody(String app) {
    return '$app uses your location even when the app is closed or not in use while you are online, so riders nearby can find you and follow the trip.';
  }

  @override
  String get locationDriverDetail =>
      'When you go offline, we stop using your location. On the next screen choose “Allow all the time”.';

  @override
  String get locationDeniedRider =>
      'Location is off. You can type your pickup address.';

  @override
  String get locationNeededDriver => 'Location is needed to go online';

  @override
  String locationNeededDriverBody(String app) {
    return 'In Settings, set Location to “Allow all the time” for $app.';
  }

  @override
  String get locationServiceOff => 'Your phone’s location (GPS) is turned off.';

  @override
  String get turnOnLocation => 'Turn on location';

  @override
  String get allowLocation => 'Allow location';

  @override
  String get notifTitle => 'Stay informed';

  @override
  String get notifRiderBody =>
      'We notify you when a driver makes an offer, arrives, or when your ride changes.';

  @override
  String get notifDriverBody =>
      'We notify you when a new ride request arrives near you, even when the app is in the background.';

  @override
  String get notifAllow => 'Allow notifications';

  @override
  String get notifDeniedBanner =>
      'Notifications are off. You may miss ride offers.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileName => 'Name';

  @override
  String get profileEmail => 'Email';

  @override
  String get profilePhone => 'Phone';

  @override
  String get phoneNotVerified => 'Not verified';

  @override
  String get phoneVerifiedBadge => 'Verified';

  @override
  String get verifyNow => 'Verify now';

  @override
  String get profileSecurity => 'Two-step login';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileMyData => 'My data';

  @override
  String get profileDeleteAccount => 'Delete my account';

  @override
  String get profileLegal => 'Legal information';

  @override
  String get profileTrips => 'My trips';

  @override
  String profileAppVersion(String version) {
    return 'App version $version';
  }

  @override
  String get profileRating => 'Your rating';

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirm => 'Do you want to log out?';

  @override
  String get editName => 'Change your name';

  @override
  String get saved => 'Saved';

  @override
  String get sessionEnded => 'Your session ended. Please log in again.';

  @override
  String get twoFactorSettingsTitle => 'Two-step login';

  @override
  String get twoFactorExplain =>
      'After your password, we ask for a second code. Even if someone knows your password, they cannot log in.';

  @override
  String get twoFactorOff => 'Off';

  @override
  String get twoFactorEmail => 'Code by email';

  @override
  String get twoFactorTotp => 'Authenticator app';

  @override
  String twoFactorCurrent(String method) {
    return 'Current: $method';
  }

  @override
  String get twoFactorUseEmail => 'Use email codes';

  @override
  String get twoFactorUseTotp => 'Use an authenticator app';

  @override
  String get twoFactorTurnOff => 'Turn off two-step login';

  @override
  String get twoFactorTotpStep1 =>
      '1. Add this key in your authenticator app (Google Authenticator, Microsoft Authenticator…).';

  @override
  String get twoFactorSecret => 'Secret key';

  @override
  String get twoFactorOpenApp => 'Open in my authenticator app';

  @override
  String get twoFactorTotpStep2 =>
      '2. Enter the 6-digit code shown in the app.';

  @override
  String get twoFactorEnabled => 'Two-step login is on.';

  @override
  String get twoFactorDisabled => 'Two-step login is off.';

  @override
  String get passwordConfirmPrompt => 'Enter your password to confirm.';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get passwordChanged => 'Password changed.';

  @override
  String get myDataTitle => 'My data';

  @override
  String get myDataIntro =>
      'Under Moroccan law 09-08 you can get a copy of your personal data and ask us to correct it.';

  @override
  String get downloadMyData => 'Download my data';

  @override
  String get myDataReady => 'Your data file is ready.';

  @override
  String get dataRequestsTitle => 'My requests';

  @override
  String get dataRequestsEmpty => 'No requests yet.';

  @override
  String get newDataRequest => 'New request';

  @override
  String get dataRequestAccess => 'Access to my data';

  @override
  String get dataRequestCorrection => 'Correct my data';

  @override
  String get dataRequestDeletion => 'Delete my data';

  @override
  String get dataRequestDetails => 'Explain your request';

  @override
  String get dataRequestDetailsHint =>
      'For example: my name is spelled wrong, the right spelling is…';

  @override
  String get dataRequestSent => 'Request sent. We answer within 30 days.';

  @override
  String get dataRequestOpen => 'Pending';

  @override
  String get dataRequestDone => 'Done';

  @override
  String get dataRequestRejected => 'Rejected';

  @override
  String dataRequestResponse(String text) {
    return 'Answer: $text';
  }

  @override
  String get deleteTitle => 'Delete my account';

  @override
  String get deleteIntro =>
      'Your account is deleted right away. This cannot be undone.';

  @override
  String get deleteWhatGoes =>
      'Deleted now: your name, email, phone number, password, devices, documents, trip addresses and GPS points.';

  @override
  String get deleteWhatStays =>
      'Kept without your name, for the period required by law: trip records (date, price) so receipts and disputes stay valid.';

  @override
  String get deleteConfirmCheck => 'I understand that this cannot be undone';

  @override
  String get deleteButton => 'Delete my account';

  @override
  String get deleteDone => 'Your account was deleted.';

  @override
  String get legalTitle => 'Legal information';

  @override
  String get legalTerms => 'Terms of use';

  @override
  String get legalPrivacy => 'Privacy policy';

  @override
  String get legalDataTransfer => 'Data transfer outside Morocco';

  @override
  String get legalBackgroundLocation => 'Background location';

  @override
  String get companyTitle => 'Company';

  @override
  String get companyName => 'Name';

  @override
  String get companyRc => 'RC';

  @override
  String get companyIce => 'ICE';

  @override
  String get companyAddress => 'Address';

  @override
  String get supportPhone => 'Support phone';

  @override
  String get supportEmail => 'Support email';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String receiptNumber(String number) {
    return 'Receipt no. $number';
  }

  @override
  String get receiptFrom => 'From';

  @override
  String get receiptTo => 'To';

  @override
  String get receiptDistance => 'Distance';

  @override
  String get receiptDuration => 'Duration';

  @override
  String get receiptPrice => 'Price';

  @override
  String get receiptDriver => 'Driver';

  @override
  String get receiptRider => 'Rider';

  @override
  String get receiptVehicle => 'Vehicle';

  @override
  String get receiptPaidCash => 'Paid in cash to the driver';

  @override
  String receiptNoCommission(String app) {
    return '$app takes no commission and does not collect trip payments.';
  }

  @override
  String get receiptShare => 'Share receipt';

  @override
  String get tripHistoryTitle => 'My trips';

  @override
  String get tripHistoryEmpty => 'No trips yet.';

  @override
  String get loadMore => 'Show more';

  @override
  String get rideStatusSearching => 'Looking for a driver';

  @override
  String get rideStatusAccepted => 'Driver on the way';

  @override
  String get rideStatusArrived => 'Driver arrived';

  @override
  String get rideStatusInProgress => 'On trip';

  @override
  String get rideStatusCompleted => 'Completed';

  @override
  String get rideStatusCancelled => 'Cancelled';

  @override
  String get rideStatusExpired => 'No driver found';

  @override
  String get homeFrom => 'From';

  @override
  String get homeTo => 'To';

  @override
  String get homeCurrentLocation => 'My current location';

  @override
  String get homeWhereTo => 'Where are you going?';

  @override
  String get homeSearchAddress => 'Search an address';

  @override
  String get homePickOnMap => 'Choose on the map';

  @override
  String get offerYourFare => 'Offer your fare';

  @override
  String suggestedPrice(int amount) {
    return 'Suggested: $amount DH';
  }

  @override
  String minOffer(int amount) {
    return 'Minimum: $amount DH';
  }

  @override
  String get commentForDriver => 'Comment for the driver (optional)';

  @override
  String get commentHint => 'For example: I have a big suitcase';

  @override
  String get findDriver => 'Find a driver';

  @override
  String tripEstimate(String km, int minutes) {
    return '$km km · about $minutes min';
  }

  @override
  String get searchingTitle => 'Looking for drivers…';

  @override
  String searchingTimeLeft(String time) {
    return '$time left';
  }

  @override
  String get raiseFare => 'Raise fare';

  @override
  String get raiseFareTitle => 'Raise your fare';

  @override
  String get raiseFareHint =>
      'A higher fare gets more answers. You cannot lower it.';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get cancelRequestConfirm => 'Cancel your request?';

  @override
  String get offersTitle => 'Offers';

  @override
  String get offerCounter => 'Counter-offer';

  @override
  String offerEta(int minutes) {
    return '$minutes min away';
  }

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get noOffersYet =>
      'Waiting for offers. Drivers nearby can see your request.';

  @override
  String get requestExpiredTitle => 'No driver accepted';

  @override
  String get requestExpiredBody => 'Try again with a higher fare.';

  @override
  String get offerNoLongerAvailable => 'This offer is no longer available.';

  @override
  String get driverOnTheWay => 'Your driver is on the way';

  @override
  String get driverArrivedTitle => 'Your driver is here';

  @override
  String get onTripTitle => 'On the way to your destination';

  @override
  String etaMinutes(int minutes) {
    return 'Arrives in $minutes min';
  }

  @override
  String get pickupPin => 'Pickup PIN';

  @override
  String get pickupPinHint => 'Give this code to the driver to start the trip.';

  @override
  String get callButton => 'Call';

  @override
  String get shareTrip => 'Share trip';

  @override
  String get sosButton => 'SOS';

  @override
  String get cancelRide => 'Cancel';

  @override
  String get cancelFreeInfo =>
      'You can cancel for free until the driver arrives.';

  @override
  String get cancelCountedWarning =>
      'The driver has arrived. If you cancel now, it will be counted.';

  @override
  String get cancelReasonTitle => 'Why do you cancel?';

  @override
  String get reasonChangedMind => 'I changed my mind';

  @override
  String get reasonDriverTooFar => 'The driver is too far';

  @override
  String get reasonDriverAsked => 'The driver asked me to cancel';

  @override
  String get reasonWrongPickup => 'Wrong pickup point';

  @override
  String get reasonRiderNoShow => 'The rider did not come';

  @override
  String get reasonCarMismatch => 'The car does not match';

  @override
  String get reasonSafety => 'I do not feel safe';

  @override
  String get reasonOther => 'Other reason';

  @override
  String get carMismatch => 'Car doesn’t match?';

  @override
  String get carMismatchBody =>
      'If the plate or the car is different, do not get in. Report it: you can then cancel for free.';

  @override
  String get reportSent => 'Thank you, our team was alerted.';

  @override
  String get cancelWarningRecent =>
      'You cancelled several rides recently. Please book only when you are ready.';

  @override
  String get rideCancelledByDriver =>
      'The driver cancelled. You can request again.';

  @override
  String get rideCancelledByRider => 'The rider cancelled the ride.';

  @override
  String get rateDriver => 'How was your driver?';

  @override
  String get rateRider => 'How was the rider?';

  @override
  String get rateComment => 'Comment (optional)';

  @override
  String get rateSubmit => 'Send rating';

  @override
  String get rateSkip => 'Skip';

  @override
  String fareToPay(int amount) {
    return 'Fare: $amount DH. Pay cash to the driver.';
  }

  @override
  String get thanksRating => 'Thank you!';

  @override
  String get idCheckRequiredBody =>
      'For safety, we need a photo of your ID card before your next ride.';

  @override
  String get shareTitle => 'Share your trip';

  @override
  String get shareBody =>
      'Add up to 5 contacts. They get a link to follow your trip live until 1 hour after it ends.';

  @override
  String get contactName => 'Name';

  @override
  String get contactPhone => 'Phone';

  @override
  String get addContact => 'Add a contact';

  @override
  String get shareCreate => 'Create the link and share';

  @override
  String shareMessage(String app, String url) {
    return 'Follow my $app trip live: $url';
  }

  @override
  String get shareMaxContacts => 'You can add up to 5 contacts.';

  @override
  String get sosTitle => 'Emergency';

  @override
  String sosBody(String app) {
    return 'Tap a service: your phone calls it and the $app team gets your live location.';
  }

  @override
  String get sosPolice => 'Police';

  @override
  String get sosGendarmerie => 'Gendarmerie';

  @override
  String get sosAmbulance => 'Ambulance';

  @override
  String get sosAlertSent => 'Alert sent. Our team sees your location.';

  @override
  String get sosAlertFailed =>
      'We could not send the alert. Call the number directly.';

  @override
  String get sosSharingLocation =>
      'Your location is shared every 10 seconds while this screen is open.';

  @override
  String get sosSending => 'Sending the alert…';

  @override
  String get callCalling => 'Calling…';

  @override
  String get callRinging => 'Ringing…';

  @override
  String get callIncoming => 'Incoming call';

  @override
  String get callConnecting => 'Connecting…';

  @override
  String get callActive => 'In call';

  @override
  String get callEnded => 'Call ended';

  @override
  String get callRejected => 'Call declined';

  @override
  String get callFailed => 'The call could not connect.';

  @override
  String get callMute => 'Mute';

  @override
  String get callUnmute => 'Unmute';

  @override
  String get callSpeaker => 'Speaker';

  @override
  String get callHangUp => 'Hang up';

  @override
  String get callAnswer => 'Answer';

  @override
  String get callDecline => 'Decline';

  @override
  String get callMicDenied => 'Allow the microphone to make calls.';

  @override
  String get callPrivacy => 'Your phone number is not shared.';

  @override
  String get callYourDriver => 'Your driver';

  @override
  String get callYourRider => 'Your rider';

  @override
  String get plateLabel => 'Plate';

  @override
  String get carLabel => 'Car';

  @override
  String get colourLabel => 'Colour';

  @override
  String get goOnline => 'Go online';

  @override
  String get goOffline => 'Go offline';

  @override
  String get onlineLabel => 'Online';

  @override
  String get offlineLabel => 'Offline';

  @override
  String onlineNotificationTitle(String app) {
    return '$app — you are online';
  }

  @override
  String get onlineNotificationBody => 'You receive ride requests near you.';

  @override
  String get offlineHint => 'Go online to receive ride requests.';

  @override
  String get requestsTitle => 'Ride requests';

  @override
  String get noRequests => 'No requests right now. Stay online.';

  @override
  String pickupDistance(String km, int minutes) {
    return '$km km to pickup · $minutes min';
  }

  @override
  String tripDistance(String km) {
    return 'Trip: $km km';
  }

  @override
  String get pickupLabel => 'Pickup';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get riderLabel => 'Rider';

  @override
  String get riderComment => 'Rider’s comment';

  @override
  String acceptFor(int amount) {
    return 'Accept for $amount DH';
  }

  @override
  String get proposePrice => 'Or propose your price';

  @override
  String counterPlus(int amount) {
    return '+$amount DH';
  }

  @override
  String get otherAmount => 'Other amount';

  @override
  String counterOfferFor(int amount) {
    return 'Propose $amount DH';
  }

  @override
  String counterMax(int amount) {
    return 'Maximum $amount DH';
  }

  @override
  String waitingForRider(String time) {
    return 'Waiting for the rider… $time';
  }

  @override
  String get withdraw => 'Withdraw my offer';

  @override
  String get bidAccepted => 'The rider accepted your offer!';

  @override
  String get bidLost => 'The rider chose another driver.';

  @override
  String get bidDeclined => 'The rider declined your offer.';

  @override
  String get bidExpired => 'Your offer expired.';

  @override
  String get bidOutdated => 'The rider raised the fare. Make a new offer.';

  @override
  String get requestClosedTaken => 'Another driver took this ride.';

  @override
  String get requestClosedGone => 'This request is no longer available.';

  @override
  String get navigate => 'Navigate';

  @override
  String get goingToPickup => 'Go to the pickup point';

  @override
  String get iveArrived => 'I’ve arrived';

  @override
  String get enterPinTitle => 'Enter the rider’s PIN';

  @override
  String get enterPinHint =>
      'Ask the rider for the 4-digit code shown in their app.';

  @override
  String get startTrip => 'Start the trip';

  @override
  String get riderNoShow => 'Rider didn’t come';

  @override
  String get riderNoShowInfo =>
      'After 5 minutes of waiting you can cancel without penalty.';

  @override
  String waitTime(String time) {
    return 'Waiting: $time';
  }

  @override
  String get completeTrip => 'Complete the trip';

  @override
  String collectCash(int amount) {
    return 'Collect $amount DH in cash';
  }

  @override
  String get driverCancelWarning =>
      'If you cancel now, you get a penalty point. Too many cancellations block you for a while.';

  @override
  String blockedUntil(String time) {
    return 'You are paused until $time because of cancellations.';
  }

  @override
  String adminMessageTitle(String app) {
    return 'Message from $app';
  }

  @override
  String get earningsTitle => 'Earnings';

  @override
  String get earningsToday => 'Today';

  @override
  String get earningsWeek => 'Last 7 days';

  @override
  String earningsTrips(int count) {
    return '$count trips';
  }

  @override
  String earningsCash(int amount) {
    return '$amount DH in cash';
  }

  @override
  String get earningsNoCommission =>
      '0% commission: everything you collect is yours.';

  @override
  String get documentsTitle => 'My documents';

  @override
  String get docCinFront => 'ID card (front)';

  @override
  String get docCinBack => 'ID card (back)';

  @override
  String get docLicence => 'Driving licence';

  @override
  String get docCarteGrise => 'Registration (carte grise)';

  @override
  String get docInsurance => 'Insurance';

  @override
  String get docVisiteTechnique => 'Technical inspection';

  @override
  String get docSelfie => 'Selfie';

  @override
  String get docStatusPending => 'Under review';

  @override
  String get docStatusApproved => 'Approved';

  @override
  String get docStatusRejected => 'Rejected';

  @override
  String get docStatusExpired => 'Expired';

  @override
  String get docStatusMissing => 'Missing';

  @override
  String docExpiresOn(String date) {
    return 'Expires on $date';
  }

  @override
  String docExpiringSoon(int days, String doc) {
    return '$doc expires in $days days. Upload the new one now.';
  }

  @override
  String get docExpiredBlocked =>
      'A document has expired. You cannot go online until you upload a valid one.';

  @override
  String get docUpload => 'Upload';

  @override
  String get docReupload => 'Upload again';

  @override
  String get docExpiryDate => 'Expiry date';

  @override
  String docRejectReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get docTakePhoto => 'Take a photo';

  @override
  String get docChooseFile => 'Choose a file';

  @override
  String get docPhotoTips =>
      'Put the document on a table, in good light. All 4 corners must be visible and the text readable.';

  @override
  String get docUploaded => 'Document sent for review.';

  @override
  String get onboardingTitle => 'Become a driver';

  @override
  String onboardingStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get driverTypeTitle => 'Type of driver';

  @override
  String get driverTypeTaxi => 'Taxi';

  @override
  String get driverTypeLicensedOperator => 'Licensed operator (VTC)';

  @override
  String get driverTypePrivateCar => 'Private car';

  @override
  String get personalInfoTitle => 'About you';

  @override
  String get cinLast4Label => 'Last 4 characters of your ID card (CIN)';

  @override
  String get cinLast4Hint =>
      'We keep only these characters, not the full number.';

  @override
  String get licenceIssuedLabel => 'Driving licence issue date';

  @override
  String get vehicleTitle => 'Your car';

  @override
  String get vehicleMake => 'Make';

  @override
  String get vehicleModel => 'Model';

  @override
  String get vehicleYear => 'Year';

  @override
  String get vehicleColour => 'Colour';

  @override
  String get vehiclePlate => 'Plate number';

  @override
  String get vehicleDoors => 'Number of doors';

  @override
  String get vehicleAc => 'Air conditioning';

  @override
  String errorCarTooOld(int year) {
    return 'The car must be from $year or newer.';
  }

  @override
  String get errorCarDoors => 'The car must have 4 doors.';

  @override
  String get errorCarNoAc => 'The car must have air conditioning.';

  @override
  String get errorLicenceRecent => 'Your licence must be at least 3 years old.';

  @override
  String get documentsStepTitle => 'Your documents';

  @override
  String get submitForReview => 'Submit for review';

  @override
  String get underReviewTitle => 'Under review';

  @override
  String get underReviewBody =>
      'We are checking your documents. We will notify you, usually within 1 to 2 working days.';

  @override
  String get rejectedTitle => 'Application not accepted';

  @override
  String rejectedBody(String reason) {
    return 'Reason: $reason. Fix it and submit again.';
  }

  @override
  String get suspendedTitle => 'Account paused';

  @override
  String get suspendedBody =>
      'Your driver account is paused. Contact support to know more.';

  @override
  String get approvedTitle => 'You are approved!';

  @override
  String batteryTitle(String app) {
    return 'Keep $app running';
  }

  @override
  String get batteryIntro =>
      'Some phones close apps in the background to save battery. Follow these steps once so you do not miss ride requests while online.';

  @override
  String get batteryChooseBrand => 'Choose your phone brand';

  @override
  String get batteryOther => 'Other brand';

  @override
  String batteryOpenSettings(String app) {
    return 'Open $app settings';
  }

  @override
  String get batteryNamesDiffer =>
      'Names can change a little between phone versions. Look for the closest one.';

  @override
  String get batteryDone => 'I did it';

  @override
  String batteryXiaomi1(String app) {
    return 'Long-press the $app icon, then tap “App info” (ⓘ).';
  }

  @override
  String get batteryXiaomi2 =>
      'Tap “Battery saver” and choose “No restrictions”.';

  @override
  String get batteryXiaomi3 => 'Turn on “Autostart”.';

  @override
  String get batteryXiaomi4 =>
      'Tap “Other permissions” and allow “Start in background” and “Show on lock screen”.';

  @override
  String get batteryXiaomi5 =>
      'Tap “Permissions” › “Location” › “Allow all the time”.';

  @override
  String batteryXiaomi6(String app) {
    return 'Open recent apps, long-press the $app card and tap the lock icon.';
  }

  @override
  String batteryTecno1(String app) {
    return 'Long-press the $app icon, then tap “App info”.';
  }

  @override
  String get batteryTecno2 =>
      'Tap “Battery” and choose “No restriction” (or turn on “Allow background activity”).';

  @override
  String batteryTecno3(String app) {
    return 'In Settings › App management › “Auto-start”, turn $app on.';
  }

  @override
  String batteryTecno4(String app) {
    return 'Open “Phone Master” › “Power saving” and remove $app from the apps that are closed automatically.';
  }

  @override
  String get batteryTecno5 =>
      'Tap “Permissions” › “Location” › “Allow all the time”.';

  @override
  String batteryTecno6(String app) {
    return 'Open recent apps and pull the $app card down (or tap the lock) to lock it.';
  }

  @override
  String get batteryInfinix1 =>
      'Open Settings › “Battery” › “App launch” (or “Auto-start management”).';

  @override
  String batteryInfinix2(String app) {
    return 'Find $app, choose “Manage manually” and turn on “Auto-launch”, “Secondary launch” and “Run in background”.';
  }

  @override
  String batteryInfinix3(String app) {
    return 'Long-press the $app icon › “App info” › “Battery” › “Allow background activity”.';
  }

  @override
  String batteryInfinix4(String app) {
    return 'In “Phone Master”, turn off auto-clean for $app.';
  }

  @override
  String get batteryInfinix5 =>
      'In “Permissions” › “Location”, choose “Allow all the time”.';

  @override
  String batteryInfinix6(String app) {
    return 'Open recent apps and lock the $app card.';
  }

  @override
  String batteryOppo1(String app) {
    return 'Long-press the $app icon, then tap “App info”.';
  }

  @override
  String get batteryOppo2 =>
      'Tap “Battery usage” and turn on “Allow background activity”, “Allow foreground activity” and “Allow auto launch”.';

  @override
  String batteryOppo3(String app) {
    return 'On older phones: Settings › “Battery” › “More settings” › “Optimise battery use” › $app › “Don’t optimise”.';
  }

  @override
  String get batteryOppo4 =>
      'Tap “Permissions” › “Location” › “Allow all the time”.';

  @override
  String batteryOppo5(String app) {
    return 'Open recent apps, tap the ⋮ menu on the $app card and choose “Lock”.';
  }

  @override
  String batterySamsung1(String app) {
    return 'Long-press the $app icon, then tap “App info”.';
  }

  @override
  String get batterySamsung2 => 'Tap “Battery” and choose “Unrestricted”.';

  @override
  String get batterySamsung3 =>
      'Go to Settings › “Battery” (or “Device care” › “Battery”) › “Background usage limits”.';

  @override
  String batterySamsung4(String app) {
    return 'Make sure $app is not in “Sleeping apps” or “Deep sleeping apps”, and add it to “Never sleeping apps”.';
  }

  @override
  String get batterySamsung5 =>
      'In App info › “Permissions” › “Location”, choose “Allow all the time”.';

  @override
  String batteryGeneric1(String app) {
    return 'Open Settings › “Apps” › $app (or long-press the icon › “App info”).';
  }

  @override
  String get batteryGeneric2 =>
      'In “Battery”, choose “Unrestricted” or “Don’t optimise”, or allow background activity.';

  @override
  String batteryGeneric3(String app) {
    return 'If you see “Auto-start” or “Launch at startup”, turn it on for $app.';
  }

  @override
  String get batteryGeneric4 =>
      'In “Permissions” › “Location”, choose “Allow all the time”.';

  @override
  String batteryGeneric5(String app) {
    return 'While online, do not swipe $app away from recent apps.';
  }

  @override
  String get subscriptionTitle => 'Subscription';

  @override
  String subscriptionPrice(int amount, int days) {
    return '$amount DH for $days days';
  }

  @override
  String subscriptionFreeRides(int count) {
    return '$count free rides per day';
  }

  @override
  String subscriptionRidesToday(int count, int limit) {
    return 'Rides today: $count / $limit';
  }

  @override
  String get subscriptionActive => 'Your subscription is active.';

  @override
  String get subscriptionInactive => 'No active subscription.';

  @override
  String get subscriptionPayWith => 'Pay with';

  @override
  String get payCashplus => 'Cash at CashPlus';

  @override
  String get payWafacash => 'Cash at Wafacash';

  @override
  String get payCard => 'Bank card';

  @override
  String get payWallet => 'Mobile wallet';

  @override
  String get payUnavailable => 'Not available yet';

  @override
  String subscriptionCashCode(
    String agent,
    int amount,
    String code,
    int hours,
  ) {
    return 'Go to a $agent agency and give this code: $code. Amount: $amount DH. Valid for $hours hours.';
  }

  @override
  String get subscriptionPending => 'Payment pending';

  @override
  String get subscriptionOpenPayment => 'Open the payment page';

  @override
  String get subscriptionOff =>
      'Subscriptions are not needed for now. All rides are free.';

  @override
  String get deviceMockTitle => 'Turn off fake GPS';

  @override
  String get deviceMockBody =>
      'An app that fakes your location is active. Turn it off in Developer options, then try again.';

  @override
  String get deviceRootedTitle => 'This phone cannot be used to drive';

  @override
  String get deviceRootedBody =>
      'This phone has been modified (rooted). For everyone’s safety, please use another phone.';

  @override
  String get deviceCheckAgain => 'Check again';

  @override
  String get errNetworkError =>
      'No internet connection. Check your network and try again.';

  @override
  String get errTimeout => 'The server is taking too long. Try again.';

  @override
  String get errInternal =>
      'Something went wrong on our side. Try again in a moment.';

  @override
  String get errRateLimited =>
      'Too many attempts. Wait a little and try again.';

  @override
  String get errValidationError => 'Some information is missing or not valid.';

  @override
  String get errUpgradeRequired => 'Please update the app to continue.';

  @override
  String get errAuthRequired => 'Please log in.';

  @override
  String get errTokenInvalid => 'Your session expired. Please log in again.';

  @override
  String get errSessionExpired => 'Your session expired. Please log in again.';

  @override
  String get errRefreshInvalid => 'Your session ended. Please log in again.';

  @override
  String get errRefreshReused =>
      'For your safety we logged you out. Please log in again.';

  @override
  String get errSessionRevoked => 'Your session ended. Please log in again.';

  @override
  String get errAccountDisabled =>
      'This account is suspended. Contact support.';

  @override
  String get errWrongRole => 'This account cannot be used in this app.';

  @override
  String get errInvalidCredentials => 'Wrong email or password.';

  @override
  String get errEmailNotVerified => 'Please verify your email first.';

  @override
  String get errEmailTaken =>
      'An account already uses this email. Log in or reset your password.';

  @override
  String get errLoginLocked =>
      'Too many attempts. Try again in 15 minutes or reset your password.';

  @override
  String get errMfaCodeInvalid => 'Wrong code. Check it and try again.';

  @override
  String get errMfaLocked => 'Too many wrong codes. Try again in 15 minutes.';

  @override
  String get errMfaTokenInvalid => 'This step expired. Please log in again.';

  @override
  String get errCodeInvalid => 'Wrong code. Check it and try again.';

  @override
  String get errCodeExpired => 'This code expired. Ask for a new one.';

  @override
  String get errCodeTooManyAttempts =>
      'Too many wrong tries. Ask for a new code.';

  @override
  String get errResendTooSoon => 'Wait a minute before asking for a new code.';

  @override
  String get errLinkInvalid =>
      'This link expired. Ask for a new code in the app.';

  @override
  String get errConsentRequired => 'Please accept all the required items.';

  @override
  String get errConsentOutdated => 'A text was updated. Please read it again.';

  @override
  String get errPhoneAlreadyVerified =>
      'Your phone is already verified. To change it, send a correction request from Profile › My data.';

  @override
  String get errPhoneInUse => 'This number is already used by another account.';

  @override
  String get errPhoneCodeLimit =>
      'You reached 3 codes today for this number. Try again tomorrow.';

  @override
  String get errOtpSendFailed =>
      'We could not send the WhatsApp code. Check that the number has WhatsApp and try again.';

  @override
  String get errPhoneNotVerified => 'Please verify your phone number first.';

  @override
  String get errIdCheckRequired =>
      'We need a photo of your ID card before your next ride.';

  @override
  String get errOfferTooLow => 'Your fare is too low for this trip.';

  @override
  String get errOfferTooHigh => 'Your fare is too high for this trip.';

  @override
  String get errOfferNotHigher =>
      'The new fare must be higher than the current one.';

  @override
  String get errRideAlreadyActive => 'You already have a ride in progress.';

  @override
  String get errOutOfServiceArea =>
      'This place is outside our service area for now.';

  @override
  String get errTripTooLong => 'This trip is too long for the app.';

  @override
  String get errBidNotAvailable => 'This offer is no longer available.';

  @override
  String get errRideNotSearching =>
      'This ride is no longer looking for a driver.';

  @override
  String get errDriverBusy =>
      'This driver just took another ride. Choose another offer.';

  @override
  String get errCannotCancel => 'This ride cannot be cancelled now.';

  @override
  String get errNoShowTooEarly =>
      'You can use “Rider didn’t come” after 5 minutes of waiting.';

  @override
  String get errRideNotActive => 'This ride is not active any more.';

  @override
  String get errRideNotFound => 'Ride not found.';

  @override
  String get errRideNotCompleted => 'A receipt is available after the trip.';

  @override
  String get errAlreadyRated => 'You already rated this trip.';

  @override
  String get errRatingWindowClosed => 'It is too late to rate this trip.';

  @override
  String get errBidAlreadyActive => 'You already made an offer on this ride.';

  @override
  String get errBidDeclinedBefore =>
      'The rider declined your offer on this ride.';

  @override
  String get errTooManyBids => 'You made too many offers on this ride.';

  @override
  String get errCounterTooLow =>
      'Your price must be higher than the rider’s offer.';

  @override
  String get errCounterTooHigh => 'Your price is too high for this trip.';

  @override
  String get errTooFar => 'You are too far from the pickup point.';

  @override
  String get errSubscriptionRequired =>
      'You reached the free rides for today. Subscribe to continue.';

  @override
  String get errDriverNotApproved => 'Your driver account is not approved yet.';

  @override
  String get errDriverBlocked =>
      'You are paused for a while because of cancellations.';

  @override
  String get errDriverOffline => 'Go online first.';

  @override
  String get errDocumentsInvalid =>
      'A document is missing, expired or not approved yet.';

  @override
  String get errDocumentsMissing => 'Some documents are missing.';

  @override
  String get errDocumentExpired => 'This document has expired.';

  @override
  String get errProfileIncomplete => 'Please complete your information first.';

  @override
  String get errVehicleMissing => 'Please add your car first.';

  @override
  String get errProfileLocked =>
      'Your profile is under review and cannot be changed now.';

  @override
  String get errAlreadySubmitted => 'Your application was already sent.';

  @override
  String get errDriverTypeDisabled =>
      'This type of driver is not open in your city yet.';

  @override
  String get errLicenceTooRecent =>
      'Your licence must be at least 3 years old.';

  @override
  String get errCarTooOld => 'The car is too old.';

  @override
  String get errCarDoors => 'The car must have 4 doors.';

  @override
  String get errCarNoAc => 'The car must have air conditioning.';

  @override
  String get errExpiryRequired => 'Please enter the expiry date.';

  @override
  String get errFileType => 'Send a photo (JPEG, PNG) or a PDF.';

  @override
  String get errFileRequired => 'Please choose a file.';

  @override
  String get errMockLocation => 'Turn off fake GPS to continue.';

  @override
  String get errRootedDevice => 'This phone cannot be used to drive.';

  @override
  String get errIntegrityFailed =>
      'We could not check this phone. Use the app from the official store or our website.';

  @override
  String get errSelfieRequired => 'Please take a selfie before going online.';

  @override
  String get errPinInvalid => 'Wrong PIN. Ask the rider again.';

  @override
  String get errPinLocked => 'Too many wrong PINs. Our team was alerted.';

  @override
  String get errActiveRide => 'Finish or cancel your current ride first.';

  @override
  String get errFeatureDisabled => 'This feature is turned off for now.';

  @override
  String get errSosNotFound => 'This alert is closed.';

  @override
  String get errShareNotFound => 'This link expired.';

  @override
  String get errTooManyPending =>
      'You already have pending requests. Wait for the answer.';

  @override
  String get errRequestInProgress =>
      'Still working on it. Try again in a moment.';

  @override
  String get errIdempotencyKeyReused => 'Something went wrong. Try again.';

  @override
  String get errNotFound => 'Not found.';

  @override
  String get errCityInactive => 'The service is not open in this city yet.';

  @override
  String get errNotADriver => 'This is not a driver account.';

  @override
  String get checkedByRideMA => 'Documents checked by RideMA';

  @override
  String get checkIdentity => 'Identity';

  @override
  String get checkCar => 'Car papers';

  @override
  String get rateGoodTitle => 'What went well?';

  @override
  String get rateBadTitle => 'What went wrong?';

  @override
  String get rateReasonsPrivate =>
      'Optional. The other person never sees your choices; our team uses them to improve rides.';

  @override
  String get rrDriverSafeDriving => 'Safe driving';

  @override
  String get rrDriverPolite => 'Polite and friendly';

  @override
  String get rrDriverCleanCar => 'Clean car';

  @override
  String get rrDriverKnewTheWay => 'Knew the way';

  @override
  String get rrDriverOnTime => 'On time';

  @override
  String get rrDriverUnsafeDriving => 'Unsafe driving';

  @override
  String get rrDriverRude => 'Rude';

  @override
  String get rrDriverDirtyCar => 'Dirty car';

  @override
  String get rrDriverWrongRoute => 'Long or wrong route';

  @override
  String get rrDriverLate => 'Arrived late';

  @override
  String get rrDriverAskedMoreMoney => 'Asked for more money';

  @override
  String get rrDriverCarMismatch => 'Different car or plate';

  @override
  String get rrRiderPolite => 'Polite and friendly';

  @override
  String get rrRiderOnTime => 'Ready on time';

  @override
  String get rrRiderExactPickup => 'Easy to find';

  @override
  String get rrRiderRespectful => 'Respected the car';

  @override
  String get rrRiderLate => 'Kept me waiting';

  @override
  String get rrRiderRude => 'Rude';

  @override
  String get rrRiderWrongPickup => 'Wrong pickup point';

  @override
  String get rrRiderMessy => 'Left the car dirty';

  @override
  String get rrRiderPaymentProblem => 'Payment problem';

  @override
  String get errRatingReasonInvalid =>
      'These reasons don’t match your stars. Please choose again.';

  @override
  String get errEtaTooShort =>
      'You are farther than that. Choose a longer arrival time.';

  @override
  String offerEtaPromised(int minutes) {
    return 'Promises $minutes min';
  }

  @override
  String driverDueBy(String time) {
    return 'Promised arrival: $time';
  }

  @override
  String get reasonDriverLate => 'The driver is late';

  @override
  String get errDriverNotLate =>
      'Your driver is not late yet. You can still cancel with another reason.';

  @override
  String waitFreeLeft(String time) {
    return 'Free waiting: $time left';
  }

  @override
  String waitFeeSoFar(int amount, int perMin, int max) {
    return 'Waiting fee: $amount DH so far ($perMin DH/min, max $max DH)';
  }

  @override
  String waitRulesInfo(int free, int perMin, int max) {
    return '$free min of free waiting, then $perMin DH per minute (max $max DH), added to the cash fare.';
  }

  @override
  String get receiptFare => 'Agreed fare';

  @override
  String receiptWaitingFee(int minutes) {
    return 'Waiting fee ($minutes min)';
  }

  @override
  String get emergencyContactsTitle => 'Emergency contacts';

  @override
  String emergencyContactsInfo(int max) {
    return 'If you press SOS during a ride, we send these people a link to follow your trip live. Up to $max contacts.';
  }

  @override
  String get emergencyContactsEmpty => 'No emergency contact yet.';

  @override
  String get emergencyContactAdd => 'Add a contact';

  @override
  String get emergencyContactName => 'Name';

  @override
  String get emergencyContactPhone => 'Phone number';

  @override
  String get emergencyContactRemove => 'Remove';

  @override
  String get sosContactsTitle => 'Your emergency contacts';

  @override
  String get sosContactSending => 'Sending your live trip…';

  @override
  String get sosContactSent => 'Live trip link sent';

  @override
  String get sosContactNotSent => 'Not reached yet. Our team has your alert.';

  @override
  String get errEmergencyContactsLimit =>
      'You can save up to 5 emergency contacts.';

  @override
  String get errEmergencyContactExists =>
      'This number is already in your emergency contacts.';

  @override
  String get errEmergencyContactSelf =>
      'Add someone else, not your own number.';

  @override
  String get errContactNotFound => 'This contact no longer exists.';

  @override
  String get chatTitle => 'Messages';

  @override
  String get chatHint => 'Write a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatEmpty => 'No messages yet. Tap a quick reply or write below.';

  @override
  String get chatClosed => 'Messages are closed: this ride is over.';

  @override
  String get chatFailed => 'Not sent. Tap to try again.';

  @override
  String get chatPrivacy =>
      'Messages are kept with the trip. Our team reads them only if there is a problem. Never share your phone number.';

  @override
  String get messageButton => 'Message';

  @override
  String chatNewFrom(String name) {
    return 'New message from $name';
  }

  @override
  String get chatOpen => 'Open';

  @override
  String get chatQuickComing => 'I’m coming';

  @override
  String get chatQuickAtPickup => 'I’m at the pickup point';

  @override
  String get chatQuickWaitPlease => 'Please wait 2 minutes';

  @override
  String get chatQuickWhereAreYou => 'Where are you?';

  @override
  String get chatQuickHere => 'I’m here';

  @override
  String get chatQuickOnMyWay => 'On my way';

  @override
  String get chatQuickTraffic => 'Stuck in traffic, a few more minutes';

  @override
  String get chatQuickCantFindYou => 'I can’t find you. Where exactly are you?';

  @override
  String get errChatClosed => 'Messages are open only during the ride.';

  @override
  String get callRingFromDriver => 'Your driver is calling you in RideMA';

  @override
  String get callRingFromRider => 'Your rider is calling you in RideMA';

  @override
  String get errOnAnotherRide =>
      'You are on a ride. Finish it before making a new offer.';
}
