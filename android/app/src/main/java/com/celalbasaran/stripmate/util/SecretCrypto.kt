package com.celalbasaran.stripmate.util

import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object SecretCrypto {
    private const val AES_GCM = "AES/GCM/NoPadding"
    private const val GCM_TAG_LENGTH = 128
    private const val GCM_IV_LENGTH = 12

    fun deriveKey(senderId: String, receiverId: String, stripId: String): SecretKeySpec {
        val seed = "${senderId}_${receiverId}_${stripId}_anlik_secret"
        val hash = MessageDigest.getInstance("SHA-256").digest(seed.toByteArray())
        return SecretKeySpec(hash, "AES")
    }

    fun encrypt(data: ByteArray, key: SecretKeySpec): ByteArray {
        val cipher = Cipher.getInstance(AES_GCM)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val iv = cipher.iv
        val encrypted = cipher.doFinal(data)
        // Prepend IV to ciphertext
        return iv + encrypted
    }

    fun decrypt(data: ByteArray, key: SecretKeySpec): ByteArray {
        val iv = data.sliceArray(0 until GCM_IV_LENGTH)
        val ciphertext = data.sliceArray(GCM_IV_LENGTH until data.size)
        val cipher = Cipher.getInstance(AES_GCM)
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        return cipher.doFinal(ciphertext)
    }
}
