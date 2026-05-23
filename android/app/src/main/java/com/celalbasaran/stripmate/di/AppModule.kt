package com.celalbasaran.stripmate.di

import android.content.Context
import android.content.SharedPreferences
import androidx.room.Room
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.celalbasaran.stripmate.data.local.StripMateDao
import com.celalbasaran.stripmate.data.local.StripMateDatabase
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.storage.FirebaseStorage
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideFirebaseAuth(): FirebaseAuth = FirebaseAuth.getInstance()

    @Provides
    @Singleton
    fun provideFirebaseFirestore(): FirebaseFirestore = FirebaseFirestore.getInstance()

    @Provides
    @Singleton
    fun provideFirebaseStorage(): FirebaseStorage = FirebaseStorage.getInstance()

    @Provides
    @Singleton
    fun provideFirebaseMessaging(): FirebaseMessaging = FirebaseMessaging.getInstance()

    @Provides
    @Singleton
    fun provideFirebaseFunctions(): FirebaseFunctions =
        FirebaseFunctions.getInstance("europe-west1")

    @Provides
    @Singleton
    fun provideStripMateDatabase(
        @ApplicationContext context: Context
    ): StripMateDatabase = Room.databaseBuilder(
        context,
        StripMateDatabase::class.java,
        StripMateDatabase.DATABASE_NAME
    )
        // Real migrations live in `Migrations.kt`; add new entries there when
        // bumping the @Database version. See the file header for the recipe.
        .addMigrations(*com.celalbasaran.stripmate.data.local.ALL_MIGRATIONS)
        // Last-resort safety net: only allow a destructive rebuild from v1.
        // Future versions (3+) without a declared migration will throw at
        // launch, surfacing the missing migration to the developer rather
        // than silently wiping users' offline cache.
        .fallbackToDestructiveMigrationFrom(1)
        .build()

    @Provides
    @Singleton
    fun provideStripMateDao(database: StripMateDatabase): StripMateDao =
        database.stripMateDao()

    /// Sensitive prefs — FCM token, deep-link state, widget state — live in
    /// EncryptedSharedPreferences. Backed by AES-256 (file) + AES-256-SIV
    /// (keys), with the master key in the AndroidKeyStore so a backup or
    /// rooted-device dump can't read it. On first launch we migrate the
    /// existing plaintext "stripmate_prefs" into the encrypted store and
    /// clear the original — keep the migration around for several releases.
    @Provides
    @Singleton
    fun provideSharedPreferences(
        @ApplicationContext context: Context
    ): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        val encrypted = EncryptedSharedPreferences.create(
            context,
            "stripmate_prefs_secure",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )

        // One-shot migration: copy any keys from the legacy plaintext store
        // into the encrypted one, then wipe the legacy file. Idempotent — the
        // legacy file is empty after migration and the loop becomes a no-op.
        val legacy = context.getSharedPreferences("stripmate_prefs", Context.MODE_PRIVATE)
        val legacyEntries = legacy.all
        if (legacyEntries.isNotEmpty()) {
            encrypted.edit().apply {
                for ((key, value) in legacyEntries) {
                    when (value) {
                        is String -> putString(key, value)
                        is Int -> putInt(key, value)
                        is Long -> putLong(key, value)
                        is Float -> putFloat(key, value)
                        is Boolean -> putBoolean(key, value)
                        // Sets are stringSets
                        is Set<*> -> {
                            @Suppress("UNCHECKED_CAST")
                            (value as? Set<String>)?.let { putStringSet(key, it) }
                        }
                    }
                }
                apply()
            }
            legacy.edit().clear().apply()
        }

        return encrypted
    }

    @Provides
    @Singleton
    fun provideFusedLocationProviderClient(
        @ApplicationContext context: Context
    ): FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)
}
