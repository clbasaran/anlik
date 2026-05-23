package com.celalbasaran.stripmate.util

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Opens the same EncryptedSharedPreferences instance that Hilt provides via
 * AppModule, but is callable from Compose / View code that doesn't have a
 * Hilt-injected SharedPreferences in scope.
 *
 * The Android Keystore guarantees the underlying master key is the same per
 * (package, signing identity), so the file the encrypted preferences open is
 * identical regardless of where this is called from. Don't open the legacy
 * "stripmate_prefs" file directly anywhere — it's emptied on first launch
 * after the AppModule migration runs.
 */
fun Context.securePreferences(): SharedPreferences {
    val masterKey = MasterKey.Builder(this)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    return EncryptedSharedPreferences.create(
        this,
        "stripmate_prefs_secure",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )
}
