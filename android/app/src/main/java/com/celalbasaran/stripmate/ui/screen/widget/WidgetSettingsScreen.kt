package com.celalbasaran.stripmate.ui.screen.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.screen.friends.FriendsViewModel
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.widget.StripMateWidgetReceiver

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WidgetSettingsScreen(
    onBack: () -> Unit,
    viewModel: FriendsViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()
    val friends = uiState.friends.filter { !it.isPending }

    val prefs = remember { context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE) }
    var selectedFriendId by remember {
        mutableStateOf(prefs.getString("widget_filter_friend_id", null))
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Widget Ayarlari") },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Geri",
                        tint = TextPrimary
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = PureBlack,
                titleContentColor = TextPrimary
            )
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = Icons.Default.Widgets,
                contentDescription = null,
                tint = TextSecondary.copy(alpha = 0.4f),
                modifier = Modifier.size(32.dp)
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "Widget'ta kimin fotoğraflarıni\ngörüntülemek istiyorsun?",
                color = TextSecondary.copy(alpha = 0.6f),
                fontSize = 14.sp,
                textAlign = TextAlign.Center
            )
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp)
        ) {
            item {
                WidgetFriendRow(
                    name = "Herkes",
                    subtitle = "Tum arkadaşlardan gelen",
                    isSelected = selectedFriendId == null,
                    onClick = {
                        selectedFriendId = null
                        saveWidgetFilter(context, null, null)
                    }
                )
                Spacer(modifier = Modifier.height(8.dp))
            }

            items(friends, key = { it.userId }) { friend ->
                val displayName = friend.profile?.displayName ?: "Kullanici"
                WidgetFriendRow(
                    name = displayName,
                    subtitle = friend.profile?.username?.let { "@$it" },
                    avatarUrl = friend.profile?.avatarUrl,
                    isSelected = selectedFriendId == friend.userId,
                    onClick = {
                        selectedFriendId = friend.userId
                        saveWidgetFilter(context, friend.userId, displayName)
                    }
                )
                Spacer(modifier = Modifier.height(4.dp))
            }

            item { Spacer(modifier = Modifier.height(32.dp)) }
        }
    }
}

private fun saveWidgetFilter(context: Context, friendId: String?, friendName: String?) {
    val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
    prefs.edit().apply {
        if (friendId != null) {
            putString("widget_filter_friend_id", friendId)
            putString("widget_filter_friend_name", friendName)
        } else {
            remove("widget_filter_friend_id")
            remove("widget_filter_friend_name")
        }
        apply()
    }

    // Trigger widget refresh
    try {
        val intent = Intent(context, StripMateWidgetReceiver::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(
                ComponentName(context, StripMateWidgetReceiver::class.java)
            )
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        context.sendBroadcast(intent)
    } catch (_: Exception) { }
}

@Composable
private fun WidgetFriendRow(
    name: String,
    subtitle: String? = null,
    avatarUrl: String? = null,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (isSelected) StripMateBlue.copy(alpha = 0.1f)
                else DarkSurface.copy(alpha = 0.5f),
                RoundedCornerShape(12.dp)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (avatarUrl != null || name != "Herkes") {
            UserAvatar(
                imageUrl = avatarUrl,
                displayName = name,
                size = 40.dp
            )
        } else {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .background(StripMateBlue.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Language,
                    contentDescription = "herkes",
                    tint = TextPrimary,
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        Spacer(modifier = Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = name,
                color = TextPrimary,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium
            )
            subtitle?.let {
                Text(
                    text = it,
                    color = TextSecondary,
                    fontSize = 13.sp
                )
            }
        }

        if (isSelected) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = null,
                tint = StripMateBlue,
                modifier = Modifier.size(22.dp)
            )
        }
    }
}
