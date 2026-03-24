package com.celalbasaran.stripmate.ui.screen.auth

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.R
import kotlinx.coroutines.launch

private data class OnboardingPage(
    val imageRes: Int,
    val title: String,
    val description: String
)

private val onboardingPages = listOf(
    OnboardingPage(
        imageRes = R.drawable.onboarding_1,
        title = "fotoğraf değil\nhafıza",
        description = "anlar uçar, sen yakala"
    ),
    OnboardingPage(
        imageRes = R.drawable.onboarding_2,
        title = "kalabalık değil\nçevren",
        description = "binlerce takipçi değil, gerçek insanlar"
    ),
    OnboardingPage(
        imageRes = R.drawable.onboarding_3,
        title = "beğeni değil\nhis",
        description = "kalp at, güldür, yaz, orada ol"
    ),
    OnboardingPage(
        imageRes = R.drawable.onboarding_4,
        title = "konum değil\nbağ",
        description = "nerede olursan ol, aynı anda burada"
    )
)

@Composable
fun OnboardingScreen(
    onComplete: () -> Unit
) {
    val pagerState = rememberPagerState(pageCount = { onboardingPages.size })
    val coroutineScope = rememberCoroutineScope()
    val isLastPage = pagerState.currentPage == onboardingPages.size - 1

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Full-bleed pager with photos
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            Box(modifier = Modifier.fillMaxSize()) {
                // Full-bleed photo
                Image(
                    painter = painterResource(id = onboardingPages[page].imageRes),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )

                // Top gradient vignette
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Black.copy(alpha = 0.7f),
                                    Color.Transparent
                                )
                            )
                        )
                )

                // Bottom gradient (covers bottom half)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .fillMaxSize(0.55f)
                        .align(Alignment.BottomCenter)
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Transparent,
                                    Color.Black.copy(alpha = 0.4f),
                                    Color.Black.copy(alpha = 0.85f),
                                    Color.Black
                                )
                            )
                        )
                )

                // Text content
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 28.dp)
                        .padding(bottom = 220.dp),
                    verticalArrangement = Arrangement.Bottom
                ) {
                    Text(
                        text = onboardingPages[page].title,
                        color = Color.White,
                        fontSize = 34.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = (-0.5).sp,
                        lineHeight = 40.sp
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    Text(
                        text = onboardingPages[page].description,
                        color = Color.White.copy(alpha = 0.55f),
                        fontSize = 16.sp,
                        lineHeight = 22.sp
                    )
                }
            }
        }

        // Fixed overlay: logo, dots, buttons
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Logo
            Text(
                text = "anlik.",
                color = Color.White,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = (-1).sp,
                modifier = Modifier.padding(top = 64.dp)
            )

            Spacer(modifier = Modifier.weight(1f))

            // Custom page dots (capsule style like iOS)
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(bottom = 20.dp)
            ) {
                repeat(onboardingPages.size) { index ->
                    val isSelected = pagerState.currentPage == index
                    val width by animateDpAsState(
                        targetValue = if (isSelected) 28.dp else 8.dp,
                        label = "dot_width"
                    )
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 4.dp)
                            .width(width)
                            .height(4.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(
                                if (isSelected) Color.White
                                else Color.White.copy(alpha = 0.25f)
                            )
                    )
                }
            }

            // Primary button
            Button(
                onClick = {
                    if (isLastPage) {
                        onComplete()
                    } else {
                        coroutineScope.launch {
                            pagerState.animateScrollToPage(pagerState.currentPage + 1)
                        }
                    }
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isLastPage) Color.White else Color.White.copy(alpha = 0.12f),
                    contentColor = if (isLastPage) Color.Black else Color.White
                ),
                shape = RoundedCornerShape(50),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .animateContentSize()
            ) {
                Text(
                    text = if (isLastPage) "başla" else "devam et",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            // Skip button (hidden on last page)
            if (!isLastPage) {
                TextButton(
                    onClick = onComplete,
                    modifier = Modifier.padding(top = 8.dp, bottom = 40.dp)
                ) {
                    Text(
                        text = "atla",
                        color = Color.White.copy(alpha = 0.4f),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            } else {
                Spacer(modifier = Modifier.height(60.dp))
            }
        }
    }
}
