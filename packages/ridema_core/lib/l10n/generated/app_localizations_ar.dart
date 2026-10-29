// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get ok => 'حسنًا';

  @override
  String get cancel => 'إلغاء';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get save => 'حفظ';

  @override
  String get close => 'إغلاق';

  @override
  String get back => 'رجوع';

  @override
  String get next => 'التالي';

  @override
  String get done => 'تم';

  @override
  String get send => 'إرسال';

  @override
  String get confirm => 'تأكيد';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get read => 'قراءة';

  @override
  String get copy => 'نسخ';

  @override
  String get copied => 'تم النسخ';

  @override
  String get share => 'مشاركة';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get required => 'مطلوب';

  @override
  String get optional => 'اختياري';

  @override
  String priceDh(int amount) {
    return '$amount درهم';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes د';
  }

  @override
  String kmShort(String km) {
    return '$km كلم';
  }

  @override
  String ratingWithCount(int count, String rating) {
    return '$rating ★ ($count)';
  }

  @override
  String tripsCount(int count) {
    return '$count رحلة';
  }

  @override
  String get newRating => 'جديد';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get dateLabel => 'التاريخ';

  @override
  String get noConnectionBanner => 'لا يوجد اتصال بالإنترنت. نواصل المحاولة…';

  @override
  String get languageTitle => 'اختر لغتك';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get languageChangeLater => 'يمكنك تغييرها لاحقًا من الملف الشخصي.';

  @override
  String get bootLoading => 'جارٍ التشغيل…';

  @override
  String bootOffline(String app) {
    return 'تعذّر الاتصال بـ $app. تحقّق من اتصالك بالإنترنت.';
  }

  @override
  String get updateTitle => 'التحديث ضروري';

  @override
  String updateBody(String app, String version) {
    return 'هذا الإصدار من $app قديم. ثبّت الإصدار $version للمتابعة.';
  }

  @override
  String get updateDownload => 'تنزيل التحديث';

  @override
  String updateDownloading(int percent) {
    return 'جارٍ التنزيل… $percent٪';
  }

  @override
  String get updateInstall => 'تثبيت';

  @override
  String get updateOpenStore => 'فتح المتجر';

  @override
  String updateAllowInstall(String app) {
    return 'سيطلب منك أندرويد السماح بتثبيت التطبيقات من $app. اسمح بذلك، ثم ارجع واضغط على «تثبيت».';
  }

  @override
  String get updateFailed => 'فشل التنزيل. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String get updateAvailable => 'يتوفر إصدار جديد.';

  @override
  String get updateNoLink => 'اطلب الإصدار الجديد من الدعم.';

  @override
  String welcomeTitle(String app) {
    return 'مرحبًا بك في $app';
  }

  @override
  String get welcomeRiderTagline =>
      'أنت تقترح السعر، والسائقون القريبون يردّون.';

  @override
  String get welcomeDriverTagline =>
      'استقبل رحلات بالقرب منك. اقبل السعر أو اقترح سعرك. بدون عمولة.';

  @override
  String get welcomeSignUp => 'إنشاء حساب';

  @override
  String get welcomeLogIn => 'لدي حساب بالفعل';

  @override
  String get welcomeCash => 'الدفع نقدًا مباشرة للسائق.';

  @override
  String get signUpTitle => 'أنشئ حسابك';

  @override
  String get fullNameLabel => 'الاسم الكامل';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get passwordHint => '10 أحرف على الأقل';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get errorNameShort => 'أدخل اسمك الكامل.';

  @override
  String get errorEmailInvalid => 'عنوان البريد الإلكتروني غير صالح.';

  @override
  String get errorPasswordShort => 'استخدم 10 أحرف على الأقل.';

  @override
  String get errorPasswordMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get errorCodeFormat => 'أدخل الأرقام الستة.';

  @override
  String get consentsTitle => 'قبل أن تبدأ';

  @override
  String get consentsIntro =>
      'يرجى قراءة كل بند والموافقة عليه. اضغط على «قراءة» لعرض النص الكامل.';

  @override
  String get consentTerms => 'أوافق على شروط الاستخدام';

  @override
  String get consentPrivacy => 'أوافق على سياسة الخصوصية';

  @override
  String get consentDataTransfer =>
      'أوافق على معالجة بعض بياناتي من طرف خدمات توجد خارج المغرب';

  @override
  String get consentDataTransferExplain =>
      'تعرض خرائط Google الخريطة، ويرسل Firebase (Google) الإشعارات، ويرسل واتساب (Meta) رمز الهاتف. قد تحفظ هذه الشركات البيانات خارج المغرب. لا يمكن للتطبيق أن يعمل بدونها.';

  @override
  String consentBackgroundLocation(String app) {
    return 'أوافق على أن يستخدم $app موقعي في الخلفية عندما أكون متصلًا';
  }

  @override
  String get consentBackgroundExplain =>
      'يمكن للركاب القريبين العثور عليك وتتبع الرحلة حتى عندما يكون التطبيق مغلقًا. عند انتقالك إلى وضع غير متصل، نتوقف.';

  @override
  String get consentsAllRequired => 'جميع الخانات ضرورية لاستخدام التطبيق.';

  @override
  String get consentsAccept => 'الموافقة وإنشاء حسابي';

  @override
  String get consentsLoadFailed =>
      'تعذّر تحميل النصوص. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String consentVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get consentsOutdated => 'تم تحديث أحد النصوص. يرجى قراءته من جديد.';

  @override
  String get verifyEmailTitle => 'تحقّق من بريدك الإلكتروني';

  @override
  String verifyEmailBody(String email) {
    return 'أرسلنا رمزًا من 6 أرقام إلى $email. أدخله أدناه أو اضغط على الرابط في الرسالة.';
  }

  @override
  String get verifyEmailSpam =>
      'لم يصلك؟ تحقّق من مجلد الرسائل غير المرغوب فيها.';

  @override
  String get codeLabel => 'رمز من 6 أرقام';

  @override
  String get verifyButton => 'تحقّق';

  @override
  String get resendCode => 'إرسال رمز جديد';

  @override
  String resendIn(int seconds) {
    return 'رمز جديد بعد $seconds ث';
  }

  @override
  String get codeSent => 'تم إرسال رمز جديد.';

  @override
  String get emailVerified => 'تم تأكيد البريد الإلكتروني';

  @override
  String get iVerifiedWithLink => 'استخدمت الرابط في الرسالة';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginButton => 'دخول';

  @override
  String get forgotPasswordLink => 'نسيت كلمة المرور؟';

  @override
  String get noAccountLink => 'ليس لديك حساب؟ أنشئ حسابًا';

  @override
  String wrongAppRider(String app) {
    return 'هذا حساب سائق. استخدم تطبيق $app للسائقين.';
  }

  @override
  String get wrongAppDriver =>
      'هذا حساب راكب. أنشئ حساب سائق ببريد إلكتروني آخر.';

  @override
  String get twoFactorTitle => 'رمز الأمان';

  @override
  String get twoFactorEmailBody =>
      'أرسلنا رمزًا إلى بريدك الإلكتروني. أدخله أدناه.';

  @override
  String twoFactorTotpBody(String app) {
    return 'افتح تطبيق المصادقة وأدخل الرمز المكوّن من 6 أرقام الخاص بـ $app.';
  }

  @override
  String get forgotTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotBody =>
      'أدخل بريدك الإلكتروني. إذا كان هناك حساب، سنرسل إليك رمزًا.';

  @override
  String get forgotSend => 'إرسال الرمز';

  @override
  String get resetTitle => 'اختر كلمة مرور جديدة';

  @override
  String resetBody(String email) {
    return 'أدخل الرمز المرسل إلى $email وكلمة المرور الجديدة.';
  }

  @override
  String get newPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get resetDone => 'تم تغيير كلمة المرور. يمكنك تسجيل الدخول الآن.';

  @override
  String get resetButton => 'تغيير كلمة المرور';

  @override
  String get verifyPhoneTitle => 'تأكيد رقم هاتفك';

  @override
  String get verifyPhoneBody => 'سنرسل رمزًا عبر واتساب إلى هذا الرقم.';

  @override
  String get verifyPhoneWhyRider => 'نحتاج إلى رقم مؤكَّد قبل رحلتك الأولى.';

  @override
  String get verifyPhoneWhyDriver => 'نحتاج إلى رقم مؤكَّد قبل أن تصبح متصلًا.';

  @override
  String get phoneLabel => 'رقم الهاتف';

  @override
  String get phoneHint => '6XXXXXXXX';

  @override
  String get errorPhoneInvalid =>
      'أدخل الأرقام التسعة بعد ‎+212‎ (مثلًا 612345678).';

  @override
  String get phoneCodesLimit =>
      'يمكنك طلب 3 رموز كحد أقصى في اليوم لنفس الرقم. كل رمز صالح لمدة 10 دقائق. يجب أن يكون الرقم مفعّلًا على واتساب.';

  @override
  String get sendCodeWhatsapp => 'إرسال الرمز عبر واتساب';

  @override
  String phoneCodeSentTo(String phone) {
    return 'تم إرسال الرمز عبر واتساب إلى $phone.';
  }

  @override
  String get changeNumber => 'تغيير الرقم';

  @override
  String get phoneVerified => 'تم تأكيد الهاتف';

  @override
  String get phonePrivacy => 'يبقى رقمك خاصًا: تتم المكالمات عبر التطبيق.';

  @override
  String get phoneChangeHint =>
      'لتغيير رقم مؤكَّد، أرسل طلب تصحيح من الملف الشخصي › بياناتي.';

  @override
  String get locationTitle => 'موقعك';

  @override
  String get locationRiderBody =>
      'نستخدم موقعك أثناء فتح التطبيق لتحديد نقطة انطلاقك.';

  @override
  String get locationRiderDetail =>
      'لا يرى السائق نقطة انطلاقك إلا أثناء الرحلة. يمكنك أيضًا كتابة عنوانك بدلًا من ذلك.';

  @override
  String locationDriverBody(String app) {
    return 'يستخدم $app موقعك حتى عندما يكون التطبيق مغلقًا أو غير مستخدم أثناء اتصالك، حتى يتمكن الركاب القريبون من العثور عليك وتتبع الرحلة.';
  }

  @override
  String get locationDriverDetail =>
      'عند انتقالك إلى وضع غير متصل، نتوقف عن استخدام موقعك. في الشاشة التالية اختر «السماح طوال الوقت».';

  @override
  String get locationDeniedRider =>
      'الموقع غير مفعّل. يمكنك كتابة عنوان الانطلاق.';

  @override
  String get locationNeededDriver => 'الموقع ضروري لتصبح متصلًا';

  @override
  String locationNeededDriverBody(String app) {
    return 'في الإعدادات، اجعل الموقع «مسموحًا طوال الوقت» لـ $app.';
  }

  @override
  String get locationServiceOff => 'خدمة الموقع (GPS) في هاتفك متوقفة.';

  @override
  String get turnOnLocation => 'تفعيل الموقع';

  @override
  String get allowLocation => 'السماح بالموقع';

  @override
  String get notifTitle => 'ابقَ على اطلاع';

  @override
  String get notifRiderBody =>
      'نُعلمك عندما يقدّم سائق عرضًا أو يصل، أو عندما تتغيّر رحلتك.';

  @override
  String get notifDriverBody =>
      'نُعلمك عند وصول طلب رحلة جديد بالقرب منك، حتى عندما يكون التطبيق في الخلفية.';

  @override
  String get notifAllow => 'السماح بالإشعارات';

  @override
  String get notifDeniedBanner => 'الإشعارات متوقفة. قد تفوتك عروض الرحلات.';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileName => 'الاسم';

  @override
  String get profileEmail => 'البريد الإلكتروني';

  @override
  String get profilePhone => 'الهاتف';

  @override
  String get phoneNotVerified => 'غير مؤكَّد';

  @override
  String get phoneVerifiedBadge => 'مؤكَّد';

  @override
  String get verifyNow => 'تأكيد الآن';

  @override
  String get profileSecurity => 'تسجيل الدخول بخطوتين';

  @override
  String get profileChangePassword => 'تغيير كلمة المرور';

  @override
  String get profileMyData => 'بياناتي';

  @override
  String get profileDeleteAccount => 'حذف حسابي';

  @override
  String get profileLegal => 'المعلومات القانونية';

  @override
  String get profileTrips => 'رحلاتي';

  @override
  String profileAppVersion(String version) {
    return 'إصدار التطبيق $version';
  }

  @override
  String get profileRating => 'تقييمك';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutConfirm => 'هل تريد تسجيل الخروج؟';

  @override
  String get editName => 'تعديل اسمك';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get sessionEnded => 'انتهت جلستك. يرجى تسجيل الدخول من جديد.';

  @override
  String get twoFactorSettingsTitle => 'تسجيل الدخول بخطوتين';

  @override
  String get twoFactorExplain =>
      'بعد كلمة المرور نطلب رمزًا ثانيًا. حتى لو عرف شخص كلمة مرورك، لن يستطيع الدخول.';

  @override
  String get twoFactorOff => 'غير مفعّل';

  @override
  String get twoFactorEmail => 'رمز عبر البريد الإلكتروني';

  @override
  String get twoFactorTotp => 'تطبيق المصادقة';

  @override
  String twoFactorCurrent(String method) {
    return 'الحالي: $method';
  }

  @override
  String get twoFactorUseEmail => 'استخدام رموز البريد الإلكتروني';

  @override
  String get twoFactorUseTotp => 'استخدام تطبيق مصادقة';

  @override
  String get twoFactorTurnOff => 'إيقاف تسجيل الدخول بخطوتين';

  @override
  String get twoFactorTotpStep1 =>
      '1. أضف هذا المفتاح في تطبيق المصادقة (Google Authenticator أو Microsoft Authenticator…).';

  @override
  String get twoFactorSecret => 'المفتاح السري';

  @override
  String get twoFactorOpenApp => 'فتح في تطبيق المصادقة';

  @override
  String get twoFactorTotpStep2 =>
      '2. أدخل الرمز المكوّن من 6 أرقام الظاهر في التطبيق.';

  @override
  String get twoFactorEnabled => 'تم تفعيل تسجيل الدخول بخطوتين.';

  @override
  String get twoFactorDisabled => 'تم إيقاف تسجيل الدخول بخطوتين.';

  @override
  String get passwordConfirmPrompt => 'أدخل كلمة المرور للتأكيد.';

  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get currentPasswordLabel => 'كلمة المرور الحالية';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور.';

  @override
  String get myDataTitle => 'بياناتي';

  @override
  String get myDataIntro =>
      'وفقًا للقانون المغربي 09-08، يمكنك الحصول على نسخة من معطياتك الشخصية وطلب تصحيحها.';

  @override
  String get downloadMyData => 'تنزيل بياناتي';

  @override
  String get myDataReady => 'ملف بياناتك جاهز.';

  @override
  String get dataRequestsTitle => 'طلباتي';

  @override
  String get dataRequestsEmpty => 'لا توجد طلبات بعد.';

  @override
  String get newDataRequest => 'طلب جديد';

  @override
  String get dataRequestAccess => 'الاطلاع على بياناتي';

  @override
  String get dataRequestCorrection => 'تصحيح بياناتي';

  @override
  String get dataRequestDeletion => 'حذف بياناتي';

  @override
  String get dataRequestDetails => 'اشرح طلبك';

  @override
  String get dataRequestDetailsHint =>
      'مثلًا: اسمي مكتوب بشكل خاطئ، والصحيح هو…';

  @override
  String get dataRequestSent => 'تم إرسال الطلب. نجيب خلال 30 يومًا.';

  @override
  String get dataRequestOpen => 'قيد المعالجة';

  @override
  String get dataRequestDone => 'تمت المعالجة';

  @override
  String get dataRequestRejected => 'مرفوض';

  @override
  String dataRequestResponse(String text) {
    return 'الرد: $text';
  }

  @override
  String get deleteTitle => 'حذف حسابي';

  @override
  String get deleteIntro => 'يُحذف حسابك فورًا. لا يمكن التراجع عن ذلك.';

  @override
  String get deleteWhatGoes =>
      'يُحذف الآن: اسمك وبريدك الإلكتروني ورقم هاتفك وكلمة المرور والأجهزة والوثائق وعناوين الرحلات ونقاط GPS.';

  @override
  String get deleteWhatStays =>
      'يُحتفظ بها دون اسمك، طوال المدة التي يفرضها القانون: سجلات الرحلات (التاريخ والسعر) حتى تبقى الإيصالات والنزاعات صالحة.';

  @override
  String get deleteConfirmCheck => 'أفهم أنه لا يمكن التراجع عن ذلك';

  @override
  String get deleteButton => 'حذف حسابي';

  @override
  String get deleteDone => 'تم حذف حسابك.';

  @override
  String get legalTitle => 'المعلومات القانونية';

  @override
  String get legalTerms => 'شروط الاستخدام';

  @override
  String get legalPrivacy => 'سياسة الخصوصية';

  @override
  String get legalDataTransfer => 'نقل البيانات خارج المغرب';

  @override
  String get legalBackgroundLocation => 'الموقع في الخلفية';

  @override
  String get companyTitle => 'الشركة';

  @override
  String get companyName => 'الاسم';

  @override
  String get companyRc => 'السجل التجاري';

  @override
  String get companyIce => 'ICE';

  @override
  String get companyAddress => 'العنوان';

  @override
  String get supportPhone => 'هاتف الدعم';

  @override
  String get supportEmail => 'بريد الدعم';

  @override
  String get receiptTitle => 'الإيصال';

  @override
  String receiptNumber(String number) {
    return 'إيصال رقم $number';
  }

  @override
  String get receiptFrom => 'من';

  @override
  String get receiptTo => 'إلى';

  @override
  String get receiptDistance => 'المسافة';

  @override
  String get receiptDuration => 'المدة';

  @override
  String get receiptPrice => 'السعر';

  @override
  String get receiptDriver => 'السائق';

  @override
  String get receiptRider => 'الراكب';

  @override
  String get receiptVehicle => 'السيارة';

  @override
  String get receiptPaidCash => 'دُفع نقدًا للسائق';

  @override
  String receiptNoCommission(String app) {
    return 'لا يأخذ $app أي عمولة ولا يحصّل ثمن الرحلات.';
  }

  @override
  String get receiptShare => 'مشاركة الإيصال';

  @override
  String get tripHistoryTitle => 'رحلاتي';

  @override
  String get tripHistoryEmpty => 'لا توجد رحلات بعد.';

  @override
  String get loadMore => 'عرض المزيد';

  @override
  String get rideStatusSearching => 'جارٍ البحث عن سائق';

  @override
  String get rideStatusAccepted => 'السائق في الطريق';

  @override
  String get rideStatusArrived => 'وصل السائق';

  @override
  String get rideStatusInProgress => 'في الرحلة';

  @override
  String get rideStatusCompleted => 'مكتملة';

  @override
  String get rideStatusCancelled => 'ملغاة';

  @override
  String get rideStatusExpired => 'لم يُعثر على سائق';

  @override
  String get homeFrom => 'من';

  @override
  String get homeTo => 'إلى';

  @override
  String get homeCurrentLocation => 'موقعي الحالي';

  @override
  String get homeWhereTo => 'إلى أين تذهب؟';

  @override
  String get homeSearchAddress => 'ابحث عن عنوان';

  @override
  String get homePickOnMap => 'اختر على الخريطة';

  @override
  String get offerYourFare => 'اقترح سعرك';

  @override
  String suggestedPrice(int amount) {
    return 'السعر المقترح: $amount درهم';
  }

  @override
  String minOffer(int amount) {
    return 'الحد الأدنى: $amount درهم';
  }

  @override
  String get commentForDriver => 'ملاحظة للسائق (اختياري)';

  @override
  String get commentHint => 'مثلًا: معي حقيبة كبيرة';

  @override
  String get findDriver => 'ابحث عن سائق';

  @override
  String tripEstimate(String km, int minutes) {
    return '$km كلم · حوالي $minutes د';
  }

  @override
  String get searchingTitle => 'جارٍ البحث عن سائقين…';

  @override
  String searchingTimeLeft(String time) {
    return 'متبقٍّ $time';
  }

  @override
  String get raiseFare => 'رفع السعر';

  @override
  String get raiseFareTitle => 'ارفع سعرك';

  @override
  String get raiseFareHint => 'السعر الأعلى يجلب ردودًا أكثر. لا يمكنك تخفيضه.';

  @override
  String get cancelRequest => 'إلغاء الطلب';

  @override
  String get cancelRequestConfirm => 'هل تريد إلغاء طلبك؟';

  @override
  String get offersTitle => 'العروض';

  @override
  String get offerCounter => 'عرض مضاد';

  @override
  String offerEta(int minutes) {
    return 'على بعد $minutes د';
  }

  @override
  String get accept => 'قبول';

  @override
  String get decline => 'رفض';

  @override
  String get noOffersYet => 'في انتظار العروض. السائقون القريبون يرون طلبك.';

  @override
  String get requestExpiredTitle => 'لم يقبل أي سائق';

  @override
  String get requestExpiredBody => 'حاول مرة أخرى بسعر أعلى.';

  @override
  String get offerNoLongerAvailable => 'هذا العرض لم يعد متاحًا.';

  @override
  String get driverOnTheWay => 'سائقك في الطريق';

  @override
  String get driverArrivedTitle => 'سائقك وصل';

  @override
  String get onTripTitle => 'في الطريق إلى وجهتك';

  @override
  String etaMinutes(int minutes) {
    return 'يصل خلال $minutes د';
  }

  @override
  String get pickupPin => 'رمز الانطلاق';

  @override
  String get pickupPinHint => 'أعطِ هذا الرمز للسائق لبدء الرحلة.';

  @override
  String get callButton => 'اتصال';

  @override
  String get shareTrip => 'مشاركة الرحلة';

  @override
  String get sosButton => 'SOS';

  @override
  String get cancelRide => 'إلغاء';

  @override
  String get cancelFreeInfo => 'يمكنك الإلغاء مجانًا إلى أن يصل السائق.';

  @override
  String get cancelCountedWarning =>
      'لقد وصل السائق. إذا ألغيت الآن، سيُحتسب ذلك.';

  @override
  String get cancelReasonTitle => 'لماذا تلغي؟';

  @override
  String get reasonChangedMind => 'غيّرت رأيي';

  @override
  String get reasonDriverTooFar => 'السائق بعيد جدًا';

  @override
  String get reasonDriverAsked => 'طلب مني السائق الإلغاء';

  @override
  String get reasonWrongPickup => 'نقطة انطلاق خاطئة';

  @override
  String get reasonRiderNoShow => 'لم يحضر الراكب';

  @override
  String get reasonCarMismatch => 'السيارة لا تطابق';

  @override
  String get reasonSafety => 'لا أشعر بالأمان';

  @override
  String get reasonOther => 'سبب آخر';

  @override
  String get carMismatch => 'السيارة لا تطابق؟';

  @override
  String get carMismatchBody =>
      'إذا كانت اللوحة أو السيارة مختلفة، لا تركب. أبلغ عن ذلك: يمكنك بعدها الإلغاء مجانًا.';

  @override
  String get reportSent => 'شكرًا، تم إخطار فريقنا.';

  @override
  String get cancelWarningRecent =>
      'ألغيت عدة رحلات مؤخرًا. يرجى الحجز فقط عندما تكون مستعدًا.';

  @override
  String get rideCancelledByDriver =>
      'ألغى السائق الرحلة. يمكنك الطلب من جديد.';

  @override
  String get rideCancelledByRider => 'ألغى الراكب الرحلة.';

  @override
  String get rateDriver => 'كيف كان سائقك؟';

  @override
  String get rateRider => 'كيف كان الراكب؟';

  @override
  String get rateComment => 'تعليق (اختياري)';

  @override
  String get rateSubmit => 'إرسال التقييم';

  @override
  String get rateSkip => 'تخطّي';

  @override
  String fareToPay(int amount) {
    return 'الأجرة: $amount درهم. ادفع نقدًا للسائق.';
  }

  @override
  String get thanksRating => 'شكرًا!';

  @override
  String get idCheckRequiredBody =>
      'لأسباب أمنية، نحتاج إلى صورة بطاقة تعريفك قبل رحلتك القادمة.';

  @override
  String get shareTitle => 'شارك رحلتك';

  @override
  String get shareBody =>
      'أضف حتى 5 جهات اتصال. سيحصلون على رابط لتتبع رحلتك مباشرة حتى ساعة بعد انتهائها.';

  @override
  String get contactName => 'الاسم';

  @override
  String get contactPhone => 'الهاتف';

  @override
  String get addContact => 'إضافة جهة اتصال';

  @override
  String get shareCreate => 'إنشاء الرابط ومشاركته';

  @override
  String shareMessage(String app, String url) {
    return 'تابع رحلتي على $app مباشرة: $url';
  }

  @override
  String get shareMaxContacts => 'يمكنك إضافة 5 جهات اتصال كحد أقصى.';

  @override
  String get sosTitle => 'طوارئ';

  @override
  String sosBody(String app) {
    return 'اضغط على خدمة: يتصل هاتفك بها ويتلقى فريق $app موقعك مباشرة.';
  }

  @override
  String get sosPolice => 'الشرطة';

  @override
  String get sosGendarmerie => 'الدرك الملكي';

  @override
  String get sosAmbulance => 'الإسعاف';

  @override
  String get sosAlertSent => 'تم إرسال التنبيه. فريقنا يرى موقعك.';

  @override
  String get sosAlertFailed => 'تعذّر إرسال التنبيه. اتصل بالرقم مباشرة.';

  @override
  String get sosSharingLocation =>
      'تتم مشاركة موقعك كل 10 ثوانٍ ما دامت هذه الشاشة مفتوحة.';

  @override
  String get sosSending => 'جارٍ إرسال التنبيه…';

  @override
  String get callCalling => 'جارٍ الاتصال…';

  @override
  String get callRinging => 'يرن…';

  @override
  String get callIncoming => 'مكالمة واردة';

  @override
  String get callConnecting => 'جارٍ الربط…';

  @override
  String get callActive => 'في مكالمة';

  @override
  String get callEnded => 'انتهت المكالمة';

  @override
  String get callRejected => 'تم رفض المكالمة';

  @override
  String get callFailed => 'تعذّر إجراء المكالمة.';

  @override
  String get callMute => 'كتم';

  @override
  String get callUnmute => 'إلغاء الكتم';

  @override
  String get callSpeaker => 'مكبّر الصوت';

  @override
  String get callHangUp => 'إنهاء';

  @override
  String get callAnswer => 'رد';

  @override
  String get callDecline => 'رفض';

  @override
  String get callMicDenied => 'اسمح باستخدام الميكروفون لإجراء المكالمات.';

  @override
  String get callPrivacy => 'رقم هاتفك لا تتم مشاركته.';

  @override
  String get callYourDriver => 'سائقك';

  @override
  String get callYourRider => 'راكبك';

  @override
  String get plateLabel => 'اللوحة';

  @override
  String get carLabel => 'السيارة';

  @override
  String get colourLabel => 'اللون';

  @override
  String get goOnline => 'الاتصال';

  @override
  String get goOffline => 'قطع الاتصال';

  @override
  String get onlineLabel => 'متصل';

  @override
  String get offlineLabel => 'غير متصل';

  @override
  String onlineNotificationTitle(String app) {
    return '$app — أنت متصل';
  }

  @override
  String get onlineNotificationBody => 'تستقبل طلبات الرحلات القريبة منك.';

  @override
  String get offlineHint => 'اتصل لتستقبل طلبات الرحلات.';

  @override
  String get requestsTitle => 'طلبات الرحلات';

  @override
  String get noRequests => 'لا توجد طلبات حاليًا. ابقَ متصلًا.';

  @override
  String pickupDistance(String km, int minutes) {
    return '$km كلم حتى الراكب · $minutes د';
  }

  @override
  String tripDistance(String km) {
    return 'الرحلة: $km كلم';
  }

  @override
  String get pickupLabel => 'الانطلاق';

  @override
  String get destinationLabel => 'الوجهة';

  @override
  String get riderLabel => 'الراكب';

  @override
  String get riderComment => 'ملاحظة الراكب';

  @override
  String acceptFor(int amount) {
    return 'قبول مقابل $amount درهم';
  }

  @override
  String get proposePrice => 'أو اقترح سعرك';

  @override
  String counterPlus(int amount) {
    return '+$amount درهم';
  }

  @override
  String get otherAmount => 'مبلغ آخر';

  @override
  String counterOfferFor(int amount) {
    return 'اقتراح $amount درهم';
  }

  @override
  String counterMax(int amount) {
    return 'الحد الأقصى $amount درهم';
  }

  @override
  String waitingForRider(String time) {
    return 'في انتظار الراكب… $time';
  }

  @override
  String get withdraw => 'سحب عرضي';

  @override
  String get bidAccepted => 'قبل الراكب عرضك!';

  @override
  String get bidLost => 'اختار الراكب سائقًا آخر.';

  @override
  String get bidDeclined => 'رفض الراكب عرضك.';

  @override
  String get bidExpired => 'انتهت صلاحية عرضك.';

  @override
  String get bidOutdated => 'رفع الراكب السعر. قدّم عرضًا جديدًا.';

  @override
  String get requestClosedTaken => 'أخذ سائق آخر هذه الرحلة.';

  @override
  String get requestClosedGone => 'هذا الطلب لم يعد متاحًا.';

  @override
  String get navigate => 'الملاحة';

  @override
  String get goingToPickup => 'توجّه إلى نقطة الانطلاق';

  @override
  String get iveArrived => 'لقد وصلت';

  @override
  String get enterPinTitle => 'أدخل رمز الراكب';

  @override
  String get enterPinHint =>
      'اطلب من الراكب الرمز المكوّن من 4 أرقام الظاهر في تطبيقه.';

  @override
  String get startTrip => 'بدء الرحلة';

  @override
  String get riderNoShow => 'لم يحضر الراكب';

  @override
  String get riderNoShowInfo =>
      'بعد 5 دقائق من الانتظار يمكنك الإلغاء دون عقوبة.';

  @override
  String waitTime(String time) {
    return 'الانتظار: $time';
  }

  @override
  String get completeTrip => 'إنهاء الرحلة';

  @override
  String collectCash(int amount) {
    return 'استلم $amount درهم نقدًا';
  }

  @override
  String get driverCancelWarning =>
      'إذا ألغيت الآن، تحصل على نقطة عقوبة. كثرة الإلغاءات توقفك لفترة.';

  @override
  String blockedUntil(String time) {
    return 'أنت موقوف حتى $time بسبب الإلغاءات.';
  }

  @override
  String adminMessageTitle(String app) {
    return 'رسالة من $app';
  }

  @override
  String get earningsTitle => 'المداخيل';

  @override
  String get earningsToday => 'اليوم';

  @override
  String get earningsWeek => 'آخر 7 أيام';

  @override
  String earningsTrips(int count) {
    return '$count رحلة';
  }

  @override
  String earningsCash(int amount) {
    return '$amount درهم نقدًا';
  }

  @override
  String get earningsNoCommission => 'بدون عمولة: كل ما تحصّله لك.';

  @override
  String get documentsTitle => 'وثائقي';

  @override
  String get docCinFront => 'البطاقة الوطنية (الوجه)';

  @override
  String get docCinBack => 'البطاقة الوطنية (الظهر)';

  @override
  String get docLicence => 'رخصة السياقة';

  @override
  String get docCarteGrise => 'البطاقة الرمادية';

  @override
  String get docInsurance => 'التأمين';

  @override
  String get docVisiteTechnique => 'الفحص التقني';

  @override
  String get docSelfie => 'صورة شخصية';

  @override
  String get docStatusPending => 'قيد المراجعة';

  @override
  String get docStatusApproved => 'مقبول';

  @override
  String get docStatusRejected => 'مرفوض';

  @override
  String get docStatusExpired => 'منتهي الصلاحية';

  @override
  String get docStatusMissing => 'غير موجود';

  @override
  String docExpiresOn(String date) {
    return 'تنتهي صلاحيته في $date';
  }

  @override
  String docExpiringSoon(int days, String doc) {
    return 'تنتهي صلاحية $doc بعد $days يومًا. أرسل الوثيقة الجديدة الآن.';
  }

  @override
  String get docExpiredBlocked =>
      'انتهت صلاحية وثيقة. لا يمكنك الاتصال قبل إرسال وثيقة صالحة.';

  @override
  String get docUpload => 'إرسال';

  @override
  String get docReupload => 'إعادة الإرسال';

  @override
  String get docExpiryDate => 'تاريخ انتهاء الصلاحية';

  @override
  String docRejectReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get docTakePhoto => 'التقاط صورة';

  @override
  String get docChooseFile => 'اختيار ملف';

  @override
  String get docPhotoTips =>
      'ضع الوثيقة على طاولة في إضاءة جيدة. يجب أن تظهر الزوايا الأربع وأن يكون النص واضحًا.';

  @override
  String get docUploaded => 'تم إرسال الوثيقة للمراجعة.';

  @override
  String get onboardingTitle => 'كن سائقًا';

  @override
  String onboardingStep(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get driverTypeTitle => 'نوع السائق';

  @override
  String get driverTypeTaxi => 'سيارة أجرة';

  @override
  String get driverTypeLicensedOperator => 'ناقل مرخّص (VTC)';

  @override
  String get driverTypePrivateCar => 'سيارة خاصة';

  @override
  String get personalInfoTitle => 'معلوماتك';

  @override
  String get cinLast4Label => 'آخر 4 رموز من بطاقتك الوطنية';

  @override
  String get cinLast4Hint => 'نحتفظ بهذه الرموز فقط، وليس بالرقم الكامل.';

  @override
  String get licenceIssuedLabel => 'تاريخ إصدار رخصة السياقة';

  @override
  String get vehicleTitle => 'سيارتك';

  @override
  String get vehicleMake => 'العلامة';

  @override
  String get vehicleModel => 'الطراز';

  @override
  String get vehicleYear => 'السنة';

  @override
  String get vehicleColour => 'اللون';

  @override
  String get vehiclePlate => 'رقم اللوحة';

  @override
  String get vehicleDoors => 'عدد الأبواب';

  @override
  String get vehicleAc => 'مكيّف الهواء';

  @override
  String errorCarTooOld(int year) {
    return 'يجب أن تكون السيارة من سنة $year أو أحدث.';
  }

  @override
  String get errorCarDoors => 'يجب أن تحتوي السيارة على 4 أبواب.';

  @override
  String get errorCarNoAc => 'يجب أن تكون السيارة مكيّفة.';

  @override
  String get errorLicenceRecent => 'يجب أن يكون عمر رخصتك 3 سنوات على الأقل.';

  @override
  String get documentsStepTitle => 'وثائقك';

  @override
  String get submitForReview => 'إرسال للمراجعة';

  @override
  String get underReviewTitle => 'قيد المراجعة';

  @override
  String get underReviewBody =>
      'نحن نراجع وثائقك. سنُعلمك عادةً خلال يوم إلى يومي عمل.';

  @override
  String get rejectedTitle => 'لم يُقبل الطلب';

  @override
  String rejectedBody(String reason) {
    return 'السبب: $reason. صحّح ذلك وأعد الإرسال.';
  }

  @override
  String get suspendedTitle => 'الحساب موقوف';

  @override
  String get suspendedBody =>
      'حساب السائق الخاص بك موقوف. اتصل بالدعم لمعرفة المزيد.';

  @override
  String get approvedTitle => 'تم قبولك!';

  @override
  String batteryTitle(String app) {
    return 'إبقاء $app يعمل';
  }

  @override
  String get batteryIntro =>
      'بعض الهواتف تغلق التطبيقات في الخلفية لتوفير البطارية. اتبع هذه الخطوات مرة واحدة حتى لا تفوتك الطلبات أثناء اتصالك.';

  @override
  String get batteryChooseBrand => 'اختر علامة هاتفك';

  @override
  String get batteryOther => 'علامة أخرى';

  @override
  String batteryOpenSettings(String app) {
    return 'فتح إعدادات $app';
  }

  @override
  String get batteryNamesDiffer =>
      'قد تختلف الأسماء قليلًا حسب إصدار الهاتف. ابحث عن الأقرب.';

  @override
  String get batteryDone => 'قمت بذلك';

  @override
  String batteryXiaomi1(String app) {
    return 'اضغط مطولًا على أيقونة $app، ثم على «معلومات التطبيق» (ⓘ).';
  }

  @override
  String get batteryXiaomi2 => 'اضغط على «موفّر البطارية» واختر «بدون قيود».';

  @override
  String get batteryXiaomi3 => 'فعّل «التشغيل التلقائي».';

  @override
  String get batteryXiaomi4 =>
      'في «أذونات أخرى»، اسمح بـ«البدء في الخلفية» و«العرض على شاشة القفل».';

  @override
  String get batteryXiaomi5 =>
      'اضغط على «الأذونات» › «الموقع» › «السماح طوال الوقت».';

  @override
  String batteryXiaomi6(String app) {
    return 'افتح التطبيقات الأخيرة، واضغط مطولًا على بطاقة $app ثم على أيقونة القفل.';
  }

  @override
  String batteryTecno1(String app) {
    return 'اضغط مطولًا على أيقونة $app، ثم على «معلومات التطبيق».';
  }

  @override
  String get batteryTecno2 =>
      'اضغط على «البطارية» واختر «بدون قيود» (أو فعّل «السماح بالنشاط في الخلفية»).';

  @override
  String batteryTecno3(String app) {
    return 'في الإعدادات › إدارة التطبيقات › «التشغيل التلقائي»، فعّل $app.';
  }

  @override
  String batteryTecno4(String app) {
    return 'افتح «Phone Master» › «توفير الطاقة» وأزل $app من التطبيقات التي تُغلق تلقائيًا.';
  }

  @override
  String get batteryTecno5 =>
      'اضغط على «الأذونات» › «الموقع» › «السماح طوال الوقت».';

  @override
  String batteryTecno6(String app) {
    return 'افتح التطبيقات الأخيرة واسحب بطاقة $app إلى الأسفل (أو اضغط على القفل) لقفلها.';
  }

  @override
  String get batteryInfinix1 =>
      'افتح الإعدادات › «البطارية» › «تشغيل التطبيقات» (أو «إدارة التشغيل التلقائي»).';

  @override
  String batteryInfinix2(String app) {
    return 'ابحث عن $app، واختر «الإدارة يدويًا» ثم فعّل «التشغيل التلقائي» و«التشغيل الثانوي» و«التشغيل في الخلفية».';
  }

  @override
  String batteryInfinix3(String app) {
    return 'اضغط مطولًا على أيقونة $app › «معلومات التطبيق» › «البطارية» › «السماح بالنشاط في الخلفية».';
  }

  @override
  String batteryInfinix4(String app) {
    return 'في «Phone Master»، أوقف التنظيف التلقائي لـ $app.';
  }

  @override
  String get batteryInfinix5 =>
      'في «الأذونات» › «الموقع»، اختر «السماح طوال الوقت».';

  @override
  String batteryInfinix6(String app) {
    return 'افتح التطبيقات الأخيرة واقفل بطاقة $app.';
  }

  @override
  String batteryOppo1(String app) {
    return 'اضغط مطولًا على أيقونة $app، ثم على «معلومات التطبيق».';
  }

  @override
  String get batteryOppo2 =>
      'اضغط على «استهلاك البطارية» وفعّل «السماح بالنشاط في الخلفية» و«السماح بالنشاط في الواجهة» و«السماح بالتشغيل التلقائي».';

  @override
  String batteryOppo3(String app) {
    return 'في الهواتف القديمة: الإعدادات › «البطارية» › «إعدادات إضافية» › «تحسين استهلاك البطارية» › $app › «عدم التحسين».';
  }

  @override
  String get batteryOppo4 =>
      'اضغط على «الأذونات» › «الموقع» › «السماح طوال الوقت».';

  @override
  String batteryOppo5(String app) {
    return 'افتح التطبيقات الأخيرة، واضغط على القائمة ⋮ في بطاقة $app واختر «قفل».';
  }

  @override
  String batterySamsung1(String app) {
    return 'اضغط مطولًا على أيقونة $app، ثم على «معلومات التطبيق».';
  }

  @override
  String get batterySamsung2 => 'اضغط على «البطارية» واختر «غير مقيّد».';

  @override
  String get batterySamsung3 =>
      'اذهب إلى الإعدادات › «البطارية» (أو «العناية بالجهاز» › «البطارية») › «حدود الاستخدام في الخلفية».';

  @override
  String batterySamsung4(String app) {
    return 'تأكّد من أن $app ليس ضمن «التطبيقات الخاملة» أو «التطبيقات الخاملة بعمق»، وأضفه إلى «التطبيقات التي لا تخمل أبدًا».';
  }

  @override
  String get batterySamsung5 =>
      'في معلومات التطبيق › «الأذونات» › «الموقع»، اختر «السماح طوال الوقت».';

  @override
  String batteryGeneric1(String app) {
    return 'افتح الإعدادات › «التطبيقات» › $app (أو اضغط مطولًا على الأيقونة › «معلومات التطبيق»).';
  }

  @override
  String get batteryGeneric2 =>
      'في «البطارية»، اختر «غير مقيّد» أو «عدم التحسين»، أو اسمح بالنشاط في الخلفية.';

  @override
  String batteryGeneric3(String app) {
    return 'إذا وجدت «التشغيل التلقائي» أو «التشغيل عند بدء الجهاز»، فعّله لـ $app.';
  }

  @override
  String get batteryGeneric4 =>
      'في «الأذونات» › «الموقع»، اختر «السماح طوال الوقت».';

  @override
  String batteryGeneric5(String app) {
    return 'أثناء اتصالك، لا تغلق $app من قائمة التطبيقات الأخيرة.';
  }

  @override
  String get subscriptionTitle => 'الاشتراك';

  @override
  String subscriptionPrice(int amount, int days) {
    return '$amount درهم لمدة $days يومًا';
  }

  @override
  String subscriptionFreeRides(int count) {
    return '$count رحلات مجانية في اليوم';
  }

  @override
  String subscriptionRidesToday(int count, int limit) {
    return 'رحلات اليوم: $count / $limit';
  }

  @override
  String get subscriptionActive => 'اشتراكك مفعّل.';

  @override
  String get subscriptionInactive => 'لا يوجد اشتراك مفعّل.';

  @override
  String get subscriptionPayWith => 'الدفع عبر';

  @override
  String get payCashplus => 'نقدًا لدى CashPlus';

  @override
  String get payWafacash => 'نقدًا لدى Wafacash';

  @override
  String get payCard => 'بطاقة بنكية';

  @override
  String get payWallet => 'محفظة إلكترونية';

  @override
  String get payUnavailable => 'غير متاح بعد';

  @override
  String subscriptionCashCode(
    String agent,
    int amount,
    String code,
    int hours,
  ) {
    return 'توجّه إلى وكالة $agent وقدّم هذا الرمز: $code. المبلغ: $amount درهم. صالح لمدة $hours ساعة.';
  }

  @override
  String get subscriptionPending => 'الدفع قيد الانتظار';

  @override
  String get subscriptionOpenPayment => 'فتح صفحة الدفع';

  @override
  String get subscriptionOff =>
      'الاشتراك غير ضروري حاليًا. جميع الرحلات مجانية.';

  @override
  String get deviceMockTitle => 'أوقف GPS المزيّف';

  @override
  String get deviceMockBody =>
      'هناك تطبيق يزيّف موقعك مفعّل. أوقفه من «خيارات المطوّرين» ثم حاول مرة أخرى.';

  @override
  String get deviceRootedTitle => 'لا يمكن استخدام هذا الهاتف للعمل كسائق';

  @override
  String get deviceRootedBody =>
      'تم تعديل نظام هذا الهاتف (روت). من أجل سلامة الجميع، استخدم هاتفًا آخر.';

  @override
  String get deviceCheckAgain => 'إعادة الفحص';

  @override
  String get errNetworkError =>
      'لا يوجد اتصال بالإنترنت. تحقّق من الشبكة وحاول مرة أخرى.';

  @override
  String get errTimeout => 'الخادم يتأخر كثيرًا. حاول مرة أخرى.';

  @override
  String get errInternal => 'حدث خطأ من جهتنا. حاول مرة أخرى بعد قليل.';

  @override
  String get errRateLimited => 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.';

  @override
  String get errValidationError => 'بعض المعلومات ناقصة أو غير صحيحة.';

  @override
  String get errUpgradeRequired => 'يرجى تحديث التطبيق للمتابعة.';

  @override
  String get errAuthRequired => 'يرجى تسجيل الدخول.';

  @override
  String get errTokenInvalid => 'انتهت جلستك. يرجى تسجيل الدخول من جديد.';

  @override
  String get errSessionExpired => 'انتهت جلستك. يرجى تسجيل الدخول من جديد.';

  @override
  String get errRefreshInvalid => 'انتهت جلستك. يرجى تسجيل الدخول من جديد.';

  @override
  String get errRefreshReused =>
      'لسلامتك، تم تسجيل خروجك. يرجى تسجيل الدخول من جديد.';

  @override
  String get errSessionRevoked => 'انتهت جلستك. يرجى تسجيل الدخول من جديد.';

  @override
  String get errAccountDisabled => 'هذا الحساب موقوف. اتصل بالدعم.';

  @override
  String get errWrongRole => 'لا يمكن استخدام هذا الحساب في هذا التطبيق.';

  @override
  String get errInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errEmailNotVerified => 'يرجى تأكيد بريدك الإلكتروني أولًا.';

  @override
  String get errEmailTaken =>
      'هناك حساب يستخدم هذا البريد الإلكتروني. سجّل الدخول أو أعد تعيين كلمة المرور.';

  @override
  String get errLoginLocked =>
      'محاولات كثيرة. حاول بعد 15 دقيقة أو أعد تعيين كلمة المرور.';

  @override
  String get errMfaCodeInvalid => 'رمز خاطئ. تحقّق منه وحاول مرة أخرى.';

  @override
  String get errMfaLocked => 'رموز خاطئة كثيرة. حاول بعد 15 دقيقة.';

  @override
  String get errMfaTokenInvalid =>
      'انتهت صلاحية هذه الخطوة. سجّل الدخول من جديد.';

  @override
  String get errCodeInvalid => 'رمز خاطئ. تحقّق منه وحاول مرة أخرى.';

  @override
  String get errCodeExpired => 'انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.';

  @override
  String get errCodeTooManyAttempts =>
      'محاولات خاطئة كثيرة. اطلب رمزًا جديدًا.';

  @override
  String get errResendTooSoon => 'انتظر دقيقة قبل طلب رمز جديد.';

  @override
  String get errLinkInvalid =>
      'انتهت صلاحية هذا الرابط. اطلب رمزًا جديدًا من التطبيق.';

  @override
  String get errConsentRequired => 'يرجى الموافقة على جميع البنود المطلوبة.';

  @override
  String get errConsentOutdated => 'تم تحديث أحد النصوص. يرجى قراءته من جديد.';

  @override
  String get errPhoneAlreadyVerified =>
      'هاتفك مؤكَّد بالفعل. لتغييره، أرسل طلب تصحيح من الملف الشخصي › بياناتي.';

  @override
  String get errPhoneInUse => 'هذا الرقم مستخدم في حساب آخر.';

  @override
  String get errPhoneCodeLimit =>
      'وصلت إلى 3 رموز اليوم لهذا الرقم. حاول غدًا.';

  @override
  String get errOtpSendFailed =>
      'تعذّر إرسال رمز واتساب. تأكّد من أن الرقم مفعّل على واتساب وحاول مرة أخرى.';

  @override
  String get errPhoneNotVerified => 'يرجى تأكيد رقم هاتفك أولًا.';

  @override
  String get errIdCheckRequired =>
      'نحتاج إلى صورة بطاقتك الوطنية قبل رحلتك القادمة.';

  @override
  String get errOfferTooLow => 'سعرك منخفض جدًا لهذه الرحلة.';

  @override
  String get errOfferTooHigh => 'سعرك مرتفع جدًا لهذه الرحلة.';

  @override
  String get errOfferNotHigher => 'يجب أن يكون السعر الجديد أعلى من الحالي.';

  @override
  String get errRideAlreadyActive => 'لديك رحلة جارية بالفعل.';

  @override
  String get errOutOfServiceArea => 'هذا المكان خارج منطقة خدمتنا حاليًا.';

  @override
  String get errTripTooLong => 'هذه الرحلة طويلة جدًا بالنسبة للتطبيق.';

  @override
  String get errBidNotAvailable => 'هذا العرض لم يعد متاحًا.';

  @override
  String get errRideNotSearching => 'هذه الرحلة لم تعد تبحث عن سائق.';

  @override
  String get errDriverBusy => 'أخذ هذا السائق رحلة أخرى للتو. اختر عرضًا آخر.';

  @override
  String get errCannotCancel => 'لا يمكن إلغاء هذه الرحلة الآن.';

  @override
  String get errNoShowTooEarly =>
      'يمكنك استخدام «لم يحضر الراكب» بعد 5 دقائق من الانتظار.';

  @override
  String get errRideNotActive => 'هذه الرحلة لم تعد نشطة.';

  @override
  String get errRideNotFound => 'الرحلة غير موجودة.';

  @override
  String get errRideNotCompleted => 'يتوفر الإيصال بعد انتهاء الرحلة.';

  @override
  String get errAlreadyRated => 'لقد قيّمت هذه الرحلة من قبل.';

  @override
  String get errRatingWindowClosed => 'فات وقت تقييم هذه الرحلة.';

  @override
  String get errBidAlreadyActive => 'لقد قدّمت عرضًا على هذه الرحلة بالفعل.';

  @override
  String get errBidDeclinedBefore => 'رفض الراكب عرضك على هذه الرحلة.';

  @override
  String get errTooManyBids => 'قدّمت عروضًا كثيرة على هذه الرحلة.';

  @override
  String get errCounterTooLow => 'يجب أن يكون سعرك أعلى من عرض الراكب.';

  @override
  String get errCounterTooHigh => 'سعرك مرتفع جدًا لهذه الرحلة.';

  @override
  String get errTooFar => 'أنت بعيد جدًا عن نقطة الانطلاق.';

  @override
  String get errSubscriptionRequired =>
      'وصلت إلى عدد الرحلات المجانية لهذا اليوم. اشترك للمتابعة.';

  @override
  String get errDriverNotApproved => 'لم تتم الموافقة على حساب السائق بعد.';

  @override
  String get errDriverBlocked => 'أنت موقوف لفترة بسبب الإلغاءات.';

  @override
  String get errDriverOffline => 'اتصل أولًا.';

  @override
  String get errDocumentsInvalid =>
      'هناك وثيقة ناقصة أو منتهية الصلاحية أو غير مقبولة بعد.';

  @override
  String get errDocumentsMissing => 'بعض الوثائق ناقصة.';

  @override
  String get errDocumentExpired => 'انتهت صلاحية هذه الوثيقة.';

  @override
  String get errProfileIncomplete => 'يرجى إكمال معلوماتك أولًا.';

  @override
  String get errVehicleMissing => 'يرجى إضافة سيارتك أولًا.';

  @override
  String get errProfileLocked => 'ملفك قيد المراجعة ولا يمكن تعديله الآن.';

  @override
  String get errAlreadySubmitted => 'تم إرسال طلبك من قبل.';

  @override
  String get errDriverTypeDisabled =>
      'هذا النوع من السائقين غير متاح في مدينتك بعد.';

  @override
  String get errLicenceTooRecent => 'يجب أن يكون عمر رخصتك 3 سنوات على الأقل.';

  @override
  String get errCarTooOld => 'السيارة قديمة جدًا.';

  @override
  String get errCarDoors => 'يجب أن تحتوي السيارة على 4 أبواب.';

  @override
  String get errCarNoAc => 'يجب أن تكون السيارة مكيّفة.';

  @override
  String get errExpiryRequired => 'يرجى إدخال تاريخ انتهاء الصلاحية.';

  @override
  String get errFileType => 'أرسل صورة (JPEG أو PNG) أو ملف PDF.';

  @override
  String get errFileRequired => 'يرجى اختيار ملف.';

  @override
  String get errMockLocation => 'أوقف GPS المزيّف للمتابعة.';

  @override
  String get errRootedDevice => 'لا يمكن استخدام هذا الهاتف للعمل كسائق.';

  @override
  String get errIntegrityFailed =>
      'تعذّر فحص هذا الهاتف. استخدم التطبيق من المتجر الرسمي أو من موقعنا.';

  @override
  String get errSelfieRequired => 'يرجى التقاط صورة شخصية قبل الاتصال.';

  @override
  String get errPinInvalid => 'رمز خاطئ. اسأل الراكب مرة أخرى.';

  @override
  String get errPinLocked => 'رموز خاطئة كثيرة. تم إخطار فريقنا.';

  @override
  String get errActiveRide => 'أنهِ رحلتك الحالية أو ألغها أولًا.';

  @override
  String get errFeatureDisabled => 'هذه الميزة متوقفة حاليًا.';

  @override
  String get errSosNotFound => 'هذا التنبيه مغلق.';

  @override
  String get errShareNotFound => 'انتهت صلاحية هذا الرابط.';

  @override
  String get errTooManyPending => 'لديك طلبات قيد الانتظار. انتظر الرد.';

  @override
  String get errRequestInProgress => 'جارٍ المعالجة. حاول مرة أخرى بعد قليل.';

  @override
  String get errIdempotencyKeyReused => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get errNotFound => 'غير موجود.';

  @override
  String get errCityInactive => 'الخدمة غير متاحة في هذه المدينة بعد.';

  @override
  String get errNotADriver => 'هذا ليس حساب سائق.';

  @override
  String get checkedByRideMA => 'وثائق تحقّقت منها RideMA';

  @override
  String get checkIdentity => 'الهوية';

  @override
  String get checkCar => 'أوراق السيارة';

  @override
  String get rateGoodTitle => 'ما الذي كان جيدًا؟';

  @override
  String get rateBadTitle => 'ما الذي لم يكن جيدًا؟';

  @override
  String get rateReasonsPrivate =>
      'اختياري. لا يرى الطرف الآخر اختياراتك أبدًا؛ يستعملها فريقنا لتحسين الرحلات.';

  @override
  String get rrDriverSafeDriving => 'قيادة آمنة';

  @override
  String get rrDriverPolite => 'مهذّب ولطيف';

  @override
  String get rrDriverCleanCar => 'سيارة نظيفة';

  @override
  String get rrDriverKnewTheWay => 'يعرف الطريق';

  @override
  String get rrDriverOnTime => 'في الموعد';

  @override
  String get rrDriverUnsafeDriving => 'قيادة خطيرة';

  @override
  String get rrDriverRude => 'غير مهذّب';

  @override
  String get rrDriverDirtyCar => 'سيارة غير نظيفة';

  @override
  String get rrDriverWrongRoute => 'طريق طويل أو خاطئ';

  @override
  String get rrDriverLate => 'وصل متأخرًا';

  @override
  String get rrDriverAskedMoreMoney => 'طلب مالًا إضافيًا';

  @override
  String get rrDriverCarMismatch => 'سيارة أو لوحة مختلفة';

  @override
  String get rrRiderPolite => 'مهذّب ولطيف';

  @override
  String get rrRiderOnTime => 'جاهز في الموعد';

  @override
  String get rrRiderExactPickup => 'سهل العثور عليه';

  @override
  String get rrRiderRespectful => 'احترم السيارة';

  @override
  String get rrRiderLate => 'جعلني أنتظر';

  @override
  String get rrRiderRude => 'غير مهذّب';

  @override
  String get rrRiderWrongPickup => 'نقطة انطلاق خاطئة';

  @override
  String get rrRiderMessy => 'ترك السيارة متّسخة';

  @override
  String get rrRiderPaymentProblem => 'مشكلة في الدفع';

  @override
  String get errRatingReasonInvalid =>
      'هذه الأسباب لا تناسب تقييمك. اختر من جديد.';

  @override
  String get errEtaTooShort => 'أنت أبعد من ذلك. اختر مدة وصول أطول.';

  @override
  String offerEtaPromised(int minutes) {
    return 'يعد بـ $minutes د';
  }

  @override
  String driverDueBy(String time) {
    return 'الوصول الموعود: $time';
  }

  @override
  String get reasonDriverLate => 'السائق متأخر';

  @override
  String get errDriverNotLate =>
      'سائقك ليس متأخرًا بعد. يمكنك الإلغاء بسبب آخر.';

  @override
  String waitFreeLeft(String time) {
    return 'الانتظار المجاني: بقي $time';
  }

  @override
  String waitFeeSoFar(int amount, int perMin, int max) {
    return 'رسوم الانتظار: $amount درهم حتى الآن ($perMin درهم/د، بحد أقصى $max درهم)';
  }

  @override
  String waitRulesInfo(int free, int perMin, int max) {
    return '$free د انتظار مجاني، ثم $perMin درهم للدقيقة (بحد أقصى $max درهم)، تُضاف إلى السعر نقدًا.';
  }

  @override
  String get receiptFare => 'السعر المتفق عليه';

  @override
  String receiptWaitingFee(int minutes) {
    return 'رسوم الانتظار ($minutes د)';
  }

  @override
  String get emergencyContactsTitle => 'جهات الاتصال للطوارئ';

  @override
  String emergencyContactsInfo(int max) {
    return 'إذا ضغطت على زر الطوارئ أثناء رحلة، نرسل لهؤلاء الأشخاص رابطًا لمتابعة رحلتك مباشرة. حتى $max جهات اتصال.';
  }

  @override
  String get emergencyContactsEmpty => 'لا توجد جهة اتصال للطوارئ بعد.';

  @override
  String get emergencyContactAdd => 'إضافة جهة اتصال';

  @override
  String get emergencyContactName => 'الاسم';

  @override
  String get emergencyContactPhone => 'رقم الهاتف';

  @override
  String get emergencyContactRemove => 'حذف';

  @override
  String get sosContactsTitle => 'جهات اتصالك للطوارئ';

  @override
  String get sosContactSending => 'جارٍ إرسال رحلتك المباشرة…';

  @override
  String get sosContactSent => 'تم إرسال رابط الرحلة';

  @override
  String get sosContactNotSent => 'لم يتم الوصول إليه بعد. فريقنا لديه تنبيهك.';

  @override
  String get errEmergencyContactsLimit =>
      'يمكنك حفظ 5 جهات اتصال للطوارئ كحد أقصى.';

  @override
  String get errEmergencyContactExists =>
      'هذا الرقم موجود بالفعل في جهات اتصال الطوارئ.';

  @override
  String get errEmergencyContactSelf => 'أضف شخصًا آخر، وليس رقمك.';

  @override
  String get errContactNotFound => 'جهة الاتصال هذه لم تعد موجودة.';

  @override
  String get chatTitle => 'الرسائل';

  @override
  String get chatHint => 'اكتب رسالة';

  @override
  String get chatSend => 'إرسال';

  @override
  String get chatEmpty =>
      'لا توجد رسائل بعد. اضغط على رد سريع أو اكتب في الأسفل.';

  @override
  String get chatClosed => 'الرسائل مغلقة: انتهت هذه الرحلة.';

  @override
  String get chatFailed => 'لم تُرسل. اضغط للمحاولة مجددًا.';

  @override
  String get chatPrivacy =>
      'تُحفظ الرسائل مع الرحلة. لا يقرأها فريقنا إلا عند وجود مشكلة. لا تشارك رقم هاتفك أبدًا.';

  @override
  String get messageButton => 'رسالة';

  @override
  String chatNewFrom(String name) {
    return 'رسالة جديدة من $name';
  }

  @override
  String get chatOpen => 'فتح';

  @override
  String get chatQuickComing => 'أنا قادم';

  @override
  String get chatQuickAtPickup => 'أنا في نقطة الانطلاق';

  @override
  String get chatQuickWaitPlease => 'انتظر دقيقتين من فضلك';

  @override
  String get chatQuickWhereAreYou => 'أين أنت؟';

  @override
  String get chatQuickHere => 'أنا هنا';

  @override
  String get chatQuickOnMyWay => 'أنا في الطريق';

  @override
  String get chatQuickTraffic => 'عالق في الزحام، بضع دقائق أخرى';

  @override
  String get chatQuickCantFindYou => 'لا أجدك. أين أنت بالضبط؟';

  @override
  String get errChatClosed => 'الرسائل متاحة فقط أثناء الرحلة.';

  @override
  String get errOnAnotherRide => 'أنت في رحلة الآن. أنهِها قبل تقديم عرض جديد.';
}
