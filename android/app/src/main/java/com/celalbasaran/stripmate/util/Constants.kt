package com.celalbasaran.stripmate.util

object Constants {
    // Limits
    const val MAX_FRIENDS = 50
    const val MAX_RECEIVERS = 50
    const val INVITE_CODE_LENGTH = 8
    const val USERNAME_MIN_LENGTH = 3
    const val USERNAME_MAX_LENGTH = 20
    const val BIO_MAX_LENGTH = 150
    const val DISPLAY_NAME_MAX_LENGTH = 30
    const val COMMENT_MAX_LENGTH = 500
    const val DM_MAX_LENGTH = 1000

    // Image
    const val IMAGE_MAX_SIZE = 1080
    const val JPEG_QUALITY = 75
    const val THUMBNAIL_SIZE = 400
    const val SMALL_THUMBNAIL_SIZE = 150
    const val AVATAR_SIZE = 512

    // Voice
    const val VOICE_MAX_DURATION = 15 // seconds
    const val VOICE_SAMPLE_RATE = 44100

    // Firestore collections
    const val COLLECTION_USERS = "users"
    const val COLLECTION_STRIPS = "strips"
    const val COLLECTION_FRIENDS = "friends"
    const val COLLECTION_STREAKS = "streaks"
    const val COLLECTION_COMMENTS = "comments"
    const val COLLECTION_DIRECT_MESSAGES = "direct_messages"
    const val COLLECTION_THREADS = "threads"
    const val COLLECTION_NOTIFICATIONS = "notifications"
    const val COLLECTION_DAILY_PROMPTS = "daily_prompts"
    const val COLLECTION_ACHIEVEMENTS = "achievements"
    const val COLLECTION_REPORTS = "reports"
    const val COLLECTION_BLOCKED = "blocked"

    // Storage paths
    const val STORAGE_STRIPS = "strips"
    const val STORAGE_AVATARS = "avatars"
    const val STORAGE_THUMBNAILS = "thumbnails"
    const val STORAGE_VOICE = "voice"

    // Notification channels
    const val CHANNEL_DEFAULT = "stripmate_default"
    const val CHANNEL_PHOTO = "stripmate_photo"
    const val CHANNEL_CHAT = "stripmate_chat"
    const val CHANNEL_FRIEND = "stripmate_friend"

    // SharedPreferences keys
    const val PREF_HAS_COMPLETED_ONBOARDING = "has_completed_onboarding"
    const val PREF_LAST_DAILY_PROMPT_DATE = "last_daily_prompt_date"
    const val PREF_NOTIFICATION_TOKEN = "notification_token"
    const val PREF_LAST_ACTIVE_TIMESTAMP = "last_active_timestamp"

    // Streak thresholds
    const val STREAK_EXPIRY_HOURS = 48
    const val FRIENDSHIP_TIER_TANIDIK = 0
    const val FRIENDSHIP_TIER_MUHABBET = 50
    const val FRIENDSHIP_TIER_YAKIN = 150
    const val FRIENDSHIP_TIER_SIRDAS = 350
    const val FRIENDSHIP_TIER_KADIM = 700

    // Pagination
    const val PAGE_SIZE = 20
    const val INITIAL_LOAD_SIZE = 40

    // Timeouts
    const val NETWORK_TIMEOUT_MS = 15_000L
    const val LOCATION_TIMEOUT_MS = 10_000L
    const val UPLOAD_TIMEOUT_MS = 60_000L
}
