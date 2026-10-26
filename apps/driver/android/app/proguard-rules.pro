# Flutter's own rules are added by the Flutter Gradle plugin.
# The embedding references Play Core deferred-components classes we do not ship.
-dontwarn com.google.android.play.core.**
# Native channel handlers are referenced from MainActivity only; keep names for crash reports.
-keep class ma.ridema.driver.** { *; }
# flutter_foreground_task service and receivers are declared in the manifest.
-keep class com.pravera.flutter_foreground_task.** { *; }
