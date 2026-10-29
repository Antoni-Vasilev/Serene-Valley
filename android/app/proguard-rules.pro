# Flutter ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native symbols
-keep class * extends io.flutter.plugin.common.MethodChannel {
    public * *(...);
}

# Keep Dart symbols
-keep class * extends io.flutter.plugin.common.MethodChannel$Result {
    public * *(...);
}
