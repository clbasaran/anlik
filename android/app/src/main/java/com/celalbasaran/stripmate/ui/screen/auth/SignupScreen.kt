package com.celalbasaran.stripmate.ui.screen.auth

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.celalbasaran.stripmate.ui.theme.*
import java.text.SimpleDateFormat
import java.util.*

private const val TOTAL_STEPS = 4

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignupScreen(
    viewModel: AuthViewModel,
    onNavigateToLogin: () -> Unit,
    onSignupSuccess: () -> Unit,
    onGoogleSignIn: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    val focusManager = LocalFocusManager.current
    val view = LocalView.current
    var passwordVisible by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    // Step state
    var currentStep by remember { mutableIntStateOf(0) }

    // Avatar picker
    var avatarUri by remember { mutableStateOf<Uri?>(null) }
    val avatarLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            avatarUri = it
            viewModel.updateAvatarUri(it)
        }
    }

    // Date picker
    var showDatePicker by remember { mutableStateOf(false) }
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = System.currentTimeMillis() - (18L * 365 * 24 * 60 * 60 * 1000)
    )

    // Consent states
    var acceptedTerms by remember { mutableStateOf(false) }
    var acceptedPrivacy by remember { mutableStateOf(false) }
    var acceptedKVKK by remember { mutableStateOf(false) }
    var acceptedEULA by remember { mutableStateOf(false) }
    val allConsentsAccepted = acceptedTerms && acceptedPrivacy && acceptedKVKK && acceptedEULA

    // Per-step validation
    val canAdvanceStep0 = isValidEmailSignup(uiState.email) &&
            uiState.password.length >= 6 &&
            uiState.password == uiState.confirmPassword
    val canAdvanceStep1 = uiState.displayName.isNotBlank() &&
            uiState.username.length >= 3
    val canAdvanceStep2 = avatarUri != null
    val canSignup = allConsentsAccepted && !uiState.isLoading

    LaunchedEffect(uiState.isLoggedIn) {
        if (uiState.isLoggedIn) onSignupSuccess()
    }

    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearError()
        }
    }

    // Date picker dialog
    if (showDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let {
                        viewModel.updateDateOfBirth(Date(it))
                    }
                    showDatePicker = false
                }) { Text("Tamam", color = Color.White) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text("İptal", color = Color.White.copy(alpha = 0.6f))
                }
            },
            colors = DatePickerDefaults.colors(containerColor = Color(0xFF1C1C1E))
        ) {
            DatePicker(
                state = datePickerState,
                colors = DatePickerDefaults.colors(
                    containerColor = Color(0xFF1C1C1E),
                    titleContentColor = Color.White,
                    headlineContentColor = Color.White,
                    weekdayContentColor = Color.White.copy(alpha = 0.6f),
                    subheadContentColor = Color.White.copy(alpha = 0.6f),
                    yearContentColor = Color.White,
                    currentYearContentColor = Color.White,
                    selectedYearContentColor = Color.Black,
                    selectedYearContainerColor = Color.White,
                    dayContentColor = Color.White,
                    selectedDayContentColor = Color.Black,
                    selectedDayContainerColor = Color.White,
                    todayContentColor = Color.White,
                    todayDateBorderColor = Color.White
                )
            )
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top bar: Back + Progress
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp)
                    .statusBarsPadding()
            ) {
                IconButton(onClick = {
                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                    if (currentStep > 0) currentStep-- else onNavigateToLogin()
                }) {
                    Icon(
                        imageVector = Icons.Default.ChevronLeft,
                        contentDescription = if (currentStep > 0) "Geri" else "Girişe dön",
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                }

                // Progress capsules
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 8.dp)
                ) {
                    repeat(TOTAL_STEPS) { step ->
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(3.dp)
                                .clip(CircleShape)
                                .background(
                                    if (step <= currentStep) Color.White
                                    else Color.White.copy(alpha = 0.15f)
                                )
                        )
                    }
                }

                Spacer(modifier = Modifier.width(48.dp))
            }

            // Step content with slide animation
            AnimatedContent(
                targetState = currentStep,
                transitionSpec = {
                    val direction = if (targetState > initialState) 1 else -1
                    (slideInHorizontally(
                        initialOffsetX = { fullWidth -> direction * fullWidth },
                        animationSpec = spring(dampingRatio = 0.85f, stiffness = 300f)
                    ) + fadeIn(animationSpec = tween(200))) togetherWith
                    (slideOutHorizontally(
                        targetOffsetX = { fullWidth -> -direction * fullWidth },
                        animationSpec = spring(dampingRatio = 0.85f, stiffness = 300f)
                    ) + fadeOut(animationSpec = tween(150)))
                },
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                label = "signupStep"
            ) { step ->
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .imePadding()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 28.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Spacer(modifier = Modifier.height(24.dp))

                    when (step) {
                        0 -> StepEmailPassword(
                            uiState = uiState,
                            viewModel = viewModel,
                            passwordVisible = passwordVisible,
                            onTogglePasswordVisibility = { passwordVisible = !passwordVisible },
                            focusManager = focusManager,
                            canAdvance = canAdvanceStep0,
                            onNext = {
                                view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                                currentStep = 1
                            },
                            onGoogleSignIn = onGoogleSignIn
                        )
                        1 -> StepProfile(
                            uiState = uiState,
                            viewModel = viewModel,
                            focusManager = focusManager,
                            showDatePicker = showDatePicker,
                            onShowDatePicker = { showDatePicker = true },
                            canAdvance = canAdvanceStep1,
                            onNext = {
                                view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                                currentStep = 2
                            }
                        )
                        2 -> StepAvatar(
                            avatarUri = avatarUri,
                            onPickAvatar = { avatarLauncher.launch("image/*") },
                            canAdvance = canAdvanceStep2,
                            onNext = {
                                view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                                currentStep = 3
                            }
                        )
                        3 -> StepConsents(
                            acceptedTerms = acceptedTerms,
                            acceptedPrivacy = acceptedPrivacy,
                            acceptedKVKK = acceptedKVKK,
                            acceptedEULA = acceptedEULA,
                            allConsentsAccepted = allConsentsAccepted,
                            onTermsChanged = { acceptedTerms = it },
                            onPrivacyChanged = { acceptedPrivacy = it },
                            onKVKKChanged = { acceptedKVKK = it },
                            onEULAChanged = { acceptedEULA = it },
                            onToggleAll = {
                                val newVal = !allConsentsAccepted
                                acceptedTerms = newVal
                                acceptedPrivacy = newVal
                                acceptedKVKK = newVal
                                acceptedEULA = newVal
                            },
                            canSignup = canSignup,
                            isLoading = uiState.isLoading,
                            onSignup = {
                                view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                                viewModel.signup()
                            }
                        )
                    }

                    Spacer(modifier = Modifier.height(40.dp))
                }
            }

            // Toggle to login
            Text(
                text = "zaten hesabın var mı? giriş yap",
                color = Color.White.copy(alpha = 0.45f),
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .clickable { onNavigateToLogin() }
                    .padding(16.dp)
                    .fillMaxWidth(),
                textAlign = TextAlign.Center
            )
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(16.dp)
        ) { data ->
            Snackbar(
                snackbarData = data,
                containerColor = ErrorRed,
                contentColor = Color.White,
                shape = RoundedCornerShape(12.dp)
            )
        }
    }
}

// MARK: - Step 0: Email & Password

@Composable
private fun StepEmailPassword(
    uiState: AuthUiState,
    viewModel: AuthViewModel,
    passwordVisible: Boolean,
    onTogglePasswordVisibility: () -> Unit,
    focusManager: androidx.compose.ui.focus.FocusManager,
    canAdvance: Boolean,
    onNext: () -> Unit,
    onGoogleSignIn: () -> Unit
) {
    StepHeader(title = "hesabını oluştur", subtitle = "e-posta ve şifreni gir")

    Spacer(modifier = Modifier.height(20.dp))

    AuthTextField(
        value = uiState.email,
        onValueChange = { viewModel.updateEmail(it) },
        placeholder = "e-posta",
        icon = Icons.Default.Email,
        keyboardType = KeyboardType.Email,
        imeAction = ImeAction.Next,
        focusManager = focusManager,
        autoCapitalize = false
    )

    // Email validation
    if (uiState.email.isNotEmpty()) {
        Spacer(modifier = Modifier.height(4.dp))
        val isValid = isValidEmailSignup(uiState.email)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)
        ) {
            Icon(
                imageVector = if (isValid) Icons.Default.CheckCircle else Icons.Default.Error,
                contentDescription = null,
                tint = if (isValid) SuccessGreen.copy(alpha = 0.7f) else Color.White.copy(alpha = 0.35f),
                modifier = Modifier.size(14.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = if (isValid) "geçerli e-posta" else "geçersiz e-posta formatı",
                color = if (isValid) SuccessGreen.copy(alpha = 0.7f) else Color.White.copy(alpha = 0.35f),
                fontSize = 12.sp
            )
        }
    }

    Spacer(modifier = Modifier.height(12.dp))

    AuthSecureField(
        value = uiState.password,
        onValueChange = { viewModel.updatePassword(it) },
        placeholder = "şifre",
        visible = passwordVisible,
        onToggleVisibility = onTogglePasswordVisibility,
        imeAction = ImeAction.Next,
        focusManager = focusManager
    )

    if (uiState.password.isNotEmpty()) {
        Spacer(modifier = Modifier.height(8.dp))
        PasswordStrengthIndicator(password = uiState.password)
    }

    Spacer(modifier = Modifier.height(12.dp))

    AuthSecureField(
        value = uiState.confirmPassword,
        onValueChange = { viewModel.updateConfirmPassword(it) },
        placeholder = "şifre tekrar",
        visible = false,
        onToggleVisibility = {},
        imeAction = ImeAction.Done,
        focusManager = focusManager
    )

    if (uiState.confirmPassword.isNotEmpty()) {
        Spacer(modifier = Modifier.height(4.dp))
        val matches = uiState.password == uiState.confirmPassword
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)
        ) {
            Icon(
                imageVector = if (matches) Icons.Default.CheckCircle else Icons.Default.Cancel,
                contentDescription = null,
                tint = if (matches) SuccessGreen.copy(alpha = 0.7f) else ErrorRed.copy(alpha = 0.7f),
                modifier = Modifier.size(14.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = if (matches) "şifreler eşleşiyor" else "şifreler eşleşmiyor",
                color = if (matches) SuccessGreen.copy(alpha = 0.7f) else ErrorRed.copy(alpha = 0.7f),
                fontSize = 12.sp
            )
        }
    }

    Spacer(modifier = Modifier.height(24.dp))

    NextButton(enabled = canAdvance, onClick = onNext)

    Spacer(modifier = Modifier.height(20.dp))

    // Divider
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth()
    ) {
        HorizontalDivider(modifier = Modifier.weight(1f), color = Color.White.copy(alpha = 0.1f))
        Text(
            text = "veya",
            color = Color.White.copy(alpha = 0.3f),
            fontSize = 12.sp,
            modifier = Modifier.padding(horizontal = 12.dp)
        )
        HorizontalDivider(modifier = Modifier.weight(1f), color = Color.White.copy(alpha = 0.1f))
    }

    Spacer(modifier = Modifier.height(16.dp))

    // Google Sign In
    OutlinedButton(
        onClick = onGoogleSignIn,
        colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.White),
        border = ButtonDefaults.outlinedButtonBorder(enabled = true).copy(
            brush = androidx.compose.ui.graphics.SolidColor(Color.White.copy(alpha = 0.15f))
        ),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
    ) {
        Text("Google ile devam et", fontSize = 16.sp, fontWeight = FontWeight.Medium)
    }
}

// MARK: - Step 1: Profile

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StepProfile(
    uiState: AuthUiState,
    viewModel: AuthViewModel,
    focusManager: androidx.compose.ui.focus.FocusManager,
    showDatePicker: Boolean,
    onShowDatePicker: () -> Unit,
    canAdvance: Boolean,
    onNext: () -> Unit
) {
    StepHeader(title = "profilini oluştur", subtitle = "arkadaşların seni tanısın")

    Spacer(modifier = Modifier.height(20.dp))

    AuthTextField(
        value = uiState.displayName,
        onValueChange = { viewModel.updateDisplayName(it) },
        placeholder = "ad soyad",
        icon = Icons.Default.Person,
        imeAction = ImeAction.Next,
        focusManager = focusManager
    )

    Spacer(modifier = Modifier.height(12.dp))

    AuthTextField(
        value = uiState.username,
        onValueChange = { viewModel.updateUsername(it) },
        placeholder = "kullanıcı adı",
        icon = Icons.Default.AlternateEmail,
        imeAction = ImeAction.Next,
        focusManager = focusManager,
        autoCapitalize = false
    )

    // Username availability
    if (uiState.username.length >= 3) {
        Spacer(modifier = Modifier.height(4.dp))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)
        ) {
            if (uiState.isCheckingUsername) {
                CircularProgressIndicator(
                    modifier = Modifier.size(12.dp),
                    strokeWidth = 1.5.dp,
                    color = Color.White.copy(alpha = 0.5f)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text("kontrol ediliyor...", color = Color.White.copy(alpha = 0.4f), fontSize = 12.sp)
            } else {
                val available = uiState.isUsernameAvailable
                if (available != null) {
                    Icon(
                        imageVector = if (available) Icons.Default.CheckCircle else Icons.Default.Cancel,
                        contentDescription = null,
                        tint = if (available) SuccessGreen.copy(alpha = 0.7f) else ErrorRed.copy(alpha = 0.7f),
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (available) "kullanılabilir" else "bu kullanıcı adı alınmış",
                        color = if (available) SuccessGreen.copy(alpha = 0.7f) else ErrorRed.copy(alpha = 0.7f),
                        fontSize = 12.sp
                    )
                }
            }
        }
    }

    Spacer(modifier = Modifier.height(12.dp))

    // Date of birth
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .border(0.5.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
            .clickable { onShowDatePicker() }
            .padding(vertical = 16.dp, horizontal = 20.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = Icons.Default.CalendarMonth,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.4f),
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = if (uiState.dateOfBirth != null) {
                    uiState.dateOfBirth?.let { SimpleDateFormat("dd MMMM yyyy", Locale("tr")).format(it) } ?: ""
                } else "doğum tarihi",
                color = if (uiState.dateOfBirth != null) Color.White else Color.White.copy(alpha = 0.4f),
                fontSize = 16.sp
            )
        }
    }

    Spacer(modifier = Modifier.height(24.dp))

    NextButton(enabled = canAdvance, onClick = onNext)
}

// MARK: - Step 2: Avatar

@Composable
private fun StepAvatar(
    avatarUri: Uri?,
    onPickAvatar: () -> Unit,
    canAdvance: Boolean,
    onNext: () -> Unit
) {
    StepHeader(title = "profil fotoğrafını seç", subtitle = "arkadaşların seni bulsun")

    Spacer(modifier = Modifier.height(32.dp))

    Box(
        modifier = Modifier
            .size(140.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.08f))
            .clickable { onPickAvatar() },
        contentAlignment = Alignment.Center
    ) {
        if (avatarUri != null) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(avatarUri)
                    .crossfade(true)
                    .build(),
                contentDescription = "Profil fotoğrafı",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize().clip(CircleShape)
            )
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Default.CameraAlt,
                    contentDescription = "Fotoğraf ekle",
                    tint = Color.White.copy(alpha = 0.4f),
                    modifier = Modifier.size(36.dp)
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "fotoğraf ekle",
                    color = Color.White.copy(alpha = 0.4f),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }

        // Edit badge
        if (avatarUri != null) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(Color.White),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Edit,
                    contentDescription = null,
                    tint = Color.Black,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }

    if (avatarUri == null) {
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = "profil fotoğrafı eklenmesi zorunludur",
            color = Color.White.copy(alpha = 0.3f),
            fontSize = 12.sp
        )
    }

    Spacer(modifier = Modifier.height(32.dp))

    NextButton(enabled = canAdvance, onClick = onNext)
}

// MARK: - Step 3: Consents

@Composable
private fun StepConsents(
    acceptedTerms: Boolean,
    acceptedPrivacy: Boolean,
    acceptedKVKK: Boolean,
    acceptedEULA: Boolean,
    allConsentsAccepted: Boolean,
    onTermsChanged: (Boolean) -> Unit,
    onPrivacyChanged: (Boolean) -> Unit,
    onKVKKChanged: (Boolean) -> Unit,
    onEULAChanged: (Boolean) -> Unit,
    onToggleAll: () -> Unit,
    canSignup: Boolean,
    isLoading: Boolean,
    onSignup: () -> Unit
) {
    StepHeader(title = "neredeyse tamam!", subtitle = "yasal belgeleri onayla")

    Spacer(modifier = Modifier.height(20.dp))

    ConsentCheckbox("Kullanım Koşulları", acceptedTerms) { onTermsChanged(it) }
    ConsentCheckbox("Gizlilik Politikası", acceptedPrivacy) { onPrivacyChanged(it) }
    ConsentCheckbox("KVKK Aydınlatma Metni", acceptedKVKK) { onKVKKChanged(it) }
    ConsentCheckbox("EULA", acceptedEULA) { onEULAChanged(it) }

    Spacer(modifier = Modifier.height(4.dp))

    // Select all
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onToggleAll() }
            .padding(vertical = 4.dp)
    ) {
        Icon(
            imageVector = if (allConsentsAccepted) Icons.Default.CheckBox else Icons.Default.CheckBoxOutlineBlank,
            contentDescription = null,
            tint = if (allConsentsAccepted) Color.White else Color.White.copy(alpha = 0.3f),
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = "tümünü okudum ve kabul ediyorum",
            color = Color.White.copy(alpha = 0.6f),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold
        )
    }

    Spacer(modifier = Modifier.height(24.dp))

    // Signup button
    Button(
        onClick = onSignup,
        enabled = canSignup,
        colors = ButtonDefaults.buttonColors(
            containerColor = if (canSignup) Color.White else Color.White.copy(alpha = 0.3f),
            contentColor = if (canSignup) Color.Black else Color.Black.copy(alpha = 0.4f),
            disabledContainerColor = Color.White.copy(alpha = 0.3f),
            disabledContentColor = Color.Black.copy(alpha = 0.4f)
        ),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                color = Color.Black,
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp
            )
        } else {
            Text("hesap oluştur", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        }
    }

    if (!allConsentsAccepted) {
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "devam etmek için yasal belgeleri onaylamalısın",
            color = Color.White.copy(alpha = 0.3f),
            fontSize = 12.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

// MARK: - Shared Components

@Composable
private fun StepHeader(title: String, subtitle: String) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.Start
    ) {
        Text(
            text = title,
            color = Color.White,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = (-0.3).sp
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = subtitle,
            color = Color.White.copy(alpha = 0.4f),
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun NextButton(enabled: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(
            containerColor = if (enabled) Color.White else Color.White.copy(alpha = 0.3f),
            contentColor = if (enabled) Color.Black else Color.Black.copy(alpha = 0.4f),
            disabledContainerColor = Color.White.copy(alpha = 0.3f),
            disabledContentColor = Color.Black.copy(alpha = 0.4f)
        ),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
    ) {
        Text("ileri", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun AuthTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Next,
    focusManager: androidx.compose.ui.focus.FocusManager,
    autoCapitalize: Boolean = true
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .border(0.5.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
            .padding(vertical = 4.dp, horizontal = 20.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.4f),
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        androidx.compose.foundation.text.BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = androidx.compose.ui.text.TextStyle(
                color = Color.White,
                fontSize = 16.sp
            ),
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboardType,
                imeAction = imeAction,
                capitalization = if (autoCapitalize) androidx.compose.ui.text.input.KeyboardCapitalization.Words
                else androidx.compose.ui.text.input.KeyboardCapitalization.None
            ),
            keyboardActions = KeyboardActions(
                onNext = { focusManager.moveFocus(FocusDirection.Down) },
                onDone = { focusManager.clearFocus() }
            ),
            singleLine = true,
            cursorBrush = androidx.compose.ui.graphics.SolidColor(Color.White),
            decorationBox = { innerTextField ->
                Box(modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
                    if (value.isEmpty()) {
                        Text(placeholder, color = Color.White.copy(alpha = 0.4f), fontSize = 16.sp)
                    }
                    innerTextField()
                }
            },
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun AuthSecureField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    visible: Boolean,
    onToggleVisibility: () -> Unit,
    imeAction: ImeAction = ImeAction.Next,
    focusManager: androidx.compose.ui.focus.FocusManager
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .border(0.5.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
            .padding(start = 20.dp, end = 8.dp, top = 4.dp, bottom = 4.dp)
    ) {
        Icon(
            imageVector = Icons.Default.Lock,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.4f),
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        androidx.compose.foundation.text.BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = androidx.compose.ui.text.TextStyle(
                color = Color.White,
                fontSize = 16.sp
            ),
            visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Password,
                imeAction = imeAction
            ),
            keyboardActions = KeyboardActions(
                onNext = { focusManager.moveFocus(FocusDirection.Down) },
                onDone = { focusManager.clearFocus() }
            ),
            singleLine = true,
            cursorBrush = androidx.compose.ui.graphics.SolidColor(Color.White),
            decorationBox = { innerTextField ->
                Box(modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
                    if (value.isEmpty()) {
                        Text(placeholder, color = Color.White.copy(alpha = 0.4f), fontSize = 16.sp)
                    }
                    innerTextField()
                }
            },
            modifier = Modifier.weight(1f)
        )
        IconButton(onClick = onToggleVisibility) {
            Icon(
                imageVector = if (visible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.4f)
            )
        }
    }
}

@Composable
private fun ConsentCheckbox(title: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onCheckedChange(!checked) }
            .padding(vertical = 6.dp)
    ) {
        Icon(
            imageVector = if (checked) Icons.Default.CheckBox else Icons.Default.CheckBoxOutlineBlank,
            contentDescription = null,
            tint = if (checked) Color.White else Color.White.copy(alpha = 0.3f),
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = title,
            color = Color.White.copy(alpha = if (checked) 0.8f else 0.5f),
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f)
        )
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = "Oku",
            tint = Color.White.copy(alpha = 0.2f),
            modifier = Modifier.size(18.dp)
        )
    }
}

private fun isValidEmailSignup(email: String): Boolean {
    val pattern = Regex("^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$")
    return pattern.matches(email.trim())
}

private enum class PasswordStrength(val label: String, val color: @Composable () -> Color, val fraction: Float) {
    WEAK("zayıf", { ErrorRed.copy(alpha = 0.7f) }, 0.25f),
    FAIR("orta", { WarningYellow.copy(alpha = 0.7f) }, 0.5f),
    GOOD("iyi", { WarningYellow.copy(alpha = 0.9f) }, 0.75f),
    STRONG("güçlü", { SuccessGreen.copy(alpha = 0.7f) }, 1.0f);
}

private fun evaluatePasswordStrength(password: String): PasswordStrength {
    var score = 0
    if (password.length >= 6) score++
    if (password.length >= 10) score++
    if (password.any { it.isUpperCase() }) score++
    if (password.any { it.isDigit() }) score++
    if (password.any { !it.isLetterOrDigit() }) score++
    return when (score) {
        0, 1 -> PasswordStrength.WEAK
        2 -> PasswordStrength.FAIR
        3, 4 -> PasswordStrength.GOOD
        else -> PasswordStrength.STRONG
    }
}

@Composable
private fun PasswordStrengthIndicator(password: String) {
    val strength = evaluatePasswordStrength(password)
    val strengthColor = strength.color()
    Column(modifier = Modifier.fillMaxWidth().animateContentSize()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(3.dp)
                .background(Color.White.copy(alpha = 0.1f), CircleShape)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(strength.fraction)
                    .height(3.dp)
                    .background(strengthColor, CircleShape)
            )
        }
        Spacer(modifier = Modifier.height(4.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("şifre gücü:", color = Color.White.copy(alpha = 0.4f), fontSize = 11.sp)
                Text(strength.label, color = strengthColor, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
            if (password.length < 6) {
                Text("min. 6 karakter", color = Color.White.copy(alpha = 0.4f), fontSize = 11.sp)
            }
        }
    }
}
