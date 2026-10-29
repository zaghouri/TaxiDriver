import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @priceDh.
  ///
  /// In en, this message translates to:
  /// **'{amount} DH'**
  String priceDh(int amount);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @kmShort.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String kmShort(String km);

  /// No description provided for @ratingWithCount.
  ///
  /// In en, this message translates to:
  /// **'{rating} ★ ({count})'**
  String ratingWithCount(int count, String rating);

  /// No description provided for @tripsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} trips'**
  String tripsCount(int count);

  /// No description provided for @newRating.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newRating;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @noConnectionBanner.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. We keep trying…'**
  String get noConnectionBanner;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageTitle;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageChangeLater.
  ///
  /// In en, this message translates to:
  /// **'You can change it later in Profile.'**
  String get languageChangeLater;

  /// No description provided for @bootLoading.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get bootLoading;

  /// No description provided for @bootOffline.
  ///
  /// In en, this message translates to:
  /// **'We could not reach {app}. Check your internet connection.'**
  String bootOffline(String app);

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update needed'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'This version of {app} is too old. Install version {version} to continue.'**
  String updateBody(String app, String version);

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download the update'**
  String get updateDownload;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String updateDownloading(int percent);

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get updateInstall;

  /// No description provided for @updateOpenStore.
  ///
  /// In en, this message translates to:
  /// **'Open the store'**
  String get updateOpenStore;

  /// No description provided for @updateAllowInstall.
  ///
  /// In en, this message translates to:
  /// **'Android will ask you to allow installing apps from {app}. Allow it, then come back and tap Install.'**
  String updateAllowInstall(String app);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'The download failed. Check your connection and try again.'**
  String get updateFailed;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version is available.'**
  String get updateAvailable;

  /// No description provided for @updateNoLink.
  ///
  /// In en, this message translates to:
  /// **'Ask support for the new version.'**
  String get updateNoLink;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {app}'**
  String welcomeTitle(String app);

  /// No description provided for @welcomeRiderTagline.
  ///
  /// In en, this message translates to:
  /// **'You choose the price. Drivers nearby answer.'**
  String get welcomeRiderTagline;

  /// No description provided for @welcomeDriverTagline.
  ///
  /// In en, this message translates to:
  /// **'Receive rides near you. Accept the price or propose yours. 0% commission.'**
  String get welcomeDriverTagline;

  /// No description provided for @welcomeSignUp.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get welcomeSignUp;

  /// No description provided for @welcomeLogIn.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get welcomeLogIn;

  /// No description provided for @welcomeCash.
  ///
  /// In en, this message translates to:
  /// **'Pay in cash, directly to the driver.'**
  String get welcomeCash;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters'**
  String get passwordHint;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @errorNameShort.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get errorNameShort;

  /// No description provided for @errorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'This email address is not valid.'**
  String get errorEmailInvalid;

  /// No description provided for @errorPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 10 characters.'**
  String get errorPasswordShort;

  /// No description provided for @errorPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords are different.'**
  String get errorPasswordMismatch;

  /// No description provided for @errorCodeFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digits.'**
  String get errorCodeFormat;

  /// No description provided for @consentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get consentsTitle;

  /// No description provided for @consentsIntro.
  ///
  /// In en, this message translates to:
  /// **'Please read and accept each item. Tap “Read” to see the full text.'**
  String get consentsIntro;

  /// No description provided for @consentTerms.
  ///
  /// In en, this message translates to:
  /// **'I accept the Terms of use'**
  String get consentTerms;

  /// No description provided for @consentPrivacy.
  ///
  /// In en, this message translates to:
  /// **'I accept the Privacy policy'**
  String get consentPrivacy;

  /// No description provided for @consentDataTransfer.
  ///
  /// In en, this message translates to:
  /// **'I agree that some of my data is processed by services outside Morocco'**
  String get consentDataTransfer;

  /// No description provided for @consentDataTransferExplain.
  ///
  /// In en, this message translates to:
  /// **'Google Maps shows the map, Firebase (Google) sends notifications and WhatsApp (Meta) sends your phone code. These companies may store data outside Morocco. Without them the app cannot work.'**
  String get consentDataTransferExplain;

  /// No description provided for @consentBackgroundLocation.
  ///
  /// In en, this message translates to:
  /// **'I agree that {app} uses my location in the background while I am online'**
  String consentBackgroundLocation(String app);

  /// No description provided for @consentBackgroundExplain.
  ///
  /// In en, this message translates to:
  /// **'Riders nearby can find you and follow the trip, even when the app is closed. When you go offline, we stop.'**
  String get consentBackgroundExplain;

  /// No description provided for @consentsAllRequired.
  ///
  /// In en, this message translates to:
  /// **'All boxes are needed to use the app.'**
  String get consentsAllRequired;

  /// No description provided for @consentsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept and create my account'**
  String get consentsAccept;

  /// No description provided for @consentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load the texts. Check your connection and try again.'**
  String get consentsLoadFailed;

  /// No description provided for @consentVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String consentVersion(String version);

  /// No description provided for @consentsOutdated.
  ///
  /// In en, this message translates to:
  /// **'A text was updated. Please read it again.'**
  String get consentsOutdated;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}. Enter it below, or tap the link in the email.'**
  String verifyEmailBody(String email);

  /// No description provided for @verifyEmailSpam.
  ///
  /// In en, this message translates to:
  /// **'Not received? Look in the Spam folder.'**
  String get verifyEmailSpam;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeLabel;

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get resendCode;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'New code in {seconds} s'**
  String resendIn(int seconds);

  /// No description provided for @codeSent.
  ///
  /// In en, this message translates to:
  /// **'A new code was sent.'**
  String get codeSent;

  /// No description provided for @emailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get emailVerified;

  /// No description provided for @iVerifiedWithLink.
  ///
  /// In en, this message translates to:
  /// **'I used the link in the email'**
  String get iVerifiedWithLink;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginTitle;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPasswordLink;

  /// No description provided for @noAccountLink.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get noAccountLink;

  /// No description provided for @wrongAppRider.
  ///
  /// In en, this message translates to:
  /// **'This is a driver account. Use the {app} Driver app.'**
  String wrongAppRider(String app);

  /// No description provided for @wrongAppDriver.
  ///
  /// In en, this message translates to:
  /// **'This is a rider account. Create a driver account with another email.'**
  String get wrongAppDriver;

  /// No description provided for @twoFactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Security code'**
  String get twoFactorTitle;

  /// No description provided for @twoFactorEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to your email. Enter it below.'**
  String get twoFactorEmailBody;

  /// No description provided for @twoFactorTotpBody.
  ///
  /// In en, this message translates to:
  /// **'Open your authenticator app and enter the 6-digit code for {app}.'**
  String twoFactorTotpBody(String app);

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// No description provided for @forgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email. If an account exists, we will send you a code.'**
  String get forgotBody;

  /// No description provided for @forgotSend.
  ///
  /// In en, this message translates to:
  /// **'Send the code'**
  String get forgotSend;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get resetTitle;

  /// No description provided for @resetBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {email} and your new password.'**
  String resetBody(String email);

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @resetDone.
  ///
  /// In en, this message translates to:
  /// **'Your password was changed. You can log in now.'**
  String get resetDone;

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get resetButton;

  /// No description provided for @verifyPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone'**
  String get verifyPhoneTitle;

  /// No description provided for @verifyPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'We will send a code on WhatsApp to this number.'**
  String get verifyPhoneBody;

  /// No description provided for @verifyPhoneWhyRider.
  ///
  /// In en, this message translates to:
  /// **'We need a verified number before your first ride.'**
  String get verifyPhoneWhyRider;

  /// No description provided for @verifyPhoneWhyDriver.
  ///
  /// In en, this message translates to:
  /// **'We need a verified number before you go online.'**
  String get verifyPhoneWhyDriver;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'6XXXXXXXX'**
  String get phoneHint;

  /// No description provided for @errorPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 9 digits after +212 (for example 612345678).'**
  String get errorPhoneInvalid;

  /// No description provided for @phoneCodesLimit.
  ///
  /// In en, this message translates to:
  /// **'You can ask for up to 3 codes per day for the same number. Each code works for 10 minutes. The number must have WhatsApp.'**
  String get phoneCodesLimit;

  /// No description provided for @sendCodeWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Send the code on WhatsApp'**
  String get sendCodeWhatsapp;

  /// No description provided for @phoneCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code sent on WhatsApp to {phone}.'**
  String phoneCodeSentTo(String phone);

  /// No description provided for @changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// No description provided for @phoneVerified.
  ///
  /// In en, this message translates to:
  /// **'Phone verified'**
  String get phoneVerified;

  /// No description provided for @phonePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your number stays private: calls go through the app.'**
  String get phonePrivacy;

  /// No description provided for @phoneChangeHint.
  ///
  /// In en, this message translates to:
  /// **'To change a verified number, send a correction request from Profile › My data.'**
  String get phoneChangeHint;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get locationTitle;

  /// No description provided for @locationRiderBody.
  ///
  /// In en, this message translates to:
  /// **'We use your location while the app is open to set your pickup point.'**
  String get locationRiderBody;

  /// No description provided for @locationRiderDetail.
  ///
  /// In en, this message translates to:
  /// **'Your driver sees your pickup point only during a ride. You can also type your address instead.'**
  String get locationRiderDetail;

  /// No description provided for @locationDriverBody.
  ///
  /// In en, this message translates to:
  /// **'{app} uses your location even when the app is closed or not in use while you are online, so riders nearby can find you and follow the trip.'**
  String locationDriverBody(String app);

  /// No description provided for @locationDriverDetail.
  ///
  /// In en, this message translates to:
  /// **'When you go offline, we stop using your location. On the next screen choose “Allow all the time”.'**
  String get locationDriverDetail;

  /// No description provided for @locationDeniedRider.
  ///
  /// In en, this message translates to:
  /// **'Location is off. You can type your pickup address.'**
  String get locationDeniedRider;

  /// No description provided for @locationNeededDriver.
  ///
  /// In en, this message translates to:
  /// **'Location is needed to go online'**
  String get locationNeededDriver;

  /// No description provided for @locationNeededDriverBody.
  ///
  /// In en, this message translates to:
  /// **'In Settings, set Location to “Allow all the time” for {app}.'**
  String locationNeededDriverBody(String app);

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Your phone’s location (GPS) is turned off.'**
  String get locationServiceOff;

  /// No description provided for @turnOnLocation.
  ///
  /// In en, this message translates to:
  /// **'Turn on location'**
  String get turnOnLocation;

  /// No description provided for @allowLocation.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get allowLocation;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay informed'**
  String get notifTitle;

  /// No description provided for @notifRiderBody.
  ///
  /// In en, this message translates to:
  /// **'We notify you when a driver makes an offer, arrives, or when your ride changes.'**
  String get notifRiderBody;

  /// No description provided for @notifDriverBody.
  ///
  /// In en, this message translates to:
  /// **'We notify you when a new ride request arrives near you, even when the app is in the background.'**
  String get notifDriverBody;

  /// No description provided for @notifAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notifAllow;

  /// No description provided for @notifDeniedBanner.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off. You may miss ride offers.'**
  String get notifDeniedBanner;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhone;

  /// No description provided for @phoneNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get phoneNotVerified;

  /// No description provided for @phoneVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get phoneVerifiedBadge;

  /// No description provided for @verifyNow.
  ///
  /// In en, this message translates to:
  /// **'Verify now'**
  String get verifyNow;

  /// No description provided for @profileSecurity.
  ///
  /// In en, this message translates to:
  /// **'Two-step login'**
  String get profileSecurity;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profileMyData.
  ///
  /// In en, this message translates to:
  /// **'My data'**
  String get profileMyData;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get profileDeleteAccount;

  /// No description provided for @profileLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal information'**
  String get profileLegal;

  /// No description provided for @profileTrips.
  ///
  /// In en, this message translates to:
  /// **'My trips'**
  String get profileTrips;

  /// No description provided for @profileAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version {version}'**
  String profileAppVersion(String version);

  /// No description provided for @profileRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get profileRating;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to log out?'**
  String get logoutConfirm;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Change your name'**
  String get editName;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @sessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Please log in again.'**
  String get sessionEnded;

  /// No description provided for @twoFactorSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-step login'**
  String get twoFactorSettingsTitle;

  /// No description provided for @twoFactorExplain.
  ///
  /// In en, this message translates to:
  /// **'After your password, we ask for a second code. Even if someone knows your password, they cannot log in.'**
  String get twoFactorExplain;

  /// No description provided for @twoFactorOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get twoFactorOff;

  /// No description provided for @twoFactorEmail.
  ///
  /// In en, this message translates to:
  /// **'Code by email'**
  String get twoFactorEmail;

  /// No description provided for @twoFactorTotp.
  ///
  /// In en, this message translates to:
  /// **'Authenticator app'**
  String get twoFactorTotp;

  /// No description provided for @twoFactorCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current: {method}'**
  String twoFactorCurrent(String method);

  /// No description provided for @twoFactorUseEmail.
  ///
  /// In en, this message translates to:
  /// **'Use email codes'**
  String get twoFactorUseEmail;

  /// No description provided for @twoFactorUseTotp.
  ///
  /// In en, this message translates to:
  /// **'Use an authenticator app'**
  String get twoFactorUseTotp;

  /// No description provided for @twoFactorTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off two-step login'**
  String get twoFactorTurnOff;

  /// No description provided for @twoFactorTotpStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Add this key in your authenticator app (Google Authenticator, Microsoft Authenticator…).'**
  String get twoFactorTotpStep1;

  /// No description provided for @twoFactorSecret.
  ///
  /// In en, this message translates to:
  /// **'Secret key'**
  String get twoFactorSecret;

  /// No description provided for @twoFactorOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open in my authenticator app'**
  String get twoFactorOpenApp;

  /// No description provided for @twoFactorTotpStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Enter the 6-digit code shown in the app.'**
  String get twoFactorTotpStep2;

  /// No description provided for @twoFactorEnabled.
  ///
  /// In en, this message translates to:
  /// **'Two-step login is on.'**
  String get twoFactorEnabled;

  /// No description provided for @twoFactorDisabled.
  ///
  /// In en, this message translates to:
  /// **'Two-step login is off.'**
  String get twoFactorDisabled;

  /// No description provided for @passwordConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm.'**
  String get passwordConfirmPrompt;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get passwordChanged;

  /// No description provided for @myDataTitle.
  ///
  /// In en, this message translates to:
  /// **'My data'**
  String get myDataTitle;

  /// No description provided for @myDataIntro.
  ///
  /// In en, this message translates to:
  /// **'Under Moroccan law 09-08 you can get a copy of your personal data and ask us to correct it.'**
  String get myDataIntro;

  /// No description provided for @downloadMyData.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get downloadMyData;

  /// No description provided for @myDataReady.
  ///
  /// In en, this message translates to:
  /// **'Your data file is ready.'**
  String get myDataReady;

  /// No description provided for @dataRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'My requests'**
  String get dataRequestsTitle;

  /// No description provided for @dataRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No requests yet.'**
  String get dataRequestsEmpty;

  /// No description provided for @newDataRequest.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get newDataRequest;

  /// No description provided for @dataRequestAccess.
  ///
  /// In en, this message translates to:
  /// **'Access to my data'**
  String get dataRequestAccess;

  /// No description provided for @dataRequestCorrection.
  ///
  /// In en, this message translates to:
  /// **'Correct my data'**
  String get dataRequestCorrection;

  /// No description provided for @dataRequestDeletion.
  ///
  /// In en, this message translates to:
  /// **'Delete my data'**
  String get dataRequestDeletion;

  /// No description provided for @dataRequestDetails.
  ///
  /// In en, this message translates to:
  /// **'Explain your request'**
  String get dataRequestDetails;

  /// No description provided for @dataRequestDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'For example: my name is spelled wrong, the right spelling is…'**
  String get dataRequestDetailsHint;

  /// No description provided for @dataRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. We answer within 30 days.'**
  String get dataRequestSent;

  /// No description provided for @dataRequestOpen.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get dataRequestOpen;

  /// No description provided for @dataRequestDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get dataRequestDone;

  /// No description provided for @dataRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get dataRequestRejected;

  /// No description provided for @dataRequestResponse.
  ///
  /// In en, this message translates to:
  /// **'Answer: {text}'**
  String dataRequestResponse(String text);

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteTitle;

  /// No description provided for @deleteIntro.
  ///
  /// In en, this message translates to:
  /// **'Your account is deleted right away. This cannot be undone.'**
  String get deleteIntro;

  /// No description provided for @deleteWhatGoes.
  ///
  /// In en, this message translates to:
  /// **'Deleted now: your name, email, phone number, password, devices, documents, trip addresses and GPS points.'**
  String get deleteWhatGoes;

  /// No description provided for @deleteWhatStays.
  ///
  /// In en, this message translates to:
  /// **'Kept without your name, for the period required by law: trip records (date, price) so receipts and disputes stay valid.'**
  String get deleteWhatStays;

  /// No description provided for @deleteConfirmCheck.
  ///
  /// In en, this message translates to:
  /// **'I understand that this cannot be undone'**
  String get deleteConfirmCheck;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteButton;

  /// No description provided for @deleteDone.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get deleteDone;

  /// No description provided for @legalTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal information'**
  String get legalTitle;

  /// No description provided for @legalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get legalTerms;

  /// No description provided for @legalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legalPrivacy;

  /// No description provided for @legalDataTransfer.
  ///
  /// In en, this message translates to:
  /// **'Data transfer outside Morocco'**
  String get legalDataTransfer;

  /// No description provided for @legalBackgroundLocation.
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get legalBackgroundLocation;

  /// No description provided for @companyTitle.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get companyTitle;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get companyName;

  /// No description provided for @companyRc.
  ///
  /// In en, this message translates to:
  /// **'RC'**
  String get companyRc;

  /// No description provided for @companyIce.
  ///
  /// In en, this message translates to:
  /// **'ICE'**
  String get companyIce;

  /// No description provided for @companyAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get companyAddress;

  /// No description provided for @supportPhone.
  ///
  /// In en, this message translates to:
  /// **'Support phone'**
  String get supportPhone;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Support email'**
  String get supportEmail;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// No description provided for @receiptNumber.
  ///
  /// In en, this message translates to:
  /// **'Receipt no. {number}'**
  String receiptNumber(String number);

  /// No description provided for @receiptFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get receiptFrom;

  /// No description provided for @receiptTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get receiptTo;

  /// No description provided for @receiptDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get receiptDistance;

  /// No description provided for @receiptDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get receiptDuration;

  /// No description provided for @receiptPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get receiptPrice;

  /// No description provided for @receiptDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get receiptDriver;

  /// No description provided for @receiptRider.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get receiptRider;

  /// No description provided for @receiptVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get receiptVehicle;

  /// No description provided for @receiptPaidCash.
  ///
  /// In en, this message translates to:
  /// **'Paid in cash to the driver'**
  String get receiptPaidCash;

  /// No description provided for @receiptNoCommission.
  ///
  /// In en, this message translates to:
  /// **'{app} takes no commission and does not collect trip payments.'**
  String receiptNoCommission(String app);

  /// No description provided for @receiptShare.
  ///
  /// In en, this message translates to:
  /// **'Share receipt'**
  String get receiptShare;

  /// No description provided for @tripHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'My trips'**
  String get tripHistoryTitle;

  /// No description provided for @tripHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No trips yet.'**
  String get tripHistoryEmpty;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get loadMore;

  /// No description provided for @rideStatusSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for a driver'**
  String get rideStatusSearching;

  /// No description provided for @rideStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way'**
  String get rideStatusAccepted;

  /// No description provided for @rideStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived'**
  String get rideStatusArrived;

  /// No description provided for @rideStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'On trip'**
  String get rideStatusInProgress;

  /// No description provided for @rideStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get rideStatusCompleted;

  /// No description provided for @rideStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get rideStatusCancelled;

  /// No description provided for @rideStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'No driver found'**
  String get rideStatusExpired;

  /// No description provided for @homeFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get homeFrom;

  /// No description provided for @homeTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get homeTo;

  /// No description provided for @homeCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'My current location'**
  String get homeCurrentLocation;

  /// No description provided for @homeWhereTo.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get homeWhereTo;

  /// No description provided for @homeSearchAddress.
  ///
  /// In en, this message translates to:
  /// **'Search an address'**
  String get homeSearchAddress;

  /// No description provided for @homePickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Choose on the map'**
  String get homePickOnMap;

  /// No description provided for @offerYourFare.
  ///
  /// In en, this message translates to:
  /// **'Offer your fare'**
  String get offerYourFare;

  /// No description provided for @suggestedPrice.
  ///
  /// In en, this message translates to:
  /// **'Suggested: {amount} DH'**
  String suggestedPrice(int amount);

  /// No description provided for @minOffer.
  ///
  /// In en, this message translates to:
  /// **'Minimum: {amount} DH'**
  String minOffer(int amount);

  /// No description provided for @commentForDriver.
  ///
  /// In en, this message translates to:
  /// **'Comment for the driver (optional)'**
  String get commentForDriver;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'For example: I have a big suitcase'**
  String get commentHint;

  /// No description provided for @findDriver.
  ///
  /// In en, this message translates to:
  /// **'Find a driver'**
  String get findDriver;

  /// No description provided for @tripEstimate.
  ///
  /// In en, this message translates to:
  /// **'{km} km · about {minutes} min'**
  String tripEstimate(String km, int minutes);

  /// No description provided for @searchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Looking for drivers…'**
  String get searchingTitle;

  /// No description provided for @searchingTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String searchingTimeLeft(String time);

  /// No description provided for @raiseFare.
  ///
  /// In en, this message translates to:
  /// **'Raise fare'**
  String get raiseFare;

  /// No description provided for @raiseFareTitle.
  ///
  /// In en, this message translates to:
  /// **'Raise your fare'**
  String get raiseFareTitle;

  /// No description provided for @raiseFareHint.
  ///
  /// In en, this message translates to:
  /// **'A higher fare gets more answers. You cannot lower it.'**
  String get raiseFareHint;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelRequest;

  /// No description provided for @cancelRequestConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel your request?'**
  String get cancelRequestConfirm;

  /// No description provided for @offersTitle.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offersTitle;

  /// No description provided for @offerCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter-offer'**
  String get offerCounter;

  /// No description provided for @offerEta.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min away'**
  String offerEta(int minutes);

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @noOffersYet.
  ///
  /// In en, this message translates to:
  /// **'Waiting for offers. Drivers nearby can see your request.'**
  String get noOffersYet;

  /// No description provided for @requestExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'No driver accepted'**
  String get requestExpiredTitle;

  /// No description provided for @requestExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'Try again with a higher fare.'**
  String get requestExpiredBody;

  /// No description provided for @offerNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This offer is no longer available.'**
  String get offerNoLongerAvailable;

  /// No description provided for @driverOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Your driver is on the way'**
  String get driverOnTheWay;

  /// No description provided for @driverArrivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your driver is here'**
  String get driverArrivedTitle;

  /// No description provided for @onTripTitle.
  ///
  /// In en, this message translates to:
  /// **'On the way to your destination'**
  String get onTripTitle;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'Arrives in {minutes} min'**
  String etaMinutes(int minutes);

  /// No description provided for @pickupPin.
  ///
  /// In en, this message translates to:
  /// **'Pickup PIN'**
  String get pickupPin;

  /// No description provided for @pickupPinHint.
  ///
  /// In en, this message translates to:
  /// **'Give this code to the driver to start the trip.'**
  String get pickupPinHint;

  /// No description provided for @callButton.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callButton;

  /// No description provided for @shareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share trip'**
  String get shareTrip;

  /// No description provided for @sosButton.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get sosButton;

  /// No description provided for @cancelRide.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelRide;

  /// No description provided for @cancelFreeInfo.
  ///
  /// In en, this message translates to:
  /// **'You can cancel for free until the driver arrives.'**
  String get cancelFreeInfo;

  /// No description provided for @cancelCountedWarning.
  ///
  /// In en, this message translates to:
  /// **'The driver has arrived. If you cancel now, it will be counted.'**
  String get cancelCountedWarning;

  /// No description provided for @cancelReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Why do you cancel?'**
  String get cancelReasonTitle;

  /// No description provided for @reasonChangedMind.
  ///
  /// In en, this message translates to:
  /// **'I changed my mind'**
  String get reasonChangedMind;

  /// No description provided for @reasonDriverTooFar.
  ///
  /// In en, this message translates to:
  /// **'The driver is too far'**
  String get reasonDriverTooFar;

  /// No description provided for @reasonDriverAsked.
  ///
  /// In en, this message translates to:
  /// **'The driver asked me to cancel'**
  String get reasonDriverAsked;

  /// No description provided for @reasonWrongPickup.
  ///
  /// In en, this message translates to:
  /// **'Wrong pickup point'**
  String get reasonWrongPickup;

  /// No description provided for @reasonRiderNoShow.
  ///
  /// In en, this message translates to:
  /// **'The rider did not come'**
  String get reasonRiderNoShow;

  /// No description provided for @reasonCarMismatch.
  ///
  /// In en, this message translates to:
  /// **'The car does not match'**
  String get reasonCarMismatch;

  /// No description provided for @reasonSafety.
  ///
  /// In en, this message translates to:
  /// **'I do not feel safe'**
  String get reasonSafety;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get reasonOther;

  /// No description provided for @carMismatch.
  ///
  /// In en, this message translates to:
  /// **'Car doesn’t match?'**
  String get carMismatch;

  /// No description provided for @carMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'If the plate or the car is different, do not get in. Report it: you can then cancel for free.'**
  String get carMismatchBody;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you, our team was alerted.'**
  String get reportSent;

  /// No description provided for @cancelWarningRecent.
  ///
  /// In en, this message translates to:
  /// **'You cancelled several rides recently. Please book only when you are ready.'**
  String get cancelWarningRecent;

  /// No description provided for @rideCancelledByDriver.
  ///
  /// In en, this message translates to:
  /// **'The driver cancelled. You can request again.'**
  String get rideCancelledByDriver;

  /// No description provided for @rideCancelledByRider.
  ///
  /// In en, this message translates to:
  /// **'The rider cancelled the ride.'**
  String get rideCancelledByRider;

  /// No description provided for @rateDriver.
  ///
  /// In en, this message translates to:
  /// **'How was your driver?'**
  String get rateDriver;

  /// No description provided for @rateRider.
  ///
  /// In en, this message translates to:
  /// **'How was the rider?'**
  String get rateRider;

  /// No description provided for @rateComment.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get rateComment;

  /// No description provided for @rateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send rating'**
  String get rateSubmit;

  /// No description provided for @rateSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get rateSkip;

  /// No description provided for @fareToPay.
  ///
  /// In en, this message translates to:
  /// **'Fare: {amount} DH. Pay cash to the driver.'**
  String fareToPay(int amount);

  /// No description provided for @thanksRating.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get thanksRating;

  /// No description provided for @idCheckRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'For safety, we need a photo of your ID card before your next ride.'**
  String get idCheckRequiredBody;

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your trip'**
  String get shareTitle;

  /// No description provided for @shareBody.
  ///
  /// In en, this message translates to:
  /// **'Add up to 5 contacts. They get a link to follow your trip live until 1 hour after it ends.'**
  String get shareBody;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactName;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactPhone;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add a contact'**
  String get addContact;

  /// No description provided for @shareCreate.
  ///
  /// In en, this message translates to:
  /// **'Create the link and share'**
  String get shareCreate;

  /// No description provided for @shareMessage.
  ///
  /// In en, this message translates to:
  /// **'Follow my {app} trip live: {url}'**
  String shareMessage(String app, String url);

  /// No description provided for @shareMaxContacts.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 5 contacts.'**
  String get shareMaxContacts;

  /// No description provided for @sosTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get sosTitle;

  /// No description provided for @sosBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a service: your phone calls it and the {app} team gets your live location.'**
  String sosBody(String app);

  /// No description provided for @sosPolice.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get sosPolice;

  /// No description provided for @sosGendarmerie.
  ///
  /// In en, this message translates to:
  /// **'Gendarmerie'**
  String get sosGendarmerie;

  /// No description provided for @sosAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Ambulance'**
  String get sosAmbulance;

  /// No description provided for @sosAlertSent.
  ///
  /// In en, this message translates to:
  /// **'Alert sent. Our team sees your location.'**
  String get sosAlertSent;

  /// No description provided for @sosAlertFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not send the alert. Call the number directly.'**
  String get sosAlertFailed;

  /// No description provided for @sosSharingLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location is shared every 10 seconds while this screen is open.'**
  String get sosSharingLocation;

  /// No description provided for @sosSending.
  ///
  /// In en, this message translates to:
  /// **'Sending the alert…'**
  String get sosSending;

  /// No description provided for @callCalling.
  ///
  /// In en, this message translates to:
  /// **'Calling…'**
  String get callCalling;

  /// No description provided for @callRinging.
  ///
  /// In en, this message translates to:
  /// **'Ringing…'**
  String get callRinging;

  /// No description provided for @callIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get callIncoming;

  /// No description provided for @callConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get callConnecting;

  /// No description provided for @callActive.
  ///
  /// In en, this message translates to:
  /// **'In call'**
  String get callActive;

  /// No description provided for @callEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callEnded;

  /// No description provided for @callRejected.
  ///
  /// In en, this message translates to:
  /// **'Call declined'**
  String get callRejected;

  /// No description provided for @callFailed.
  ///
  /// In en, this message translates to:
  /// **'The call could not connect.'**
  String get callFailed;

  /// No description provided for @callMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get callMute;

  /// No description provided for @callUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get callUnmute;

  /// No description provided for @callSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get callSpeaker;

  /// No description provided for @callHangUp.
  ///
  /// In en, this message translates to:
  /// **'Hang up'**
  String get callHangUp;

  /// No description provided for @callAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get callAnswer;

  /// No description provided for @callDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get callDecline;

  /// No description provided for @callMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone to make calls.'**
  String get callMicDenied;

  /// No description provided for @callPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your phone number is not shared.'**
  String get callPrivacy;

  /// No description provided for @callYourDriver.
  ///
  /// In en, this message translates to:
  /// **'Your driver'**
  String get callYourDriver;

  /// No description provided for @callYourRider.
  ///
  /// In en, this message translates to:
  /// **'Your rider'**
  String get callYourRider;

  /// No description provided for @plateLabel.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get plateLabel;

  /// No description provided for @carLabel.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get carLabel;

  /// No description provided for @colourLabel.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colourLabel;

  /// No description provided for @goOnline.
  ///
  /// In en, this message translates to:
  /// **'Go online'**
  String get goOnline;

  /// No description provided for @goOffline.
  ///
  /// In en, this message translates to:
  /// **'Go offline'**
  String get goOffline;

  /// No description provided for @onlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get onlineLabel;

  /// No description provided for @offlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineLabel;

  /// No description provided for @onlineNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'{app} — you are online'**
  String onlineNotificationTitle(String app);

  /// No description provided for @onlineNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'You receive ride requests near you.'**
  String get onlineNotificationBody;

  /// No description provided for @offlineHint.
  ///
  /// In en, this message translates to:
  /// **'Go online to receive ride requests.'**
  String get offlineHint;

  /// No description provided for @requestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride requests'**
  String get requestsTitle;

  /// No description provided for @noRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests right now. Stay online.'**
  String get noRequests;

  /// No description provided for @pickupDistance.
  ///
  /// In en, this message translates to:
  /// **'{km} km to pickup · {minutes} min'**
  String pickupDistance(String km, int minutes);

  /// No description provided for @tripDistance.
  ///
  /// In en, this message translates to:
  /// **'Trip: {km} km'**
  String tripDistance(String km);

  /// No description provided for @pickupLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickupLabel;

  /// No description provided for @destinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destinationLabel;

  /// No description provided for @riderLabel.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get riderLabel;

  /// No description provided for @riderComment.
  ///
  /// In en, this message translates to:
  /// **'Rider’s comment'**
  String get riderComment;

  /// No description provided for @acceptFor.
  ///
  /// In en, this message translates to:
  /// **'Accept for {amount} DH'**
  String acceptFor(int amount);

  /// No description provided for @proposePrice.
  ///
  /// In en, this message translates to:
  /// **'Or propose your price'**
  String get proposePrice;

  /// No description provided for @counterPlus.
  ///
  /// In en, this message translates to:
  /// **'+{amount} DH'**
  String counterPlus(int amount);

  /// No description provided for @otherAmount.
  ///
  /// In en, this message translates to:
  /// **'Other amount'**
  String get otherAmount;

  /// No description provided for @counterOfferFor.
  ///
  /// In en, this message translates to:
  /// **'Propose {amount} DH'**
  String counterOfferFor(int amount);

  /// No description provided for @counterMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum {amount} DH'**
  String counterMax(int amount);

  /// No description provided for @waitingForRider.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the rider… {time}'**
  String waitingForRider(String time);

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw my offer'**
  String get withdraw;

  /// No description provided for @bidAccepted.
  ///
  /// In en, this message translates to:
  /// **'The rider accepted your offer!'**
  String get bidAccepted;

  /// No description provided for @bidLost.
  ///
  /// In en, this message translates to:
  /// **'The rider chose another driver.'**
  String get bidLost;

  /// No description provided for @bidDeclined.
  ///
  /// In en, this message translates to:
  /// **'The rider declined your offer.'**
  String get bidDeclined;

  /// No description provided for @bidExpired.
  ///
  /// In en, this message translates to:
  /// **'Your offer expired.'**
  String get bidExpired;

  /// No description provided for @bidOutdated.
  ///
  /// In en, this message translates to:
  /// **'The rider raised the fare. Make a new offer.'**
  String get bidOutdated;

  /// No description provided for @requestClosedTaken.
  ///
  /// In en, this message translates to:
  /// **'Another driver took this ride.'**
  String get requestClosedTaken;

  /// No description provided for @requestClosedGone.
  ///
  /// In en, this message translates to:
  /// **'This request is no longer available.'**
  String get requestClosedGone;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @goingToPickup.
  ///
  /// In en, this message translates to:
  /// **'Go to the pickup point'**
  String get goingToPickup;

  /// No description provided for @iveArrived.
  ///
  /// In en, this message translates to:
  /// **'I’ve arrived'**
  String get iveArrived;

  /// No description provided for @enterPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the rider’s PIN'**
  String get enterPinTitle;

  /// No description provided for @enterPinHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the rider for the 4-digit code shown in their app.'**
  String get enterPinHint;

  /// No description provided for @startTrip.
  ///
  /// In en, this message translates to:
  /// **'Start the trip'**
  String get startTrip;

  /// No description provided for @riderNoShow.
  ///
  /// In en, this message translates to:
  /// **'Rider didn’t come'**
  String get riderNoShow;

  /// No description provided for @riderNoShowInfo.
  ///
  /// In en, this message translates to:
  /// **'After 5 minutes of waiting you can cancel without penalty.'**
  String get riderNoShowInfo;

  /// No description provided for @waitTime.
  ///
  /// In en, this message translates to:
  /// **'Waiting: {time}'**
  String waitTime(String time);

  /// No description provided for @completeTrip.
  ///
  /// In en, this message translates to:
  /// **'Complete the trip'**
  String get completeTrip;

  /// No description provided for @collectCash.
  ///
  /// In en, this message translates to:
  /// **'Collect {amount} DH in cash'**
  String collectCash(int amount);

  /// No description provided for @driverCancelWarning.
  ///
  /// In en, this message translates to:
  /// **'If you cancel now, you get a penalty point. Too many cancellations block you for a while.'**
  String get driverCancelWarning;

  /// No description provided for @blockedUntil.
  ///
  /// In en, this message translates to:
  /// **'You are paused until {time} because of cancellations.'**
  String blockedUntil(String time);

  /// No description provided for @adminMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Message from {app}'**
  String adminMessageTitle(String app);

  /// No description provided for @earningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earningsTitle;

  /// No description provided for @earningsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get earningsToday;

  /// No description provided for @earningsWeek.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get earningsWeek;

  /// No description provided for @earningsTrips.
  ///
  /// In en, this message translates to:
  /// **'{count} trips'**
  String earningsTrips(int count);

  /// No description provided for @earningsCash.
  ///
  /// In en, this message translates to:
  /// **'{amount} DH in cash'**
  String earningsCash(int amount);

  /// No description provided for @earningsNoCommission.
  ///
  /// In en, this message translates to:
  /// **'0% commission: everything you collect is yours.'**
  String get earningsNoCommission;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'My documents'**
  String get documentsTitle;

  /// No description provided for @docCinFront.
  ///
  /// In en, this message translates to:
  /// **'ID card (front)'**
  String get docCinFront;

  /// No description provided for @docCinBack.
  ///
  /// In en, this message translates to:
  /// **'ID card (back)'**
  String get docCinBack;

  /// No description provided for @docLicence.
  ///
  /// In en, this message translates to:
  /// **'Driving licence'**
  String get docLicence;

  /// No description provided for @docCarteGrise.
  ///
  /// In en, this message translates to:
  /// **'Registration (carte grise)'**
  String get docCarteGrise;

  /// No description provided for @docInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get docInsurance;

  /// No description provided for @docVisiteTechnique.
  ///
  /// In en, this message translates to:
  /// **'Technical inspection'**
  String get docVisiteTechnique;

  /// No description provided for @docSelfie.
  ///
  /// In en, this message translates to:
  /// **'Selfie'**
  String get docSelfie;

  /// No description provided for @docStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get docStatusPending;

  /// No description provided for @docStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get docStatusApproved;

  /// No description provided for @docStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get docStatusRejected;

  /// No description provided for @docStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get docStatusExpired;

  /// No description provided for @docStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get docStatusMissing;

  /// No description provided for @docExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires on {date}'**
  String docExpiresOn(String date);

  /// No description provided for @docExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'{doc} expires in {days} days. Upload the new one now.'**
  String docExpiringSoon(int days, String doc);

  /// No description provided for @docExpiredBlocked.
  ///
  /// In en, this message translates to:
  /// **'A document has expired. You cannot go online until you upload a valid one.'**
  String get docExpiredBlocked;

  /// No description provided for @docUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get docUpload;

  /// No description provided for @docReupload.
  ///
  /// In en, this message translates to:
  /// **'Upload again'**
  String get docReupload;

  /// No description provided for @docExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get docExpiryDate;

  /// No description provided for @docRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String docRejectReason(String reason);

  /// No description provided for @docTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get docTakePhoto;

  /// No description provided for @docChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get docChooseFile;

  /// No description provided for @docPhotoTips.
  ///
  /// In en, this message translates to:
  /// **'Put the document on a table, in good light. All 4 corners must be visible and the text readable.'**
  String get docPhotoTips;

  /// No description provided for @docUploaded.
  ///
  /// In en, this message translates to:
  /// **'Document sent for review.'**
  String get docUploaded;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Become a driver'**
  String get onboardingTitle;

  /// No description provided for @onboardingStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onboardingStep(int step, int total);

  /// No description provided for @driverTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Type of driver'**
  String get driverTypeTitle;

  /// No description provided for @driverTypeTaxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get driverTypeTaxi;

  /// No description provided for @driverTypeLicensedOperator.
  ///
  /// In en, this message translates to:
  /// **'Licensed operator (VTC)'**
  String get driverTypeLicensedOperator;

  /// No description provided for @driverTypePrivateCar.
  ///
  /// In en, this message translates to:
  /// **'Private car'**
  String get driverTypePrivateCar;

  /// No description provided for @personalInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get personalInfoTitle;

  /// No description provided for @cinLast4Label.
  ///
  /// In en, this message translates to:
  /// **'Last 4 characters of your ID card (CIN)'**
  String get cinLast4Label;

  /// No description provided for @cinLast4Hint.
  ///
  /// In en, this message translates to:
  /// **'We keep only these characters, not the full number.'**
  String get cinLast4Hint;

  /// No description provided for @licenceIssuedLabel.
  ///
  /// In en, this message translates to:
  /// **'Driving licence issue date'**
  String get licenceIssuedLabel;

  /// No description provided for @vehicleTitle.
  ///
  /// In en, this message translates to:
  /// **'Your car'**
  String get vehicleTitle;

  /// No description provided for @vehicleMake.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get vehicleMake;

  /// No description provided for @vehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get vehicleModel;

  /// No description provided for @vehicleYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get vehicleYear;

  /// No description provided for @vehicleColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get vehicleColour;

  /// No description provided for @vehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get vehiclePlate;

  /// No description provided for @vehicleDoors.
  ///
  /// In en, this message translates to:
  /// **'Number of doors'**
  String get vehicleDoors;

  /// No description provided for @vehicleAc.
  ///
  /// In en, this message translates to:
  /// **'Air conditioning'**
  String get vehicleAc;

  /// No description provided for @errorCarTooOld.
  ///
  /// In en, this message translates to:
  /// **'The car must be from {year} or newer.'**
  String errorCarTooOld(int year);

  /// No description provided for @errorCarDoors.
  ///
  /// In en, this message translates to:
  /// **'The car must have 4 doors.'**
  String get errorCarDoors;

  /// No description provided for @errorCarNoAc.
  ///
  /// In en, this message translates to:
  /// **'The car must have air conditioning.'**
  String get errorCarNoAc;

  /// No description provided for @errorLicenceRecent.
  ///
  /// In en, this message translates to:
  /// **'Your licence must be at least 3 years old.'**
  String get errorLicenceRecent;

  /// No description provided for @documentsStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Your documents'**
  String get documentsStepTitle;

  /// No description provided for @submitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get submitForReview;

  /// No description provided for @underReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get underReviewTitle;

  /// No description provided for @underReviewBody.
  ///
  /// In en, this message translates to:
  /// **'We are checking your documents. We will notify you, usually within 1 to 2 working days.'**
  String get underReviewBody;

  /// No description provided for @rejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Application not accepted'**
  String get rejectedTitle;

  /// No description provided for @rejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}. Fix it and submit again.'**
  String rejectedBody(String reason);

  /// No description provided for @suspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account paused'**
  String get suspendedTitle;

  /// No description provided for @suspendedBody.
  ///
  /// In en, this message translates to:
  /// **'Your driver account is paused. Contact support to know more.'**
  String get suspendedBody;

  /// No description provided for @approvedTitle.
  ///
  /// In en, this message translates to:
  /// **'You are approved!'**
  String get approvedTitle;

  /// No description provided for @batteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep {app} running'**
  String batteryTitle(String app);

  /// No description provided for @batteryIntro.
  ///
  /// In en, this message translates to:
  /// **'Some phones close apps in the background to save battery. Follow these steps once so you do not miss ride requests while online.'**
  String get batteryIntro;

  /// No description provided for @batteryChooseBrand.
  ///
  /// In en, this message translates to:
  /// **'Choose your phone brand'**
  String get batteryChooseBrand;

  /// No description provided for @batteryOther.
  ///
  /// In en, this message translates to:
  /// **'Other brand'**
  String get batteryOther;

  /// No description provided for @batteryOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open {app} settings'**
  String batteryOpenSettings(String app);

  /// No description provided for @batteryNamesDiffer.
  ///
  /// In en, this message translates to:
  /// **'Names can change a little between phone versions. Look for the closest one.'**
  String get batteryNamesDiffer;

  /// No description provided for @batteryDone.
  ///
  /// In en, this message translates to:
  /// **'I did it'**
  String get batteryDone;

  /// No description provided for @batteryXiaomi1.
  ///
  /// In en, this message translates to:
  /// **'Long-press the {app} icon, then tap “App info” (ⓘ).'**
  String batteryXiaomi1(String app);

  /// No description provided for @batteryXiaomi2.
  ///
  /// In en, this message translates to:
  /// **'Tap “Battery saver” and choose “No restrictions”.'**
  String get batteryXiaomi2;

  /// No description provided for @batteryXiaomi3.
  ///
  /// In en, this message translates to:
  /// **'Turn on “Autostart”.'**
  String get batteryXiaomi3;

  /// No description provided for @batteryXiaomi4.
  ///
  /// In en, this message translates to:
  /// **'Tap “Other permissions” and allow “Start in background” and “Show on lock screen”.'**
  String get batteryXiaomi4;

  /// No description provided for @batteryXiaomi5.
  ///
  /// In en, this message translates to:
  /// **'Tap “Permissions” › “Location” › “Allow all the time”.'**
  String get batteryXiaomi5;

  /// No description provided for @batteryXiaomi6.
  ///
  /// In en, this message translates to:
  /// **'Open recent apps, long-press the {app} card and tap the lock icon.'**
  String batteryXiaomi6(String app);

  /// No description provided for @batteryTecno1.
  ///
  /// In en, this message translates to:
  /// **'Long-press the {app} icon, then tap “App info”.'**
  String batteryTecno1(String app);

  /// No description provided for @batteryTecno2.
  ///
  /// In en, this message translates to:
  /// **'Tap “Battery” and choose “No restriction” (or turn on “Allow background activity”).'**
  String get batteryTecno2;

  /// No description provided for @batteryTecno3.
  ///
  /// In en, this message translates to:
  /// **'In Settings › App management › “Auto-start”, turn {app} on.'**
  String batteryTecno3(String app);

  /// No description provided for @batteryTecno4.
  ///
  /// In en, this message translates to:
  /// **'Open “Phone Master” › “Power saving” and remove {app} from the apps that are closed automatically.'**
  String batteryTecno4(String app);

  /// No description provided for @batteryTecno5.
  ///
  /// In en, this message translates to:
  /// **'Tap “Permissions” › “Location” › “Allow all the time”.'**
  String get batteryTecno5;

  /// No description provided for @batteryTecno6.
  ///
  /// In en, this message translates to:
  /// **'Open recent apps and pull the {app} card down (or tap the lock) to lock it.'**
  String batteryTecno6(String app);

  /// No description provided for @batteryInfinix1.
  ///
  /// In en, this message translates to:
  /// **'Open Settings › “Battery” › “App launch” (or “Auto-start management”).'**
  String get batteryInfinix1;

  /// No description provided for @batteryInfinix2.
  ///
  /// In en, this message translates to:
  /// **'Find {app}, choose “Manage manually” and turn on “Auto-launch”, “Secondary launch” and “Run in background”.'**
  String batteryInfinix2(String app);

  /// No description provided for @batteryInfinix3.
  ///
  /// In en, this message translates to:
  /// **'Long-press the {app} icon › “App info” › “Battery” › “Allow background activity”.'**
  String batteryInfinix3(String app);

  /// No description provided for @batteryInfinix4.
  ///
  /// In en, this message translates to:
  /// **'In “Phone Master”, turn off auto-clean for {app}.'**
  String batteryInfinix4(String app);

  /// No description provided for @batteryInfinix5.
  ///
  /// In en, this message translates to:
  /// **'In “Permissions” › “Location”, choose “Allow all the time”.'**
  String get batteryInfinix5;

  /// No description provided for @batteryInfinix6.
  ///
  /// In en, this message translates to:
  /// **'Open recent apps and lock the {app} card.'**
  String batteryInfinix6(String app);

  /// No description provided for @batteryOppo1.
  ///
  /// In en, this message translates to:
  /// **'Long-press the {app} icon, then tap “App info”.'**
  String batteryOppo1(String app);

  /// No description provided for @batteryOppo2.
  ///
  /// In en, this message translates to:
  /// **'Tap “Battery usage” and turn on “Allow background activity”, “Allow foreground activity” and “Allow auto launch”.'**
  String get batteryOppo2;

  /// No description provided for @batteryOppo3.
  ///
  /// In en, this message translates to:
  /// **'On older phones: Settings › “Battery” › “More settings” › “Optimise battery use” › {app} › “Don’t optimise”.'**
  String batteryOppo3(String app);

  /// No description provided for @batteryOppo4.
  ///
  /// In en, this message translates to:
  /// **'Tap “Permissions” › “Location” › “Allow all the time”.'**
  String get batteryOppo4;

  /// No description provided for @batteryOppo5.
  ///
  /// In en, this message translates to:
  /// **'Open recent apps, tap the ⋮ menu on the {app} card and choose “Lock”.'**
  String batteryOppo5(String app);

  /// No description provided for @batterySamsung1.
  ///
  /// In en, this message translates to:
  /// **'Long-press the {app} icon, then tap “App info”.'**
  String batterySamsung1(String app);

  /// No description provided for @batterySamsung2.
  ///
  /// In en, this message translates to:
  /// **'Tap “Battery” and choose “Unrestricted”.'**
  String get batterySamsung2;

  /// No description provided for @batterySamsung3.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings › “Battery” (or “Device care” › “Battery”) › “Background usage limits”.'**
  String get batterySamsung3;

  /// No description provided for @batterySamsung4.
  ///
  /// In en, this message translates to:
  /// **'Make sure {app} is not in “Sleeping apps” or “Deep sleeping apps”, and add it to “Never sleeping apps”.'**
  String batterySamsung4(String app);

  /// No description provided for @batterySamsung5.
  ///
  /// In en, this message translates to:
  /// **'In App info › “Permissions” › “Location”, choose “Allow all the time”.'**
  String get batterySamsung5;

  /// No description provided for @batteryGeneric1.
  ///
  /// In en, this message translates to:
  /// **'Open Settings › “Apps” › {app} (or long-press the icon › “App info”).'**
  String batteryGeneric1(String app);

  /// No description provided for @batteryGeneric2.
  ///
  /// In en, this message translates to:
  /// **'In “Battery”, choose “Unrestricted” or “Don’t optimise”, or allow background activity.'**
  String get batteryGeneric2;

  /// No description provided for @batteryGeneric3.
  ///
  /// In en, this message translates to:
  /// **'If you see “Auto-start” or “Launch at startup”, turn it on for {app}.'**
  String batteryGeneric3(String app);

  /// No description provided for @batteryGeneric4.
  ///
  /// In en, this message translates to:
  /// **'In “Permissions” › “Location”, choose “Allow all the time”.'**
  String get batteryGeneric4;

  /// No description provided for @batteryGeneric5.
  ///
  /// In en, this message translates to:
  /// **'While online, do not swipe {app} away from recent apps.'**
  String batteryGeneric5(String app);

  /// No description provided for @subscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionPrice.
  ///
  /// In en, this message translates to:
  /// **'{amount} DH for {days} days'**
  String subscriptionPrice(int amount, int days);

  /// No description provided for @subscriptionFreeRides.
  ///
  /// In en, this message translates to:
  /// **'{count} free rides per day'**
  String subscriptionFreeRides(int count);

  /// No description provided for @subscriptionRidesToday.
  ///
  /// In en, this message translates to:
  /// **'Rides today: {count} / {limit}'**
  String subscriptionRidesToday(int count, int limit);

  /// No description provided for @subscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is active.'**
  String get subscriptionActive;

  /// No description provided for @subscriptionInactive.
  ///
  /// In en, this message translates to:
  /// **'No active subscription.'**
  String get subscriptionInactive;

  /// No description provided for @subscriptionPayWith.
  ///
  /// In en, this message translates to:
  /// **'Pay with'**
  String get subscriptionPayWith;

  /// No description provided for @payCashplus.
  ///
  /// In en, this message translates to:
  /// **'Cash at CashPlus'**
  String get payCashplus;

  /// No description provided for @payWafacash.
  ///
  /// In en, this message translates to:
  /// **'Cash at Wafacash'**
  String get payWafacash;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Bank card'**
  String get payCard;

  /// No description provided for @payWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile wallet'**
  String get payWallet;

  /// No description provided for @payUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get payUnavailable;

  /// No description provided for @subscriptionCashCode.
  ///
  /// In en, this message translates to:
  /// **'Go to a {agent} agency and give this code: {code}. Amount: {amount} DH. Valid for {hours} hours.'**
  String subscriptionCashCode(String agent, int amount, String code, int hours);

  /// No description provided for @subscriptionPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get subscriptionPending;

  /// No description provided for @subscriptionOpenPayment.
  ///
  /// In en, this message translates to:
  /// **'Open the payment page'**
  String get subscriptionOpenPayment;

  /// No description provided for @subscriptionOff.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions are not needed for now. All rides are free.'**
  String get subscriptionOff;

  /// No description provided for @deviceMockTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off fake GPS'**
  String get deviceMockTitle;

  /// No description provided for @deviceMockBody.
  ///
  /// In en, this message translates to:
  /// **'An app that fakes your location is active. Turn it off in Developer options, then try again.'**
  String get deviceMockBody;

  /// No description provided for @deviceRootedTitle.
  ///
  /// In en, this message translates to:
  /// **'This phone cannot be used to drive'**
  String get deviceRootedTitle;

  /// No description provided for @deviceRootedBody.
  ///
  /// In en, this message translates to:
  /// **'This phone has been modified (rooted). For everyone’s safety, please use another phone.'**
  String get deviceRootedBody;

  /// No description provided for @deviceCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get deviceCheckAgain;

  /// Error text for API code NETWORK_ERROR
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get errNetworkError;

  /// Error text for API code TIMEOUT
  ///
  /// In en, this message translates to:
  /// **'The server is taking too long. Try again.'**
  String get errTimeout;

  /// Error text for API code INTERNAL
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Try again in a moment.'**
  String get errInternal;

  /// Error text for API code RATE_LIMITED
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a little and try again.'**
  String get errRateLimited;

  /// Error text for API code VALIDATION_ERROR
  ///
  /// In en, this message translates to:
  /// **'Some information is missing or not valid.'**
  String get errValidationError;

  /// Error text for API code UPGRADE_REQUIRED
  ///
  /// In en, this message translates to:
  /// **'Please update the app to continue.'**
  String get errUpgradeRequired;

  /// Error text for API code AUTH_REQUIRED
  ///
  /// In en, this message translates to:
  /// **'Please log in.'**
  String get errAuthRequired;

  /// Error text for API code TOKEN_INVALID
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please log in again.'**
  String get errTokenInvalid;

  /// Error text for API code SESSION_EXPIRED
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please log in again.'**
  String get errSessionExpired;

  /// Error text for API code REFRESH_INVALID
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Please log in again.'**
  String get errRefreshInvalid;

  /// Error text for API code REFRESH_REUSED
  ///
  /// In en, this message translates to:
  /// **'For your safety we logged you out. Please log in again.'**
  String get errRefreshReused;

  /// Error text for API code SESSION_REVOKED
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Please log in again.'**
  String get errSessionRevoked;

  /// Error text for API code ACCOUNT_DISABLED
  ///
  /// In en, this message translates to:
  /// **'This account is suspended. Contact support.'**
  String get errAccountDisabled;

  /// Error text for API code WRONG_ROLE
  ///
  /// In en, this message translates to:
  /// **'This account cannot be used in this app.'**
  String get errWrongRole;

  /// Error text for API code INVALID_CREDENTIALS
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get errInvalidCredentials;

  /// Error text for API code EMAIL_NOT_VERIFIED
  ///
  /// In en, this message translates to:
  /// **'Please verify your email first.'**
  String get errEmailNotVerified;

  /// Error text for API code EMAIL_TAKEN
  ///
  /// In en, this message translates to:
  /// **'An account already uses this email. Log in or reset your password.'**
  String get errEmailTaken;

  /// Error text for API code LOGIN_LOCKED
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in 15 minutes or reset your password.'**
  String get errLoginLocked;

  /// Error text for API code MFA_CODE_INVALID
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Check it and try again.'**
  String get errMfaCodeInvalid;

  /// Error text for API code MFA_LOCKED
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Try again in 15 minutes.'**
  String get errMfaLocked;

  /// Error text for API code MFA_TOKEN_INVALID
  ///
  /// In en, this message translates to:
  /// **'This step expired. Please log in again.'**
  String get errMfaTokenInvalid;

  /// Error text for API code CODE_INVALID
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Check it and try again.'**
  String get errCodeInvalid;

  /// Error text for API code CODE_EXPIRED
  ///
  /// In en, this message translates to:
  /// **'This code expired. Ask for a new one.'**
  String get errCodeExpired;

  /// Error text for API code CODE_TOO_MANY_ATTEMPTS
  ///
  /// In en, this message translates to:
  /// **'Too many wrong tries. Ask for a new code.'**
  String get errCodeTooManyAttempts;

  /// Error text for API code RESEND_TOO_SOON
  ///
  /// In en, this message translates to:
  /// **'Wait a minute before asking for a new code.'**
  String get errResendTooSoon;

  /// Error text for API code LINK_INVALID
  ///
  /// In en, this message translates to:
  /// **'This link expired. Ask for a new code in the app.'**
  String get errLinkInvalid;

  /// Error text for API code CONSENT_REQUIRED
  ///
  /// In en, this message translates to:
  /// **'Please accept all the required items.'**
  String get errConsentRequired;

  /// Error text for API code CONSENT_OUTDATED
  ///
  /// In en, this message translates to:
  /// **'A text was updated. Please read it again.'**
  String get errConsentOutdated;

  /// Error text for API code PHONE_ALREADY_VERIFIED
  ///
  /// In en, this message translates to:
  /// **'Your phone is already verified. To change it, send a correction request from Profile › My data.'**
  String get errPhoneAlreadyVerified;

  /// Error text for API code PHONE_IN_USE
  ///
  /// In en, this message translates to:
  /// **'This number is already used by another account.'**
  String get errPhoneInUse;

  /// Error text for API code PHONE_CODE_LIMIT
  ///
  /// In en, this message translates to:
  /// **'You reached 3 codes today for this number. Try again tomorrow.'**
  String get errPhoneCodeLimit;

  /// Error text for API code OTP_SEND_FAILED
  ///
  /// In en, this message translates to:
  /// **'We could not send the WhatsApp code. Check that the number has WhatsApp and try again.'**
  String get errOtpSendFailed;

  /// Error text for API code PHONE_NOT_VERIFIED
  ///
  /// In en, this message translates to:
  /// **'Please verify your phone number first.'**
  String get errPhoneNotVerified;

  /// Error text for API code ID_CHECK_REQUIRED
  ///
  /// In en, this message translates to:
  /// **'We need a photo of your ID card before your next ride.'**
  String get errIdCheckRequired;

  /// Error text for API code OFFER_TOO_LOW
  ///
  /// In en, this message translates to:
  /// **'Your fare is too low for this trip.'**
  String get errOfferTooLow;

  /// Error text for API code OFFER_TOO_HIGH
  ///
  /// In en, this message translates to:
  /// **'Your fare is too high for this trip.'**
  String get errOfferTooHigh;

  /// Error text for API code OFFER_NOT_HIGHER
  ///
  /// In en, this message translates to:
  /// **'The new fare must be higher than the current one.'**
  String get errOfferNotHigher;

  /// Error text for API code RIDE_ALREADY_ACTIVE
  ///
  /// In en, this message translates to:
  /// **'You already have a ride in progress.'**
  String get errRideAlreadyActive;

  /// Error text for API code OUT_OF_SERVICE_AREA
  ///
  /// In en, this message translates to:
  /// **'This place is outside our service area for now.'**
  String get errOutOfServiceArea;

  /// Error text for API code TRIP_TOO_LONG
  ///
  /// In en, this message translates to:
  /// **'This trip is too long for the app.'**
  String get errTripTooLong;

  /// Error text for API code BID_NOT_AVAILABLE
  ///
  /// In en, this message translates to:
  /// **'This offer is no longer available.'**
  String get errBidNotAvailable;

  /// Error text for API code RIDE_NOT_SEARCHING
  ///
  /// In en, this message translates to:
  /// **'This ride is no longer looking for a driver.'**
  String get errRideNotSearching;

  /// Error text for API code DRIVER_BUSY
  ///
  /// In en, this message translates to:
  /// **'This driver just took another ride. Choose another offer.'**
  String get errDriverBusy;

  /// Error text for API code CANNOT_CANCEL
  ///
  /// In en, this message translates to:
  /// **'This ride cannot be cancelled now.'**
  String get errCannotCancel;

  /// Error text for API code NO_SHOW_TOO_EARLY
  ///
  /// In en, this message translates to:
  /// **'You can use “Rider didn’t come” after 5 minutes of waiting.'**
  String get errNoShowTooEarly;

  /// Error text for API code RIDE_NOT_ACTIVE
  ///
  /// In en, this message translates to:
  /// **'This ride is not active any more.'**
  String get errRideNotActive;

  /// Error text for API code RIDE_NOT_FOUND
  ///
  /// In en, this message translates to:
  /// **'Ride not found.'**
  String get errRideNotFound;

  /// Error text for API code RIDE_NOT_COMPLETED
  ///
  /// In en, this message translates to:
  /// **'A receipt is available after the trip.'**
  String get errRideNotCompleted;

  /// Error text for API code ALREADY_RATED
  ///
  /// In en, this message translates to:
  /// **'You already rated this trip.'**
  String get errAlreadyRated;

  /// Error text for API code RATING_WINDOW_CLOSED
  ///
  /// In en, this message translates to:
  /// **'It is too late to rate this trip.'**
  String get errRatingWindowClosed;

  /// Error text for API code BID_ALREADY_ACTIVE
  ///
  /// In en, this message translates to:
  /// **'You already made an offer on this ride.'**
  String get errBidAlreadyActive;

  /// Error text for API code BID_DECLINED_BEFORE
  ///
  /// In en, this message translates to:
  /// **'The rider declined your offer on this ride.'**
  String get errBidDeclinedBefore;

  /// Error text for API code TOO_MANY_BIDS
  ///
  /// In en, this message translates to:
  /// **'You made too many offers on this ride.'**
  String get errTooManyBids;

  /// Error text for API code COUNTER_TOO_LOW
  ///
  /// In en, this message translates to:
  /// **'Your price must be higher than the rider’s offer.'**
  String get errCounterTooLow;

  /// Error text for API code COUNTER_TOO_HIGH
  ///
  /// In en, this message translates to:
  /// **'Your price is too high for this trip.'**
  String get errCounterTooHigh;

  /// Error text for API code TOO_FAR
  ///
  /// In en, this message translates to:
  /// **'You are too far from the pickup point.'**
  String get errTooFar;

  /// Error text for API code SUBSCRIPTION_REQUIRED
  ///
  /// In en, this message translates to:
  /// **'You reached the free rides for today. Subscribe to continue.'**
  String get errSubscriptionRequired;

  /// Error text for API code DRIVER_NOT_APPROVED
  ///
  /// In en, this message translates to:
  /// **'Your driver account is not approved yet.'**
  String get errDriverNotApproved;

  /// Error text for API code DRIVER_BLOCKED
  ///
  /// In en, this message translates to:
  /// **'You are paused for a while because of cancellations.'**
  String get errDriverBlocked;

  /// Error text for API code DRIVER_OFFLINE
  ///
  /// In en, this message translates to:
  /// **'Go online first.'**
  String get errDriverOffline;

  /// Error text for API code DOCUMENTS_INVALID
  ///
  /// In en, this message translates to:
  /// **'A document is missing, expired or not approved yet.'**
  String get errDocumentsInvalid;

  /// Error text for API code DOCUMENTS_MISSING
  ///
  /// In en, this message translates to:
  /// **'Some documents are missing.'**
  String get errDocumentsMissing;

  /// Error text for API code DOCUMENT_EXPIRED
  ///
  /// In en, this message translates to:
  /// **'This document has expired.'**
  String get errDocumentExpired;

  /// Error text for API code PROFILE_INCOMPLETE
  ///
  /// In en, this message translates to:
  /// **'Please complete your information first.'**
  String get errProfileIncomplete;

  /// Error text for API code VEHICLE_MISSING
  ///
  /// In en, this message translates to:
  /// **'Please add your car first.'**
  String get errVehicleMissing;

  /// Error text for API code PROFILE_LOCKED
  ///
  /// In en, this message translates to:
  /// **'Your profile is under review and cannot be changed now.'**
  String get errProfileLocked;

  /// Error text for API code ALREADY_SUBMITTED
  ///
  /// In en, this message translates to:
  /// **'Your application was already sent.'**
  String get errAlreadySubmitted;

  /// Error text for API code DRIVER_TYPE_DISABLED
  ///
  /// In en, this message translates to:
  /// **'This type of driver is not open in your city yet.'**
  String get errDriverTypeDisabled;

  /// Error text for API code LICENCE_TOO_RECENT
  ///
  /// In en, this message translates to:
  /// **'Your licence must be at least 3 years old.'**
  String get errLicenceTooRecent;

  /// Error text for API code CAR_TOO_OLD
  ///
  /// In en, this message translates to:
  /// **'The car is too old.'**
  String get errCarTooOld;

  /// Error text for API code CAR_DOORS
  ///
  /// In en, this message translates to:
  /// **'The car must have 4 doors.'**
  String get errCarDoors;

  /// Error text for API code CAR_NO_AC
  ///
  /// In en, this message translates to:
  /// **'The car must have air conditioning.'**
  String get errCarNoAc;

  /// Error text for API code EXPIRY_REQUIRED
  ///
  /// In en, this message translates to:
  /// **'Please enter the expiry date.'**
  String get errExpiryRequired;

  /// Error text for API code FILE_TYPE
  ///
  /// In en, this message translates to:
  /// **'Send a photo (JPEG, PNG) or a PDF.'**
  String get errFileType;

  /// Error text for API code FILE_REQUIRED
  ///
  /// In en, this message translates to:
  /// **'Please choose a file.'**
  String get errFileRequired;

  /// Error text for API code MOCK_LOCATION
  ///
  /// In en, this message translates to:
  /// **'Turn off fake GPS to continue.'**
  String get errMockLocation;

  /// Error text for API code ROOTED_DEVICE
  ///
  /// In en, this message translates to:
  /// **'This phone cannot be used to drive.'**
  String get errRootedDevice;

  /// Error text for API code INTEGRITY_FAILED
  ///
  /// In en, this message translates to:
  /// **'We could not check this phone. Use the app from the official store or our website.'**
  String get errIntegrityFailed;

  /// Error text for API code SELFIE_REQUIRED
  ///
  /// In en, this message translates to:
  /// **'Please take a selfie before going online.'**
  String get errSelfieRequired;

  /// Error text for API code PIN_INVALID
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. Ask the rider again.'**
  String get errPinInvalid;

  /// Error text for API code PIN_LOCKED
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs. Our team was alerted.'**
  String get errPinLocked;

  /// Error text for API code ACTIVE_RIDE
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel your current ride first.'**
  String get errActiveRide;

  /// Error text for API code FEATURE_DISABLED
  ///
  /// In en, this message translates to:
  /// **'This feature is turned off for now.'**
  String get errFeatureDisabled;

  /// Error text for API code SOS_NOT_FOUND
  ///
  /// In en, this message translates to:
  /// **'This alert is closed.'**
  String get errSosNotFound;

  /// Error text for API code SHARE_NOT_FOUND
  ///
  /// In en, this message translates to:
  /// **'This link expired.'**
  String get errShareNotFound;

  /// Error text for API code TOO_MANY_PENDING
  ///
  /// In en, this message translates to:
  /// **'You already have pending requests. Wait for the answer.'**
  String get errTooManyPending;

  /// Error text for API code REQUEST_IN_PROGRESS
  ///
  /// In en, this message translates to:
  /// **'Still working on it. Try again in a moment.'**
  String get errRequestInProgress;

  /// Error text for API code IDEMPOTENCY_KEY_REUSED
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errIdempotencyKeyReused;

  /// Error text for API code NOT_FOUND
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get errNotFound;

  /// Error text for API code CITY_INACTIVE
  ///
  /// In en, this message translates to:
  /// **'The service is not open in this city yet.'**
  String get errCityInactive;

  /// Error text for API code NOT_A_DRIVER
  ///
  /// In en, this message translates to:
  /// **'This is not a driver account.'**
  String get errNotADriver;

  /// Trust badge on the driver card: the driver's identity and car documents were checked and approved (D63).
  ///
  /// In en, this message translates to:
  /// **'Documents checked by RideMA'**
  String get checkedByRideMA;

  /// No description provided for @checkIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get checkIdentity;

  /// No description provided for @checkCar.
  ///
  /// In en, this message translates to:
  /// **'Car papers'**
  String get checkCar;

  /// Heading of the reason chips after a 4–5 star rating (D64).
  ///
  /// In en, this message translates to:
  /// **'What went well?'**
  String get rateGoodTitle;

  /// Heading of the reason chips after a 1–3 star rating (D64).
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get rateBadTitle;

  /// No description provided for @rateReasonsPrivate.
  ///
  /// In en, this message translates to:
  /// **'Optional. The other person never sees your choices; our team uses them to improve rides.'**
  String get rateReasonsPrivate;

  /// No description provided for @rrDriverSafeDriving.
  ///
  /// In en, this message translates to:
  /// **'Safe driving'**
  String get rrDriverSafeDriving;

  /// No description provided for @rrDriverPolite.
  ///
  /// In en, this message translates to:
  /// **'Polite and friendly'**
  String get rrDriverPolite;

  /// No description provided for @rrDriverCleanCar.
  ///
  /// In en, this message translates to:
  /// **'Clean car'**
  String get rrDriverCleanCar;

  /// No description provided for @rrDriverKnewTheWay.
  ///
  /// In en, this message translates to:
  /// **'Knew the way'**
  String get rrDriverKnewTheWay;

  /// No description provided for @rrDriverOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get rrDriverOnTime;

  /// No description provided for @rrDriverUnsafeDriving.
  ///
  /// In en, this message translates to:
  /// **'Unsafe driving'**
  String get rrDriverUnsafeDriving;

  /// No description provided for @rrDriverRude.
  ///
  /// In en, this message translates to:
  /// **'Rude'**
  String get rrDriverRude;

  /// No description provided for @rrDriverDirtyCar.
  ///
  /// In en, this message translates to:
  /// **'Dirty car'**
  String get rrDriverDirtyCar;

  /// No description provided for @rrDriverWrongRoute.
  ///
  /// In en, this message translates to:
  /// **'Long or wrong route'**
  String get rrDriverWrongRoute;

  /// No description provided for @rrDriverLate.
  ///
  /// In en, this message translates to:
  /// **'Arrived late'**
  String get rrDriverLate;

  /// No description provided for @rrDriverAskedMoreMoney.
  ///
  /// In en, this message translates to:
  /// **'Asked for more money'**
  String get rrDriverAskedMoreMoney;

  /// No description provided for @rrDriverCarMismatch.
  ///
  /// In en, this message translates to:
  /// **'Different car or plate'**
  String get rrDriverCarMismatch;

  /// No description provided for @rrRiderPolite.
  ///
  /// In en, this message translates to:
  /// **'Polite and friendly'**
  String get rrRiderPolite;

  /// No description provided for @rrRiderOnTime.
  ///
  /// In en, this message translates to:
  /// **'Ready on time'**
  String get rrRiderOnTime;

  /// No description provided for @rrRiderExactPickup.
  ///
  /// In en, this message translates to:
  /// **'Easy to find'**
  String get rrRiderExactPickup;

  /// No description provided for @rrRiderRespectful.
  ///
  /// In en, this message translates to:
  /// **'Respected the car'**
  String get rrRiderRespectful;

  /// No description provided for @rrRiderLate.
  ///
  /// In en, this message translates to:
  /// **'Kept me waiting'**
  String get rrRiderLate;

  /// No description provided for @rrRiderRude.
  ///
  /// In en, this message translates to:
  /// **'Rude'**
  String get rrRiderRude;

  /// No description provided for @rrRiderWrongPickup.
  ///
  /// In en, this message translates to:
  /// **'Wrong pickup point'**
  String get rrRiderWrongPickup;

  /// No description provided for @rrRiderMessy.
  ///
  /// In en, this message translates to:
  /// **'Left the car dirty'**
  String get rrRiderMessy;

  /// No description provided for @rrRiderPaymentProblem.
  ///
  /// In en, this message translates to:
  /// **'Payment problem'**
  String get rrRiderPaymentProblem;

  /// Error text for API code RATING_REASON_INVALID
  ///
  /// In en, this message translates to:
  /// **'These reasons don’t match your stars. Please choose again.'**
  String get errRatingReasonInvalid;

  /// Error text for API code ETA_TOO_SHORT
  ///
  /// In en, this message translates to:
  /// **'You are farther than that. Choose a longer arrival time.'**
  String get errEtaTooShort;

  /// On a driver offer: the arrival time the driver promised (D66).
  ///
  /// In en, this message translates to:
  /// **'Promises {minutes} min'**
  String offerEtaPromised(int minutes);

  /// Rider driver card: time by which the driver promised to be at the pickup (D66).
  ///
  /// In en, this message translates to:
  /// **'Promised arrival: {time}'**
  String driverDueBy(String time);

  /// No description provided for @reasonDriverLate.
  ///
  /// In en, this message translates to:
  /// **'The driver is late'**
  String get reasonDriverLate;

  /// Error text for API code DRIVER_NOT_LATE
  ///
  /// In en, this message translates to:
  /// **'Your driver is not late yet. You can still cancel with another reason.'**
  String get errDriverNotLate;

  /// Countdown of the free wait at the pickup (D70).
  ///
  /// In en, this message translates to:
  /// **'Free waiting: {time} left'**
  String waitFreeLeft(String time);

  /// Paid waiting so far (D70).
  ///
  /// In en, this message translates to:
  /// **'Waiting fee: {amount} DH so far ({perMin} DH/min, max {max} DH)'**
  String waitFeeSoFar(int amount, int perMin, int max);

  /// No description provided for @waitRulesInfo.
  ///
  /// In en, this message translates to:
  /// **'{free} min of free waiting, then {perMin} DH per minute (max {max} DH), added to the cash fare.'**
  String waitRulesInfo(int free, int perMin, int max);

  /// No description provided for @receiptFare.
  ///
  /// In en, this message translates to:
  /// **'Agreed fare'**
  String get receiptFare;

  /// No description provided for @receiptWaitingFee.
  ///
  /// In en, this message translates to:
  /// **'Waiting fee ({minutes} min)'**
  String receiptWaitingFee(int minutes);

  /// No description provided for @emergencyContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts'**
  String get emergencyContactsTitle;

  /// Saved emergency contacts screen (D71).
  ///
  /// In en, this message translates to:
  /// **'If you press SOS during a ride, we send these people a link to follow your trip live. Up to {max} contacts.'**
  String emergencyContactsInfo(int max);

  /// No description provided for @emergencyContactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No emergency contact yet.'**
  String get emergencyContactsEmpty;

  /// No description provided for @emergencyContactAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a contact'**
  String get emergencyContactAdd;

  /// No description provided for @emergencyContactName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get emergencyContactName;

  /// No description provided for @emergencyContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get emergencyContactPhone;

  /// No description provided for @emergencyContactRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get emergencyContactRemove;

  /// No description provided for @sosContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your emergency contacts'**
  String get sosContactsTitle;

  /// No description provided for @sosContactSending.
  ///
  /// In en, this message translates to:
  /// **'Sending your live trip…'**
  String get sosContactSending;

  /// No description provided for @sosContactSent.
  ///
  /// In en, this message translates to:
  /// **'Live trip link sent'**
  String get sosContactSent;

  /// No description provided for @sosContactNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not reached yet. Our team has your alert.'**
  String get sosContactNotSent;

  /// Error text for API code EMERGENCY_CONTACTS_LIMIT
  ///
  /// In en, this message translates to:
  /// **'You can save up to 5 emergency contacts.'**
  String get errEmergencyContactsLimit;

  /// Error text for API code EMERGENCY_CONTACT_EXISTS
  ///
  /// In en, this message translates to:
  /// **'This number is already in your emergency contacts.'**
  String get errEmergencyContactExists;

  /// Error text for API code EMERGENCY_CONTACT_SELF
  ///
  /// In en, this message translates to:
  /// **'Add someone else, not your own number.'**
  String get errEmergencyContactSelf;

  /// Error text for API code CONTACT_NOT_FOUND
  ///
  /// In en, this message translates to:
  /// **'This contact no longer exists.'**
  String get errContactNotFound;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatTitle;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get chatHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Tap a quick reply or write below.'**
  String get chatEmpty;

  /// No description provided for @chatClosed.
  ///
  /// In en, this message translates to:
  /// **'Messages are closed: this ride is over.'**
  String get chatClosed;

  /// No description provided for @chatFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent. Tap to try again.'**
  String get chatFailed;

  /// No description provided for @chatPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Messages are kept with the trip. Our team reads them only if there is a problem. Never share your phone number.'**
  String get chatPrivacy;

  /// No description provided for @messageButton.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageButton;

  /// No description provided for @chatNewFrom.
  ///
  /// In en, this message translates to:
  /// **'New message from {name}'**
  String chatNewFrom(String name);

  /// No description provided for @chatOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get chatOpen;

  /// No description provided for @chatQuickComing.
  ///
  /// In en, this message translates to:
  /// **'I’m coming'**
  String get chatQuickComing;

  /// No description provided for @chatQuickAtPickup.
  ///
  /// In en, this message translates to:
  /// **'I’m at the pickup point'**
  String get chatQuickAtPickup;

  /// No description provided for @chatQuickWaitPlease.
  ///
  /// In en, this message translates to:
  /// **'Please wait 2 minutes'**
  String get chatQuickWaitPlease;

  /// No description provided for @chatQuickWhereAreYou.
  ///
  /// In en, this message translates to:
  /// **'Where are you?'**
  String get chatQuickWhereAreYou;

  /// No description provided for @chatQuickHere.
  ///
  /// In en, this message translates to:
  /// **'I’m here'**
  String get chatQuickHere;

  /// No description provided for @chatQuickOnMyWay.
  ///
  /// In en, this message translates to:
  /// **'On my way'**
  String get chatQuickOnMyWay;

  /// No description provided for @chatQuickTraffic.
  ///
  /// In en, this message translates to:
  /// **'Stuck in traffic, a few more minutes'**
  String get chatQuickTraffic;

  /// No description provided for @chatQuickCantFindYou.
  ///
  /// In en, this message translates to:
  /// **'I can’t find you. Where exactly are you?'**
  String get chatQuickCantFindYou;

  /// Error text for API code CHAT_CLOSED
  ///
  /// In en, this message translates to:
  /// **'Messages are open only during the ride.'**
  String get errChatClosed;

  /// No description provided for @callRingFromDriver.
  ///
  /// In en, this message translates to:
  /// **'Your driver is calling you in RideMA'**
  String get callRingFromDriver;

  /// No description provided for @callRingFromRider.
  ///
  /// In en, this message translates to:
  /// **'Your rider is calling you in RideMA'**
  String get callRingFromRider;

  /// Error text for API code ON_ANOTHER_RIDE
  ///
  /// In en, this message translates to:
  /// **'You are on a ride. Finish it before making a new offer.'**
  String get errOnAnotherRide;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
