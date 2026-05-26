# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

-keepattributes SourceFile,LineNumberTable
-keep class io.sentry.** { *; }

# Meta Facebook SDK (facebook_app_events)
-keep class com.facebook.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.facebook.**
