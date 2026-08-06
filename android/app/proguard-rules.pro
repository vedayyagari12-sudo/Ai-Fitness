# Release builds shrink and obfuscate. Flutter's own engine classes are
# reached from native code, so R8 cannot see those references and would
# otherwise strip them.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Plugins that resolve classes reflectively.
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep annotations used for keeping other things.
-keepattributes *Annotation*

# Line numbers make a stack trace from a release build readable.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
