package com.celalbasaran.stripmate

import com.celalbasaran.stripmate.ui.screen.legal.LegalTexts
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LegalTextsLocalizationTest {
    @Test
    fun privacyPolicyReturnsSpanishCopy() {
        assertEquals("Politica de privacidad", LegalTexts.titleFor("privacy", "es-ES"))
        assertTrue(LegalTexts.contentFor("privacy", "es-ES").contains("POLITICA DE PRIVACIDAD"))
        assertTrue(LegalTexts.contentFor("privacy", "es-ES").contains("16 anos"))
    }

    @Test
    fun termsReturnsSpanishCopy() {
        assertEquals("Condiciones de uso", LegalTexts.titleFor("terms", "es-ES"))
        assertTrue(LegalTexts.contentFor("terms", "es-ES").contains("CONDICIONES DE USO"))
        assertTrue(LegalTexts.contentFor("terms", "es-ES").contains("16 anos"))
    }
}
