# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firestore models
-keep class com.celalbasaran.stripmate.data.model.** { *; }

# Room
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *

# Hilt
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }

# Coil
-dontwarn coil.**

# ExoPlayer
-keep class androidx.media3.** { *; }
