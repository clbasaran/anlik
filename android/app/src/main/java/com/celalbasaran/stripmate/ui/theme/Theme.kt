package com.celalbasaran.stripmate.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val StripMateDarkColorScheme = darkColorScheme(
    primary = StripMateBlue,
    onPrimary = Color.White,
    primaryContainer = StripMateBlueDark,
    onPrimaryContainer = Color.White,
    secondary = TextSecondary,
    onSecondary = Color.White,
    secondaryContainer = DarkSurfaceVariant,
    onSecondaryContainer = TextPrimary,
    tertiary = StreakOrange,
    onTertiary = Color.White,
    tertiaryContainer = DarkSurfaceElevated,
    onTertiaryContainer = TextPrimary,
    background = PureBlack,
    onBackground = TextPrimary,
    surface = PureBlack,
    onSurface = TextPrimary,
    surfaceVariant = DarkSurface,
    onSurfaceVariant = TextSecondary,
    surfaceTint = StripMateBlue,
    error = ErrorRed,
    onError = Color.White,
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    outline = SeparatorColor,
    outlineVariant = PlaceholderColor,
    inverseSurface = TextPrimary,
    inverseOnSurface = PureBlack,
    inversePrimary = StripMateBlue,
    scrim = Color.Black
)

@Composable
fun StripMateTheme(
    content: @Composable () -> Unit
) {
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = Color.Transparent.toArgb()
            window.navigationBarColor = Color.Transparent.toArgb()
            WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = false
                isAppearanceLightNavigationBars = false
            }
        }
    }

    MaterialTheme(
        colorScheme = StripMateDarkColorScheme,
        typography = StripMateTypography,
        content = content
    )
}
