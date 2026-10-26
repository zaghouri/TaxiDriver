// Version 1 legal texts. DRAFTS written for launch — have them reviewed by a Moroccan lawyer
// (law 09-08 / CNDP declaration) before go-live. New versions are published from the admin panel;
// these are only the seed.
export type Locale = 'ar' | 'fr' | 'en';
export type LegalKind = 'terms' | 'privacy' | 'data_transfer' | 'background_location';

export const LEGAL_VERSION = '2026-10-v1';

type Text = { title: string; body: string };

export const legalTexts: Record<LegalKind, Record<Locale, Text>> = {
  terms: {
    en: {
      title: 'Terms of use',
      body: `{company} runs {app}, an app that connects riders with independent drivers in Morocco.
1. You must be 18 or older and give true information.
2. The rider proposes a price in dirhams (DH). A driver accepts it or proposes another price. The ride is agreed when the rider chooses a driver.
3. Rides are paid in cash, directly to the driver. {app} does not take a commission and never holds your money.
4. Be respectful. Fraud, violence, discrimination or damage lead to account suspension.
5. Cancelling often may limit your account (riders get a warning; drivers get rating penalties and temporary blocks).
6. Drivers are responsible for their licence, vehicle papers and insurance. {app} checks documents but is not the transport operator.
7. In an emergency use the SOS button or call 19 (police), 177 (gendarmerie) or 15 (ambulance).
8. These terms follow Moroccan law. Company: {company}, RC {rc}, ICE {ice}, {address}.`,
    },
    fr: {
      title: "Conditions d'utilisation",
      body: `{company} exploite {app}, une application qui met en relation des passagers et des chauffeurs indépendants au Maroc.
1. Vous devez avoir 18 ans ou plus et donner des informations exactes.
2. Le passager propose un prix en dirhams (DH). Un chauffeur l'accepte ou propose un autre prix. La course est conclue quand le passager choisit un chauffeur.
3. Les courses se paient en espèces, directement au chauffeur. {app} ne prend aucune commission et ne détient jamais votre argent.
4. Restez respectueux. Fraude, violence, discrimination ou dégâts entraînent la suspension du compte.
5. Les annulations répétées peuvent limiter votre compte (avertissement pour les passagers ; pénalité de note et blocage temporaire pour les chauffeurs).
6. Les chauffeurs sont responsables de leur permis, des papiers du véhicule et de l'assurance. {app} vérifie les documents mais n'est pas le transporteur.
7. En cas d'urgence, utilisez le bouton SOS ou appelez le 19 (police), le 177 (gendarmerie) ou le 15 (ambulance).
8. Ces conditions relèvent du droit marocain. Société : {company}, RC {rc}, ICE {ice}, {address}.`,
    },
    ar: {
      title: 'شروط الاستخدام',
      body: `تُشغّل {company} تطبيق {app} الذي يربط الركاب بسائقين مستقلين في المغرب.
1. يجب أن يكون عمرك 18 سنة أو أكثر وأن تقدّم معلومات صحيحة.
2. يقترح الراكب ثمناً بالدرهم. يقبله السائق أو يقترح ثمناً آخر. تُعتبر الرحلة متفقاً عليها عندما يختار الراكب سائقاً.
3. تُدفع الرحلات نقداً للسائق مباشرة. لا يأخذ {app} أي عمولة ولا يحتفظ بأموالك أبداً.
4. كن محترماً. الاحتيال أو العنف أو التمييز أو الإضرار يؤدي إلى توقيف الحساب.
5. الإلغاء المتكرر قد يقيّد حسابك (تنبيه للركاب، وخصم من التقييم وتوقيف مؤقت للسائقين).
6. السائق مسؤول عن رخصته ووثائق السيارة والتأمين. يتحقق {app} من الوثائق لكنه ليس الناقل.
7. في حالة الطوارئ استعمل زر النجدة أو اتصل بـ 19 (الشرطة) أو 177 (الدرك) أو 15 (الإسعاف).
8. تخضع هذه الشروط للقانون المغربي. الشركة: {company}، السجل التجاري {rc}، التعريف الموحد {ice}، {address}.`,
    },
  },
  privacy: {
    en: {
      title: 'Privacy policy',
      body: `What we collect: name, email, Moroccan mobile number, ratings, trips (pickup, destination, route, times, price), device information. Drivers also: last 4 characters of the CIN, licence date, vehicle details and document photos.
Why: to create your account, match riders and drivers, keep trips safe, handle disputes and meet legal duties (law 09-08).
Location: riders share location while the app is open. Drivers share location while online, even when the app is closed.
Who sees it: the other person on your trip sees your first name, rating and (for drivers) car and plate. Phone numbers are never shown; calls go through the app. Our staff see data only when needed, and every view of an ID document is logged.
How long: trips 5 years; GPS route points 12 months; emergency alerts 2 years; driver documents 6 months after you stop driving; codes 7 days.
Your rights: in the app you can download your data, ask for a correction and delete your account. You can also write to {email}.
Security: ID documents are encrypted; passwords are hashed; access is logged.
Controller: {company}, RC {rc}, ICE {ice}, {address}.`,
    },
    fr: {
      title: 'Politique de confidentialité',
      body: `Ce que nous collectons : nom, email, numéro mobile marocain, notes, courses (départ, destination, trajet, horaires, prix), informations sur l'appareil. Pour les chauffeurs aussi : 4 derniers caractères de la CIN, date du permis, véhicule et photos des documents.
Pourquoi : créer votre compte, mettre en relation passagers et chauffeurs, sécuriser les courses, traiter les litiges et respecter la loi 09-08.
Localisation : les passagers partagent leur position quand l'application est ouverte. Les chauffeurs partagent leur position lorsqu'ils sont en ligne, même quand l'application est fermée.
Qui y a accès : la personne avec qui vous voyagez voit votre prénom, votre note et (pour les chauffeurs) la voiture et la plaque. Les numéros ne sont jamais affichés : les appels passent par l'application. Notre équipe n'accède aux données qu'en cas de besoin, et chaque consultation d'une pièce d'identité est enregistrée.
Durées : courses 5 ans ; points GPS 12 mois ; alertes d'urgence 2 ans ; documents chauffeur 6 mois après l'arrêt de l'activité ; codes 7 jours.
Vos droits : dans l'application vous pouvez télécharger vos données, demander une correction et supprimer votre compte. Vous pouvez aussi écrire à {email}.
Sécurité : documents d'identité chiffrés, mots de passe hachés, accès journalisés.
Responsable : {company}, RC {rc}, ICE {ice}, {address}.`,
    },
    ar: {
      title: 'سياسة الخصوصية',
      body: `ما نجمعه: الاسم، البريد الإلكتروني، رقم الهاتف المغربي، التقييمات، الرحلات (نقطة الانطلاق، الوجهة، المسار، الأوقات، الثمن)، ومعلومات الجهاز. وبالنسبة للسائقين أيضاً: آخر 4 أحرف من البطاقة الوطنية، تاريخ رخصة السياقة، معلومات السيارة وصور الوثائق.
لماذا: لإنشاء حسابك، وربط الركاب بالسائقين، وتأمين الرحلات، ومعالجة النزاعات، واحترام القانون 09-08.
الموقع: يشارك الراكب موقعه عندما يكون التطبيق مفتوحاً. ويشارك السائق موقعه عندما يكون متصلاً، حتى عندما يكون التطبيق مغلقاً.
من يطّلع عليها: الشخص المرافق في الرحلة يرى اسمك الأول وتقييمك و(بالنسبة للسائق) السيارة ورقم اللوحة. لا تظهر أرقام الهاتف أبداً، فالمكالمات تتم عبر التطبيق. لا يطّلع فريقنا على البيانات إلا عند الحاجة، ويُسجَّل كل اطلاع على وثيقة هوية.
المدة: الرحلات 5 سنوات؛ نقاط GPS 12 شهراً؛ تنبيهات الطوارئ سنتان؛ وثائق السائق 6 أشهر بعد التوقف عن العمل؛ الرموز 7 أيام.
حقوقك: يمكنك من داخل التطبيق تحميل بياناتك، وطلب تصحيحها، وحذف حسابك. ويمكنك أيضاً مراسلتنا على {email}.
الأمان: وثائق الهوية مشفرة، وكلمات المرور مُجزّأة، وكل وصول مُسجَّل.
المسؤول: {company}، السجل التجاري {rc}، التعريف الموحد {ice}، {address}.`,
    },
  },
  data_transfer: {
    en: {
      title: 'Data sent outside Morocco',
      body: `To work, {app} uses services located outside Morocco, mainly in the United States:
• Google Maps (maps and address search): your location and searched addresses.
• Google Firebase (notifications, app settings, crash reports): a device identifier, notification content and technical crash data.
• Meta WhatsApp (one-time phone check): your phone number and a verification code.
These companies apply their own protection rules. By ticking this box you agree that this data is transferred to them. Without this consent the app cannot work.`,
    },
    fr: {
      title: 'Données envoyées hors du Maroc',
      body: `Pour fonctionner, {app} utilise des services situés hors du Maroc, principalement aux États-Unis :
• Google Maps (cartes et recherche d'adresse) : votre position et les adresses recherchées.
• Google Firebase (notifications, réglages de l'application, rapports de plantage) : un identifiant de l'appareil, le contenu des notifications et des données techniques de plantage.
• Meta WhatsApp (vérification unique du téléphone) : votre numéro et un code de vérification.
Ces sociétés appliquent leurs propres règles de protection. En cochant cette case, vous acceptez ce transfert. Sans ce consentement l'application ne peut pas fonctionner.`,
    },
    ar: {
      title: 'بيانات تُرسل خارج المغرب',
      body: `لكي يعمل، يستعمل {app} خدمات موجودة خارج المغرب، أساساً في الولايات المتحدة:
• خرائط Google (الخرائط والبحث عن العناوين): موقعك والعناوين التي تبحث عنها.
• Google Firebase (الإشعارات، إعدادات التطبيق، تقارير الأعطال): معرّف الجهاز، محتوى الإشعارات وبيانات تقنية عن الأعطال.
• واتساب Meta (التحقق من الهاتف مرة واحدة): رقم هاتفك ورمز التحقق.
تطبق هذه الشركات قواعد الحماية الخاصة بها. بوضع العلامة توافق على هذا النقل. بدون هذه الموافقة لا يمكن للتطبيق أن يعمل.`,
    },
  },
  background_location: {
    en: {
      title: 'Location while you drive',
      body: `When you are online, {app} uses your location even when the app is closed or not in use, so nearby riders can find you and follow their trip. A notification stays visible while this is active. Go offline to stop it.`,
    },
    fr: {
      title: 'Localisation pendant la conduite',
      body: `Quand vous êtes en ligne, {app} utilise votre position même lorsque l'application est fermée ou non utilisée, pour que les passagers proches vous trouvent et suivent leur course. Une notification reste visible pendant ce temps. Passez hors ligne pour l'arrêter.`,
    },
    ar: {
      title: 'الموقع أثناء السياقة',
      body: `عندما تكون متصلاً، يستعمل {app} موقعك حتى عندما يكون التطبيق مغلقاً أو غير مستعمل، حتى يجدك الركاب القريبون ويتابعوا رحلتهم. يبقى إشعار ظاهراً طوال هذه المدة. اختر "غير متصل" لإيقافه.`,
    },
  },
};
