# Supabase
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }

# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.dominictatakis.calendarsync.**$$serializer { *; }
-keepclassmembers class com.dominictatakis.calendarsync.** { *** Companion; }
-keepclasseswithmembers class com.dominictatakis.calendarsync.** { kotlinx.serialization.KSerializer serializer(...); }
