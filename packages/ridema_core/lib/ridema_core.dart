/// Shared code for the RideMA rider and driver apps.
///
/// Start with [RideMaApp] (bootstrap widget) and [CoreServices]
/// (`CoreServices.of(context)`); see README.md for wiring.
library;

export 'brand.dart';
// API
export 'src/api/api_client.dart';
export 'src/api/api_exception.dart';
export 'src/api/ridema_api.dart';
export 'src/api/storage.dart';
// Auth
export 'src/auth/auth_controller.dart';
// Config
export 'src/config/app_config.dart';
export 'src/config/firebase_services.dart';
export 'src/config/remote_config_service.dart';
export 'src/chat/chat_controller.dart';
export 'src/chat/chat_screen.dart';
export 'src/core_services.dart';
// Localisation
export 'src/l10n/l10n.dart';
export 'src/l10n/locale_controller.dart';
// Models
export 'src/models/app_models.dart';
export 'src/models/chat.dart';
export 'src/models/driver.dart';
export 'src/models/json.dart' show Json;
export 'src/models/rating_reasons.dart';
export 'src/models/realtime_events.dart';
export 'src/models/ride.dart';
export 'src/models/user.dart';
// Platform
export 'src/platform/apk_installer.dart';
export 'src/platform/device_integrity.dart';
export 'src/platform/launcher.dart';
export 'src/platform/permissions.dart';
// Realtime
export 'src/realtime/realtime_service.dart';
export 'src/ridema_app.dart';
// Safety
export 'src/safety/call.dart';
export 'src/safety/sos.dart';
export 'src/theme.dart';
// UI
export 'src/ui/screens/auth_screens.dart';
export 'src/ui/screens/battery_guide_screen.dart';
export 'src/ui/screens/boot_screens.dart';
export 'src/ui/screens/emergency_contacts_screen.dart';
export 'src/ui/screens/legal_screens.dart';
export 'src/ui/screens/permission_screens.dart';
export 'src/ui/screens/phone_screen.dart';
export 'src/ui/screens/profile_screens.dart';
export 'src/ui/screens/trips_screens.dart';
export 'src/ui/widgets/common.dart';
export 'src/ui/widgets/ride_widgets.dart';
