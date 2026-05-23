const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { beforeUserCreated } = require("firebase-functions/v2/identity");
const { defineSecret } = require("firebase-functions/params");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const path = require("path");
const http2 = require("http2");
const crypto = require("crypto");

admin.initializeApp();

// Helper: Truncate APNs collapse-id to 64 bytes (Apple hard limit).
// Uses Buffer.byteLength for correct UTF-8 handling — Turkish characters
// can be multi-byte, so character length != byte length.
function collapseId(str) {
    if (typeof str !== "string" || !str) return "";
    const buf = Buffer.from(str, "utf8");
    if (buf.length <= 64) return str;
    // Slice to 64 bytes and decode back, trimming any broken trailing character
    return buf.slice(0, 64).toString("utf8").replace(/\uFFFD+$/, "");
}

// Helper: Update user's lastActive timestamp (fire-and-forget, non-blocking)
function updateLastActive(userId) {
    if (!userId) return;
    admin.firestore().collection("users").doc(userId)
        .update({ lastActive: admin.firestore.FieldValue.serverTimestamp() })
        .catch(e => console.warn("updateLastActive failed:", e.message));
}

// APNs secrets for direct widget push (set via: firebase functions:secrets:set APNS_KEY_ID etc.)
const APNS_KEY_ID = defineSecret("APNS_KEY_ID");
const APNS_TEAM_ID = defineSecret("APNS_TEAM_ID");
const APNS_AUTH_KEY = defineSecret("APNS_AUTH_KEY"); // .p8 key content (PEM)

// Helper: Check if it's silent hours for a specific user
// Only blocks if user explicitly enabled quiet hours in their settings.
// Default: NOT silent (notifications always come through unless user opts in)
async function isSilentHoursForUser(userId) {
    try {
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        if (userDoc.exists) {
            const data = userDoc.data();
            const prefs = data.notificationPreferences || {};
            // Only apply quiet hours if user explicitly enabled them
            if (prefs.quiet_hours_enabled === true) {
                const start = prefs.quiet_hours_start ?? 23;
                const end = prefs.quiet_hours_end ?? 7;
                const now = new Date();
                // Use user's timezone if stored, otherwise infer from locale
                const tz = data.timezone || data.timeZone;
                let currentHour;
                if (tz) {
                    try {
                        currentHour = parseInt(new Intl.DateTimeFormat("en-US", { hour: "numeric", hour12: false, timeZone: tz }).format(now), 10);
                    } catch (_) {
                        currentHour = (now.getUTCHours() + 3) % 24; // fallback to Turkey
                    }
                } else {
                    // Infer offset from locale: es-ES → UTC+1/+2 (use +1 as safe default), else Turkey UTC+3
                    const locale = preferredLanguage(data);
                    const offset = locale === "es-ES" ? 1 : 3;
                    currentHour = (now.getUTCHours() + offset) % 24;
                }
                if (start > end) {
                    // Overnight range (e.g., 23:00 - 07:00)
                    return currentHour >= start || currentHour < end;
                } else {
                    // Same-day range (e.g., 14:00 - 18:00)
                    return currentHour >= start && currentHour < end;
                }
            }
        }
    } catch (e) { /* fallback to not silent */ }
    // Default: NOT silent — user must explicitly enable quiet hours
    return false;
}

// Legacy isSilentHours() removed — all checks now use per-user isSilentHoursForUser()

// Helper: Check user notification preferences before sending
async function shouldSendNotification(userId, type) {
    try {
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        if (!userDoc.exists) return true;
        const prefs = userDoc.data().notificationPreferences;
        if (!prefs) return true;
        if (prefs.push_enabled === false) return false;

        // Each notification type maps to preference keys in priority order.
        // iOS keys use "notif_" prefix; Android legacy keys use descriptive names.
        // "First defined key wins": the first key that exists in prefs determines the result.
        // This prevents old Android keys from overriding newer iOS keys.
        const keyGroups = {
            strips:             ["notif_strips", "photo_received"],
            new_strip:          ["notif_strips", "photo_received"],
            comments:           ["notif_comments", "comment_received"],
            comment_received:   ["notif_comments", "comment_received"],
            strip_chat:         ["notif_strip_chat", "notif_comments", "comment_received"],
            dms:                ["notif_dms", "message_received"],
            direct_message:     ["notif_dms", "message_received"],
            friends:            ["notif_friends", "friend_added"],
            friend_request:     ["notif_friends", "friend_added"],
            friend_added:       ["notif_friends", "friend_added"],
            streaks:            ["notif_streaks", "streak_warning"],
            streak_warning:     ["notif_streaks", "streak_warning"],
            prompts:            ["notif_prompts", "daily_prompt"],
            daily_prompt:       ["notif_prompts", "daily_prompt"],
            weekly:             ["notif_weekly", "weekly_summary"],
            weekly_summary:     ["notif_weekly", "weekly_summary"],
            support_reply:      ["notif_support"],
            nudge:              ["notif_nudge"],
        };

        const keys = keyGroups[type];
        if (!keys) {
            // Unknown type: check notif_{type} as fallback
            return prefs[`notif_${type}`] !== false;
        }

        // For strip_chat: dedicated key takes priority, then fall back to comments
        if (type === "strip_chat") {
            if (prefs["notif_strip_chat"] !== undefined) return prefs["notif_strip_chat"] !== false;
            if (prefs["notif_comments"] !== undefined) return prefs["notif_comments"] !== false;
            if (prefs["comment_received"] !== undefined) return prefs["comment_received"] !== false;
            return true;
        }

        // First defined key wins: return the value of the first key found in prefs
        for (const key of keys) {
            if (prefs[key] !== undefined) return prefs[key] !== false;
        }
        // No key defined at all — allow notification
        return true;
    } catch (e) {
        // Fail-open: if we can't read preferences, allow the notification.
        // Dropping notifications on transient Firestore errors is worse UX than
        // occasionally sending one the user opted out of.
        console.error("shouldSendNotification error for", userId, type, e.message);
        return true;
    }
}

function preferredLanguage(userData) {
    const locale = String(
        userData?.locale ||
        userData?.language ||
        userData?.preferredLanguage ||
        ""
    ).trim().toLowerCase();

    if (locale.startsWith("es")) return "es-ES";
    if (locale.startsWith("en")) return "en";
    // Default to Turkish for known Turkish locales or empty; English for all other locales
    if (!locale || locale.startsWith("tr")) return "tr";
    return "en";
}

const localizedNotificationCopy = {
    tr: {
        someone: "Birisi",
        brandTitle: "anlık.",
        secretTitle: "gizli an",
        supportTitle: "anlık. destek",
        dmFallback: "Bir mesaj gönderdi",
        stripBody: (name) => `${name} sana yeni bir an paylaştı.`,
        secretStripBody: (name) => `${name} sana gizli bir an gönderdi. açmak için sen de bir an paylaş!`,
        stripChatBody: (name, text) => text ? `${name}: ${text}` : `${name} anına tepki verdi`,
        supportFallback: "Destek ekibinden yeni mesaj",
        friendRequestBody: (name) => `${name} arkadaş olmak istiyor.`,
        friendRequestReminderBody: (name) => `${name} seni hâlâ bekliyor.`,
        streakLostBody: (count) => `${count} günlük bağın koptu. yeni bir an paylaş ve tekrar başla!`,
        weeklyTitle: "anlık. -- haftalık özet",
        weeklyQuiet: "bu hafta biraz sessizdin, arkadaşların seni bekliyor.",
        weeklyGrowth: (growth) => `geçen haftaya göre %${growth} daha aktif bir hafta geçirdin!`,
        weeklyTopFriendWithStreaks: (count, name) => `${count} aktif bağın var! en çok ${name} ile paylaştın.`,
        weeklyTopFriend: (total, name) => `bu hafta ${total} an! en çok ${name} ile paylaştın.`,
        weeklyFallback: (sent, received, streaks) =>
            `bu hafta ${sent} an paylaştın, ${received} an aldın.${streaks > 0 ? ` ${streaks} aktif bağın var!` : ""}`,
        nudgeBody: (name) => `${name} seni dürttü!`,
        birthdayBody: (name) => `bugün ${name}'in doğum günü. bir an gönder.`,
    },
    en: {
        someone: "Someone",
        brandTitle: "anlik.",
        secretTitle: "private moment",
        supportTitle: "anlik. support",
        dmFallback: "Sent you a message",
        stripBody: (name) => `${name} shared a new moment with you.`,
        secretStripBody: (name) => `${name} sent you a private moment. Share one back to unlock it.`,
        stripChatBody: (name, text) => text ? `${name}: ${text}` : `${name} reacted to your moment`,
        supportFallback: "You have a new message from support",
        friendRequestBody: (name) => `${name} wants to be friends.`,
        friendRequestReminderBody: (name) => `${name} is still waiting.`,
        streakLostBody: (count) => `Your ${count}-day streak ended. Share a new moment and start again.`,
        weeklyTitle: "anlik. -- weekly recap",
        weeklyQuiet: "It was a quieter week. Your people are waiting for you.",
        weeklyGrowth: (growth) => `You were ${growth}% more active than last week!`,
        weeklyTopFriendWithStreaks: (count, name) => `You have ${count} active streaks. You shared the most with ${name}.`,
        weeklyTopFriend: (total, name) => `${total} moments this week. You shared the most with ${name}.`,
        weeklyFallback: (sent, received, streaks) =>
            `This week you shared ${sent} moments and received ${received}.${streaks > 0 ? ` You still have ${streaks} active streaks.` : ""}`,
        nudgeBody: (name) => `${name} nudged you!`,
        birthdayBody: (name) => `It's ${name}'s birthday today. Share a moment.`,
    },
    "es-ES": {
        someone: "Alguien",
        brandTitle: "anlik.",
        secretTitle: "momento privado",
        supportTitle: "anlik. ayuda",
        dmFallback: "Te ha enviado un mensaje",
        stripBody: (name) => `${name} ha compartido un momento contigo.`,
        secretStripBody: (name) => `${name} te ha enviado un momento privado. Comparte uno para desbloquearlo.`,
        stripChatBody: (name, text) => text ? `${name}: ${text}` : `${name} ha reaccionado a tu momento`,
        supportFallback: "Tienes un mensaje nuevo de soporte",
        friendRequestBody: (name) => `${name} quiere conectar contigo.`,
        friendRequestReminderBody: (name) => `${name} sigue esperandote.`,
        streakLostBody: (count) => `Tu racha de ${count} dias termino. Comparte un momento nuevo y vuelve a empezar.`,
        weeklyTitle: "anlik. -- resumen semanal",
        weeklyQuiet: "Esta semana estuviste mas en calma. Tu gente sigue ahi.",
        weeklyGrowth: (growth) => `Tu semana fue un ${growth}% mas activa que la anterior.`,
        weeklyTopFriendWithStreaks: (count, name) => `Tienes ${count} rachas activas. Con quien mas compartiste fue con ${name}.`,
        weeklyTopFriend: (total, name) => `${total} momentos esta semana. Con quien mas compartiste fue con ${name}.`,
        weeklyFallback: (sent, received, streaks) =>
            `Esta semana compartiste ${sent} momentos y recibiste ${received}.${streaks > 0 ? ` Sigues con ${streaks} rachas activas.` : ""}`,
        nudgeBody: (name) => `${name} te dio un toque!`,
        birthdayBody: (name) => `Hoy es el cumpleanos de ${name}. Comparte un momento.`,
    },
};

function copyForLanguage(language) {
    return localizedNotificationCopy[language] || localizedNotificationCopy.tr;
}

function copyForUser(userData) {
    return copyForLanguage(preferredLanguage(userData));
}

// ── GIF / Sticker URL detection ──
// Messages sent via the GIPHY picker are stored as a single URL in `text`.
// Pushing the raw URL into the notification body shows users a long opaque
// "https://media.giphy.com/...gif" string which is both ugly and uninformative.
// Instead we replace the body with a localized "Bir GIF gönderdi" / "Sent a GIF".
//
// Any single-token text starting with http(s) and pointing to a known GIF host
// counts. We also catch direct .gif extensions on any host.
const GIF_URL_REGEX = /^https?:\/\/((media\d*\.)?giphy\.com|i\.giphy\.com|tenor\.com|c\.tenor\.com|media\d*\.tenor\.com)\//i;

function looksLikeGifUrl(text) {
    if (!text || typeof text !== "string") return false;
    const trimmed = text.trim();
    if (trimmed.includes(" ") || trimmed.includes("\n")) return false;
    if (GIF_URL_REGEX.test(trimmed)) return true;
    // Any HTTPS URL ending in .gif (case-insensitive)
    return /^https?:\/\/\S+\.gif(\?|$)/i.test(trimmed);
}

const gifBodyByLanguage = {
    tr: "GIF gönderdi",
    en: "Sent a GIF",
    "es-ES": "Te ha enviado un GIF"
};

function gifBodyForCopy(copy) {
    // copy is the full localized object — match it back to a language key.
    if (copy.dmFallback === gifBodyByLanguage.en || copy.someone === "Someone") return gifBodyByLanguage.en;
    if (copy.someone === "Alguien") return gifBodyByLanguage["es-ES"];
    return gifBodyByLanguage.tr;
}

/** Returns a notification-safe body for a chat message. Replaces GIF URLs with a localized phrase. */
function notificationBodyForMessage(text, copy, fallback) {
    if (!text) return fallback || copy.dmFallback;
    if (looksLikeGifUrl(text)) return gifBodyForCopy(copy);
    return text;
}

function groupTokenEntriesByLanguage(tokenEntries, userDataById = {}) {
    return tokenEntries.reduce((groups, entry) => {
        const language = preferredLanguage(userDataById[entry.uid]);
        if (!groups[language]) groups[language] = [];
        groups[language].push(entry);
        return groups;
    }, {});
}

function chunkArray(items, size = 500) {
    const chunks = [];
    for (let index = 0; index < items.length; index += size) {
        chunks.push(items.slice(index, index + size));
    }
    return chunks;
}

// Helper: Check if senderId is blocked by receiverId (bidirectional)
async function isBlockedBetween(senderId, receiverId) {
    try {
        const [blocked, reverseBlocked] = await Promise.all([
            admin.firestore().collection("users").doc(receiverId).collection("blocked").doc(senderId).get(),
            admin.firestore().collection("users").doc(senderId).collection("blocked").doc(receiverId).get()
        ]);
        return blocked.exists || reverseBlocked.exists;
    } catch (e) {
        console.error("isBlockedBetween failed, defaulting to blocked:", e.message);
        return true; // Fail-closed: assume blocked on error to protect user safety
    }
}

// Helper: Get FCM token from private subcollection (secure path)
async function getFCMToken(userId) {
    try {
        const privateDoc = await admin.firestore().collection("users").doc(userId).collection("private").doc("tokens").get();
        if (privateDoc.exists && privateDoc.data().fcmToken) {
            return privateDoc.data().fcmToken;
        }
        // Legacy fallback: token stored directly on user document
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        if (userDoc.exists && userDoc.data().fcmToken) {
            // Migrate legacy token to private subcollection for future reads
            try {
                const legacyToken = userDoc.data().fcmToken;
                await admin.firestore().collection("users").doc(userId).collection("private").doc("tokens")
                    .set({
                        fcmToken: legacyToken,
                        platform: "legacy",
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    }, { merge: true });
                await admin.firestore().collection("users").doc(userId)
                    .update({ fcmToken: admin.firestore.FieldValue.delete() });
                console.log(`Migrated legacy FCM token for user ${userId}`);
                return legacyToken;
            } catch (migrationError) {
                return userDoc.data().fcmToken;
            }
        }
        return null;
    } catch (e) {
        console.error(`Error fetching FCM token for ${userId}:`, e.message);
        return null;
    }
}

// Helper: Get FCM tokens for multiple users in parallel
async function getFCMTokensBatch(userIds) {
    const results = await Promise.all(
        userIds.map(async (uid) => {
            const token = await getFCMToken(uid);
            return { uid, token };
        })
    );
    return results.filter(r => r.token);
}

// Helper: Get widget push tokens for multiple users in parallel
async function getWidgetPushTokensBatch(userIds) {
    const results = await Promise.all(
        userIds.map(async (uid) => {
            try {
                const doc = await admin.firestore().collection("users").doc(uid).collection("private").doc("tokens").get();
                const token = doc.exists ? (doc.data().widgetPushToken || null) : null;
                return { uid, token };
            } catch (error) {
                console.error(`Error fetching widget token for ${uid}:`, error.message);
                return { uid, token: null };
            }
        })
    );
    return results.filter(r => r.token);
}

// Helper: Create APNs JWT for direct push (ES256)
let cachedApnsJwt = null;
let apnsJwtExpiry = 0;

function createApnsJwt() {
    const now = Math.floor(Date.now() / 1000);
    if (cachedApnsJwt && apnsJwtExpiry > now) return cachedApnsJwt;

    const keyId = APNS_KEY_ID.value().trim();
    const teamId = APNS_TEAM_ID.value().trim();
    const authKey = APNS_AUTH_KEY.value().trim();

    try {
        const header = Buffer.from(JSON.stringify({ alg: "ES256", kid: keyId })).toString("base64url");
        const claims = Buffer.from(JSON.stringify({ iss: teamId, iat: now })).toString("base64url");
        const signingInput = `${header}.${claims}`;

        const privateKey = crypto.createPrivateKey({ key: authKey, format: "pem", type: "pkcs8" });
        const signature = crypto.sign(
            "SHA256",
            Buffer.from(signingInput),
            { key: privateKey, dsaEncoding: "ieee-p1363" }
        ).toString("base64url");

        cachedApnsJwt = `${signingInput}.${signature}`;
        apnsJwtExpiry = now + 50 * 60;
        return cachedApnsJwt;
    } catch (err) {
        console.error(`APNs JWT creation failed: ${err.message}`);
        return null;
    }
}

// Helper: Send widget push via APNs HTTP/2 (triggers WidgetKit timeline reload)
async function sendWidgetPushToTokens(widgetTokenEntries) {
    if (widgetTokenEntries.length === 0) return;

    const jwt = createApnsJwt();
    if (!jwt) { console.error("Widget push: JWT creation failed"); return; }

    // Log redacted tokens for debugging
    widgetTokenEntries.forEach(e => console.log(`Widget push: token for uid=${e.uid}: ${e.token.substring(0, 8)}...`));

    const topic = "com.celalbasaran.stripmate.push-type.widgets";

    const results = await Promise.allSettled(
        widgetTokenEntries.map(({ token }) => {
            return new Promise((resolve, reject) => {
                const client = http2.connect("https://api.push.apple.com");
                client.on("error", (err) => { client.close(); reject(err); });

                const req = client.request({
                    ":method": "POST",
                    ":path": `/3/device/${token}`,
                    "authorization": `bearer ${jwt}`,
                    "apns-topic": topic,
                    // WidgetKit push requires push-type=widgets + priority 10 for
                    // immediate delivery. Without these headers APNs treats the push
                    // as throttleable and widget updates can lag 10-30+ seconds.
                    "apns-push-type": "widgets",
                    "apns-priority": "10",
                    // "Deliver now or drop" — if the device is offline, don't queue.
                    // Widget staleness is better than delayed refresh minutes later.
                    "apns-expiration": "0",
                    "content-type": "application/json"
                });

                let data = "";
                let statusCode = 0;
                req.on("response", (headers) => { statusCode = headers[":status"]; });
                req.on("data", (chunk) => data += chunk);
                req.on("end", () => { client.close(); resolve({ statusCode, data, token: token.substring(0, 8) }); });
                req.on("error", (err) => { client.close(); reject(err); });
                // WidgetKit push payload is intentionally minimal — iOS uses the
                // push itself as a signal to call getTimeline(), not for data.
                req.write(JSON.stringify({}));
                req.end();
            });
        })
    );

    results.forEach((r) => {
        if (r.status === "fulfilled") {
            console.log(`Widget push token=${r.value.token}: status=${r.value.statusCode} body=${r.value.data || "(empty)"}`);
        } else {
            console.error(`Widget push error: ${r.reason?.message}`);
        }
    });
}

// Helper: Clean up invalid FCM tokens after a failed multicast send.
async function cleanupInvalidTokens(response, tokenEntries) {
    if (!response || !response.responses) return;
    const invalidCodes = [
        "messaging/invalid-registration-token",
        "messaging/registration-token-not-registered",
    ];
    // Build token-to-uid map for safe lookup regardless of array alignment
    const tokenMap = new Map(tokenEntries.map(e => [e.token, e.uid]));
    const tokens = tokenEntries.map(e => e.token);
    const batch = admin.firestore().batch();
    let cleanupCount = 0;
    response.responses.forEach((resp, idx) => {
        if (resp.error && invalidCodes.includes(resp.error.code)) {
            const token = tokens[idx];
            const uid = token ? tokenMap.get(token) : null;
            if (uid) {
                // Clean from primary path (private subcollection)
                const tokenRef = admin.firestore().collection("users").doc(uid).collection("private").doc("tokens");
                batch.update(tokenRef, { fcmToken: admin.firestore.FieldValue.delete() });
                // Also clean from legacy path (user document) to prevent stale token loops
                const userRef = admin.firestore().collection("users").doc(uid);
                batch.update(userRef, { fcmToken: admin.firestore.FieldValue.delete() });
                cleanupCount++;
            }
        }
    });
    if (cleanupCount > 0) {
        await batch.commit();
        console.log(`Cleaned up ${cleanupCount} invalid FCM tokens.`);
    }
}

// 1. Send push notification when a new photo is sent + UPDATE STREAKS SERVER-SIDE
exports.onNewStrip = onDocumentCreated({ document: "strips/{stripId}", region: "europe-west1", secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY] }, async (event) => {
    const stripData = event.data.data();
    if (!stripData) return;

    try {
    const senderId = stripData.senderId;
    const receiverIds = stripData.receiverIds || [];

    updateLastActive(senderId);

    // Increment sender's strip count (for automation queries — avoids full collection scan)
    admin.firestore().collection("users").doc(senderId)
        .update({ stripCount: admin.firestore.FieldValue.increment(1) })
        .catch(() => {});

    // Rate limit: max 100 strips per day per user
    try {
        const now = new Date();
        const startOfDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
        const todayStrips = await admin.firestore().collection("strips")
            .where("senderId", "==", senderId)
            .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
            .count().get();
        if (todayStrips.data().count > 100) {
            console.warn(`Strip rate limit exceeded for ${senderId}: ${todayStrips.data().count}/day`);
            await event.data.ref.delete();
            return;
        }
    } catch (e) {
        console.error("Error checking strip rate limit:", e);
    }

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderData = senderDoc.exists ? senderDoc.data() : null;
    const senderCopy = copyForUser(senderData);
    const senderName = senderData ? (senderData.displayName || senderData.username || senderCopy.someone) : senderCopy.someone;

    const recipientIds = receiverIds.filter(rid => rid !== senderId);

    // Filter out recipients who have blocked the sender
    const unblockedRecipientIds = [];
    for (const rid of recipientIds) {
        if (!(await isBlockedBetween(senderId, rid))) {
            unblockedRecipientIds.push(rid);
        }
    }

    // ── SERVER-SIDE STREAK UPDATE (paralel) ──
    const streakRecipients = recipientIds.filter(id => id !== senderId);
    const streakResults = await Promise.allSettled(streakRecipients.map(async (receiverId) => {
        try {
            // Skip streak update if users have blocked each other
            if (await isBlockedBetween(senderId, receiverId)) return;

            const streakId = [senderId, receiverId].sort().join("_");
            const streakRef = admin.firestore().collection("streaks").doc(streakId);

            await admin.firestore().runTransaction(async (transaction) => {
                const doc = await transaction.get(streakRef);
                const now = new Date();
                const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                
                if (doc.exists) {
                    const data = doc.data();
                    const lastDate = data.lastExchangeDate ? data.lastExchangeDate.toDate() : new Date(0);
                    const lastDayStart = new Date(lastDate.getFullYear(), lastDate.getMonth(), lastDate.getDate());
                    const daysDiff = Math.floor((todayStart - lastDayStart) / (1000 * 60 * 60 * 24));
                    
                    let currentStreak = data.currentStreak || 0;
                    let longestStreak = data.longestStreak || 0;
                    let totalExchanges = (data.totalExchanges || 0) + 1;
                    
                    if (daysDiff === 0) { /* same day, no streak increment */ }
                    else if (daysDiff === 1) { currentStreak += 1; }
                    else { currentStreak = 1; }
                    
                    longestStreak = Math.max(longestStreak, currentStreak);
                    
                    // Friendship score: streak(40%) + exchanges(40%) + recency(20%)
                    const streakPts = Math.min(400, Math.log2(Math.max(currentStreak, 1) + 1) * 60);
                    const exchangePts = Math.min(400, Math.log2(Math.max(totalExchanges, 1) + 1) * 45);
                    const recencyPts = 200; // just exchanged
                    const friendshipScore = Math.min(1000, Math.floor(streakPts + exchangePts + recencyPts));
                    
                    transaction.update(streakRef, {
                        currentStreak, longestStreak, totalExchanges,
                        lastExchangeDate: admin.firestore.FieldValue.serverTimestamp(),
                        lastSenderId: senderId,
                        friendshipScore
                    });
                } else {
                    const score = Math.min(1000, Math.floor(Math.log2(2) * 60 + Math.log2(2) * 45 + 200));
                    transaction.set(streakRef, {
                        id: streakId,
                        userIds: [senderId, receiverId].sort(),
                        currentStreak: 1, longestStreak: 1, totalExchanges: 1,
                        lastExchangeDate: admin.firestore.FieldValue.serverTimestamp(),
                        lastSenderId: senderId,
                        friendshipScore: score
                    });
                }
            });
        } catch (e) { console.error(`Streak update failed for ${receiverId}:`, e.message); }
    }));
    streakResults.forEach((r, i) => {
        if (r.status === "rejected") {
            console.error(`Streak update rejected for ${streakRecipients[i]}:`, r.reason?.message || r.reason);
        }
    });

    // ── PUSH NOTIFICATIONS (with per-user silent hours + preferences check) ──
    
    // Filter recipients based on disabled status, notification preferences AND per-user silent hours
    const filteredRecipients = [];
    const recipientDataById = {};
    for (const rid of unblockedRecipientIds) {
        // Skip disabled users
        const recipientDoc = await admin.firestore().collection("users").doc(rid).get();
        const recipientData = recipientDoc.exists ? recipientDoc.data() : {};
        recipientDataById[rid] = recipientData;
        if (recipientData.disabled === true) continue;
        if (await isSilentHoursForUser(rid)) continue;
        if (await shouldSendNotification(rid, "strips")) filteredRecipients.push(rid);
    }
    
    const tokenEntries = await getFCMTokensBatch(filteredRecipients);

    if (tokenEntries.length > 0) {
        try {
            const isSecret = stripData.isSecret === true;
            const customData = {
                type: "new_strip",
                stripId: event.params.stripId,
                relatedId: event.params.stripId,
                senderId,
                senderName,
                // Gizli anlarda görsel bilgisi gönderme — NSE kilit ikonu gösterecek
                imageUrl: isSecret ? "" : (stripData.imageUrl || ""),
                thumbnailUrl: isSecret ? "" : (stripData.thumbnailUrl || ""),
                smallThumbnailUrl: isSecret ? "" : (stripData.smallThumbnailUrl || ""),
                latitude: stripData.latitude != null ? String(stripData.latitude) : "",
                longitude: stripData.longitude != null ? String(stripData.longitude) : "",
                cityName: isSecret ? "" : (stripData.cityName || ""),
                isSecret: isSecret ? "true" : "false"
            };
            const groupedEntries = groupTokenEntriesByLanguage(tokenEntries, recipientDataById);

            for (const [language, languageEntries] of Object.entries(groupedEntries)) {
                const copy = copyForLanguage(language);
                const notificationBody = isSecret
                    ? copy.secretStripBody(senderName)
                    : copy.stripBody(senderName);

                const response = await admin.messaging().sendEachForMulticast({
                    tokens: languageEntries.map((entry) => entry.token),
                    android: { collapseKey: `strip_${event.params.stripId}` },
                    apns: {
                        headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`strip_${event.params.stripId}`) },
                        payload: {
                            aps: {
                                alert: { title: isSecret ? copy.secretTitle : copy.brandTitle, body: notificationBody },
                                sound: isSecret ? "secret_strip.caf" : "new_strip.caf",
                                badge: 1,
                                "mutable-content": 1,
                                "thread-id": `strip_${senderId}`,
                                category: "strip_chat"
                            },
                            ...customData
                        }
                    },
                    data: customData
                });
                console.log(`Strip multicast (${language}): ${response.successCount} success, ${response.failureCount} failed`);
                if (response.failureCount > 0) {
                    response.responses.forEach((resp, idx) => {
                        if (resp.error) {
                            console.error(`  FCM send failed for token[${idx}] (uid=${languageEntries[idx]?.uid}): ${resp.error.code} — ${resp.error.message}`);
                        }
                    });
                }
                await cleanupInvalidTokens(response, languageEntries);
            }

        } catch (error) { console.error("Error sending strip multicast:", error); }
    }

    // 2. Widget push via APNs — triggers WidgetKit timeline reload instantly.
    // A short delay lets NSE finish downloading the image to the shared container
    // before the widget is told to rebuild its timeline. 1.5s covers the p99 NSE
    // download on decent networks; if it's still not done, NSE itself calls
    // reloadTimelines a second time when the file lands — so this is a floor,
    // not a hard dependency.
    try {
        const widgetTokenEntries = await getWidgetPushTokensBatch(unblockedRecipientIds);
        console.log(`Widget push: found ${widgetTokenEntries.length} tokens for ${unblockedRecipientIds.length} recipients`);
        if (widgetTokenEntries.length > 0) {
            await new Promise(resolve => setTimeout(resolve, 1500));
            await sendWidgetPushToTokens(widgetTokenEntries);
        }
    } catch (e) { console.warn("Widget push failed:", e.message); }

    // 3. Secret Moment unlock — when sender receives a strip back, unlock their pending secrets
    try {
        for (const receiverId of unblockedRecipientIds) {
            const pendingSecrets = await admin.firestore().collection("strips")
                .where("senderId", "==", receiverId)
                .where("receiverIds", "array-contains", senderId)
                .where("isSecret", "==", true)
                .get();

            for (const doc of pendingSecrets.docs) {
                const unlockedBy = doc.data().unlockedBy || [];
                if (!unlockedBy.includes(senderId)) {
                    await doc.ref.update({
                        unlockedBy: admin.firestore.FieldValue.arrayUnion(senderId)
                    });
                    console.log(`Secret strip ${doc.id} unlocked for ${senderId}`);
                }
            }
        }
    } catch (e) { console.warn("Secret unlock failed:", e.message); }

    } catch (error) {
        console.error("onNewStrip critical error:", error);
    }
});

// 2. Send push notification for Direct Messages
exports.onNewDirectMessage = onDocumentCreated({ document: "direct_messages/{threadId}/messages/{messageId}", region: "europe-west1" }, async (event) => {
    const msgData = event.data.data();
    if (!msgData) return;

    const senderId = msgData.senderId;
    const threadId = event.params.threadId;
    const ids = threadId.split("_");
    const receiverId = ids.find(id => id !== senderId);
    if (!receiverId) return;
    if (await isBlockedBetween(senderId, receiverId)) return;

    updateLastActive(senderId);

    // Skip notifications for deleted messages
    if (msgData.isDeleted === true) return;

    // Rate limit: max 500 DMs per day per user (scoped to this thread)
    try {
        const now = new Date();
        const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const todayMsgs = await admin.firestore()
            .collection("direct_messages").doc(threadId).collection("messages")
            .where("senderId", "==", senderId)
            .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
            .count().get();
        if (todayMsgs.data().count > 500) {
            console.warn(`DM rate limit exceeded for ${senderId} in thread ${threadId}: ${todayMsgs.data().count}/day`);
            return; // Don't delete, just skip notification
        }
    } catch (e) {
        console.error("Error checking DM rate limit:", e);
    }

    const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
    const receiverCopy = copyForUser(receiverDoc.exists ? receiverDoc.data() : null);
    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderName = senderDoc.exists ? (senderDoc.data().displayName || senderDoc.data().username || receiverCopy.someone) : receiverCopy.someone;

    const receiverToken = await getFCMToken(receiverId);
    if (!receiverToken) return;
    if (await isSilentHoursForUser(receiverId)) return;
    if (!(await shouldSendNotification(receiverId, "dms"))) return;

    const dmDisplayBody = notificationBodyForMessage(msgData.text, receiverCopy, receiverCopy.dmFallback);
    try {
        await admin.messaging().send({
            token: receiverToken,
            android: { collapseKey: `dm_${threadId}` },
            apns: {
                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`dm_${threadId}`) },
                payload: {
                    aps: {
                        alert: {
                            title: `${receiverCopy.brandTitle} — ${senderName}`,
                            body: dmDisplayBody
                        },
                        sound: "dm_message.caf",
                        badge: 1,
                        "content-available": 1,
                        "mutable-content": 1,
                        "thread-id": threadId,
                        category: "direct_message"
                    }
                }
            },
            data: {
                type: "direct_message",
                threadId,
                senderId,
                senderName,
                messageText: msgData.text || "",
                displayBody: dmDisplayBody,
                isGif: looksLikeGifUrl(msgData.text) ? "1" : "0"
            }
        });
        console.log("DM sent successfully");
    } catch (error) { console.error("Error sending DM:", error); }
});

// 3. Send push notification for 1-on-1 strip chat messages (with rate limiting)
exports.onNewStripChatMessage = onDocumentCreated({ document: "strips/{stripId}/chats/{receiverId}/messages/{messageId}", region: "europe-west1" }, async (event) => {
    const messageData = event.data.data();
    if (!messageData) return;

    const senderId = messageData.senderId;
    const stripId = event.params.stripId;
    const receiverId = event.params.receiverId;

    updateLastActive(senderId);

    // Rate limit: wrapped in try-catch so notifications still send if index is building
    try {
        const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
        const recentMessages = await admin.firestore()
            .collection("strips").doc(stripId).collection("chats").doc(receiverId).collection("messages")
            .where("senderId", "==", senderId)
            .where("timestamp", ">=", oneMinuteAgo)
            .count().get();
        if (recentMessages.data().count > 10) {
            console.log(`Rate limit: skipping notification for ${senderId}`);
            return;
        }
    } catch (rateLimitError) {
        console.warn("Rate limit query failed, proceeding:", rateLimitError.message);
    }

    // Determine who to notify: get strip data and find the other participant
    const stripDoc = await admin.firestore().collection("strips").doc(stripId).get();
    if (!stripDoc.exists) return;
    const stripData = stripDoc.data();
    
    // The chat channel is between strip.senderId and receiverId
    // Notify whichever one did NOT send this message
    let notifyUserId;
    if (senderId === stripData.senderId) {
        notifyUserId = receiverId; // Strip owner sent message → notify receiver
    } else {
        notifyUserId = stripData.senderId; // Receiver sent message → notify strip owner
    }

    if (!notifyUserId || notifyUserId === senderId) return;
    if (await isBlockedBetween(senderId, notifyUserId)) return;

    // Check quiet hours
    if (await isSilentHoursForUser(notifyUserId)) return;
    if (!(await shouldSendNotification(notifyUserId, "strip_chat"))) return;

    const notifyUserDoc = await admin.firestore().collection("users").doc(notifyUserId).get();
    const notifyCopy = copyForUser(notifyUserDoc.exists ? notifyUserDoc.data() : null);
    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderName = senderDoc.exists ? (senderDoc.data().displayName || senderDoc.data().username || notifyCopy.someone) : notifyCopy.someone;

    const tokenEntries = await getFCMTokensBatch([notifyUserId]);
    const tokens = tokenEntries.map(e => e.token);

    const stripChatDisplayBody = looksLikeGifUrl(messageData.text)
        ? `${senderName}: ${gifBodyForCopy(notifyCopy)}`
        : notifyCopy.stripChatBody(senderName, messageData.text || "");
    if (tokens.length > 0) {
        try {
            const response = await admin.messaging().sendEachForMulticast({
                tokens,
                android: { collapseKey: `c_${stripId}` },
                apns: {
                    headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`c_${stripId}`) },
                    payload: {
                        aps: {
                            alert: {
                                title: notifyCopy.brandTitle,
                                body: stripChatDisplayBody
                            },
                            sound: "chat_message.caf",
                            badge: 1,
                            "content-available": 1,
                            "mutable-content": 1,
                            "thread-id": `chat_${stripId}_${receiverId}`,
                            category: "strip_chat"
                        },
                        "summary-arg": senderName
                    }
                },
                data: {
                    type: "new_strip_chat",
                    stripId,
                    relatedId: stripId,
                    receiverId,
                    senderId,
                    senderName,
                    messageText: messageData.text || "",
                    displayBody: stripChatDisplayBody,
                    isGif: looksLikeGifUrl(messageData.text) ? "1" : "0"
                }
            });
            console.log(`Strip chat notification: ${response.successCount} success, ${response.failureCount} failed`);
            if (response.failureCount > 0) {
                response.responses.forEach((resp, idx) => {
                    if (resp.error) {
                        console.error(`  FCM chat send failed for token[${idx}] (uid=${tokenEntries[idx]?.uid}): ${resp.error.code} — ${resp.error.message}`);
                    }
                });
            }
            await cleanupInvalidTokens(response, tokenEntries);
        } catch (error) { console.error("Error sending strip chat notification:", error); }
    }
});

// 4. Send push notification when admin replies in support chat
exports.onSupportChatAdminReply = onDocumentCreated({ document: "support_chats/{userId}/messages/{messageId}", region: "europe-west1" }, async (event) => {
    const msgData = event.data.data();
    if (!msgData) return;

    // Only notify when admin sends a message
    if (msgData.isAdmin !== true) return;

    const userId = event.params.userId;

    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const supportCopy = copyForUser(userDoc.exists ? userDoc.data() : null);
    const userToken = await getFCMToken(userId);
    if (!userToken) return;
    if (await isSilentHoursForUser(userId)) return;
    if (!(await shouldSendNotification(userId, "support_reply"))) return;

    const messageText = msgData.text || supportCopy.supportFallback;

    try {
        await admin.messaging().send({
            token: userToken,
            android: { collapseKey: `s_${userId}` },
            apns: {
                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`s_${userId}`) },
                payload: {
                    aps: {
                        alert: { title: supportCopy.supportTitle, body: messageText },
                        sound: "dm_message.caf",
                        badge: 1,
                        "mutable-content": 1,
                        "thread-id": `support_${userId}`
                    }
                }
            },
            data: {
                type: "support_reply",
                userId,
                messageText
            }
        });
        console.log(`Support reply notification sent to user ${userId}`);
    } catch (error) {
        console.error("Error sending support reply notification:", error);
    }
});

// 5. Send push notification for Friend Requests
exports.onNewFriendRequest = onDocumentCreated({ document: "users/{userId}/friendships/{friendId}", region: "europe-west1" }, async (event) => {
    const friendData = event.data.data();
    if (!friendData) return;

    const userId = event.params.userId;
    const requesterId = friendData.requesterId;

    updateLastActive(requesterId);

    if (userId === requesterId) return;
    if (!friendData.isPending) return;
    if (await isBlockedBetween(requesterId, userId)) return;

    const receiverDoc = await admin.firestore().collection("users").doc(userId).get();
    const receiverCopy = copyForUser(receiverDoc.exists ? receiverDoc.data() : null);
    const requesterDoc = await admin.firestore().collection("users").doc(requesterId).get();
    const requesterName = requesterDoc.exists ? (requesterDoc.data().displayName || requesterDoc.data().username || receiverCopy.someone) : receiverCopy.someone;

    const receiverToken = await getFCMToken(userId);
    if (!receiverToken) return;
    if (await isSilentHoursForUser(userId)) return;
    if (!(await shouldSendNotification(userId, "friends"))) return;

    try {
        await admin.messaging().send({
            token: receiverToken,
            android: { collapseKey: `friend_${requesterId}` },
            apns: {
                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`friend_${requesterId}`) },
                payload: {
                    aps: {
                        alert: { title: receiverCopy.brandTitle, body: receiverCopy.friendRequestBody(requesterName) },
                        sound: "friend_request.caf",
                        badge: 1,
                        "content-available": 1,
                        "mutable-content": 1,
                        "thread-id": "friend_requests"
                    }
                }
            },
            data: { type: "friend_request", requesterId, senderId: requesterId, senderName: requesterName }
        });
        console.log("Friend request notification sent");
    } catch (error) { console.error("Error sending friend request:", error); }
});

// 4b. Friend Request Reminder — runs daily 11:00 İstanbul. Finds pending
// friend requests created 48-72 hours ago that have NOT been reminded yet
// and sends a gentle "X seni hâlâ bekliyor" push to the receiver, then
// stamps `reminderSentAt` so the same request never gets nudged twice.
//
// Why this query window:
// - Lower bound (>= 72h ago): caps total churn — older than 3 days we let
//   the request rot rather than nag forever.
// - Upper bound (<= 48h ago): wait until the user has had a chance to act
//   organically before reminding.
exports.friendRequestReminder = onSchedule({ schedule: "every day 11:00", timeZone: "Europe/Istanbul", region: "europe-west1" }, async (event) => {
    const now = Date.now();
    const seventyTwoH = new Date(now - 72 * 3600 * 1000);
    const fortyEightH = new Date(now - 48 * 3600 * 1000);
    let scanned = 0;
    let pushed = 0;

    // Friendships are at /users/{uid}/friendships/{friendId}; the receiver of
    // a pending request is `userId` (the doc owner) and the sender is
    // `requesterId`. We only nudge the *receiver*, so query their inbox.
    const snap = await admin.firestore().collectionGroup("friendships")
        .where("isPending", "==", true)
        .where("timestamp", ">=", seventyTwoH)
        .where("timestamp", "<=", fortyEightH)
        .limit(500)
        .get();

    if (snap.empty) {
        console.log("friend reminder: nothing in window");
        return;
    }

    for (const doc of snap.docs) {
        scanned++;
        const data = doc.data();
        if (data.reminderSentAt) continue; // already nudged

        const receiverId = doc.ref.parent.parent.id; // users/{receiverId}/friendships/{...}
        const requesterId = data.requesterId;
        if (!requesterId || requesterId === receiverId) continue; // outbound row, skip

        // Block check both ways
        if (await isBlockedBetween(receiverId, requesterId)) continue;

        const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
        const receiverData = receiverDoc.exists ? receiverDoc.data() : null;
        if (!receiverData || receiverData.disabled === true) continue;
        if (await isSilentHoursForUser(receiverId)) continue;
        if (!(await shouldSendNotification(receiverId, "friend_request"))) continue;

        const tokenEntries = await getFCMTokensBatch([receiverId]);
        if (tokenEntries.length === 0) continue;

        const requesterDoc = await admin.firestore().collection("users").doc(requesterId).get();
        const copy = copyForUser(receiverData);
        const requesterName = requesterDoc.exists
            ? (requesterDoc.data().displayName || requesterDoc.data().username || copy.someone)
            : copy.someone;

        try {
            const response = await admin.messaging().sendEachForMulticast({
                tokens: tokenEntries.map((e) => e.token),
                android: { collapseKey: `fr_remind_${requesterId}` },
                apns: {
                    headers: { "apns-priority": "5", "apns-push-type": "alert", "apns-collapse-id": collapseId(`fr_remind_${requesterId}`) },
                    payload: {
                        aps: {
                            alert: { title: copy.brandTitle, body: copy.friendRequestReminderBody(requesterName) },
                            sound: "friend_request.caf",
                            badge: 1,
                            "thread-id": "friend_requests"
                        }
                    }
                },
                data: { type: "friend_request", requesterId, senderId: requesterId, senderName: requesterName, reminder: "1" }
            });
            await cleanupInvalidTokens(response, tokenEntries);

            // Mark so we never nudge twice for the same row.
            await doc.ref.update({ reminderSentAt: admin.firestore.FieldValue.serverTimestamp() });
            pushed++;
        } catch (e) {
            console.warn("friend reminder push failed:", e.message);
        }
    }
    console.log(`friend reminder: scanned=${scanned}, pushed=${pushed}`);
});

// 4c. Friend Birthday Push — runs daily 09:00 İstanbul. For every user whose
// birthMonth/birthDay matches today, sends a push to each of their accepted
// friends ("bugün X'in doğum günü"). Respects the per-user
// `birthdayVisible` privacy flag (default true) — users who opt out are
// skipped entirely (their friends won't be notified).
exports.friendBirthdayPush = onSchedule({ schedule: "every day 09:00", timeZone: "Europe/Istanbul", region: "europe-west1" }, async (event) => {
    const istanbul = new Date(new Date().toLocaleString("en-US", { timeZone: "Europe/Istanbul" }));
    const month = istanbul.getMonth() + 1;
    const day = istanbul.getDate();

    const todayBirthdayUsers = await admin.firestore().collection("users")
        .where("birthMonth", "==", month)
        .where("birthDay", "==", day)
        .limit(200)
        .get();

    if (todayBirthdayUsers.empty) {
        console.log(`birthday push: nobody born ${day}/${month}`);
        return;
    }

    let totalPushed = 0;

    for (const birthdayDoc of todayBirthdayUsers.docs) {
        const birthdayUserId = birthdayDoc.id;
        const birthdayData = birthdayDoc.data();
        if (birthdayData.disabled === true) continue;
        // Per-user privacy opt-out. The toggle is stored alongside other
        // privacy flags under notificationPreferences.privacy_birthday_visible
        // (default true). Explicit false suppresses the push entirely.
        const privacyPrefs = (birthdayData.notificationPreferences || {});
        if (privacyPrefs.privacy_birthday_visible === false) continue;
        const birthdayName = birthdayData.displayName || birthdayData.username || "";
        if (!birthdayName) continue;

        // Find accepted friends and notify each one.
        const friendsSnap = await admin.firestore()
            .collection("users").doc(birthdayUserId)
            .collection("friendships")
            .where("isPending", "==", false)
            .limit(50)
            .get();

        for (const friendshipDoc of friendsSnap.docs) {
            const friendId = friendshipDoc.data().userId;
            if (!friendId || friendId === birthdayUserId) continue;
            if (await isBlockedBetween(birthdayUserId, friendId)) continue;

            const friendDoc = await admin.firestore().collection("users").doc(friendId).get();
            const friendData = friendDoc.exists ? friendDoc.data() : null;
            if (!friendData || friendData.disabled === true) continue;
            if (await isSilentHoursForUser(friendId)) continue;
            // Re-use the existing "social" notification toggle so we don't ship
            // a new pref key just for this; users can opt out via friends pref.
            if (!(await shouldSendNotification(friendId, "friend_request"))) continue;

            const tokenEntries = await getFCMTokensBatch([friendId]);
            if (tokenEntries.length === 0) continue;

            const copy = copyForUser(friendData);
            try {
                const response = await admin.messaging().sendEachForMulticast({
                    tokens: tokenEntries.map((e) => e.token),
                    android: { collapseKey: `bday_${birthdayUserId}` },
                    apns: {
                        headers: { "apns-priority": "5", "apns-push-type": "alert", "apns-collapse-id": collapseId(`bday_${birthdayUserId}`) },
                        payload: {
                            aps: {
                                alert: { title: copy.brandTitle, body: copy.birthdayBody(birthdayName) },
                                sound: "friend_request.caf",
                                badge: 1,
                                "thread-id": "birthdays"
                            }
                        }
                    },
                    data: { type: "friend_birthday", birthdayUserId, birthdayUserName: birthdayName }
                });
                await cleanupInvalidTokens(response, tokenEntries);
                totalPushed++;
            } catch (e) { console.warn("birthday push failed:", e.message); }
        }
    }
    console.log(`birthday push: notified ${totalPushed} friends across ${todayBirthdayUsers.size} celebrants.`);
});

// 4d. Strip Retention Cleanup — runs daily 03:15 İstanbul. Deletes Firestore
// strip docs (and best-effort their Storage objects) once they've outlived
// their per-strip `retentionDays` (default 30 if missing). Sentinel value
// `-1` opts a strip out of cleanup entirely ("kalıcı" / archived).
exports.stripRetentionCleanup = onSchedule({ schedule: "every day 03:15", timeZone: "Europe/Istanbul", region: "europe-west1" }, async (event) => {
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;
    // Pull strips older than the default 30-day retention. Per-strip overrides
    // (7-day or kalıcı) are honored inside the worker. Capped at 500/run; if
    // backlog grows the next run picks up the rest.
    const olderThan30Days = new Date(now - 30 * dayMs);
    const candidates = await admin.firestore().collection("strips")
        .where("timestamp", "<=", olderThan30Days)
        .orderBy("timestamp", "asc")
        .limit(500)
        .get();
    if (candidates.empty) { console.log("retention cleanup: nothing"); return; }

    let deleted = 0;
    let skipped = 0;
    let kept = 0;

    for (const doc of candidates.docs) {
        const data = doc.data();
        const retentionDays = typeof data.retentionDays === "number" ? data.retentionDays : 30;
        if (retentionDays === -1) { kept++; continue; }
        const tsMs = data.timestamp && typeof data.timestamp.toMillis === "function"
            ? data.timestamp.toMillis() : 0;
        if (!tsMs) { skipped++; continue; }
        const ageDays = Math.floor((now - tsMs) / dayMs);
        if (ageDays < retentionDays) { kept++; continue; }

        try {
            const bucket = admin.storage().bucket();
            const urls = [data.imageUrl, data.thumbnailUrl, data.smallThumbnailUrl, data.voiceUrl, data.videoUrl]
                .filter((u) => typeof u === "string" && u);
            for (const url of urls) {
                try {
                    const m = url.match(/\/o\/([^?]+)/);
                    if (!m) continue;
                    const objectPath = decodeURIComponent(m[1]);
                    await bucket.file(objectPath).delete().catch(() => {});
                } catch (_) {}
            }
            await doc.ref.delete();
            deleted++;
        } catch (e) {
            console.warn(`retention delete failed for ${doc.id}:`, e.message);
            skipped++;
        }
    }
    console.log(`retention: deleted=${deleted}, kept=${kept}, skipped=${skipped}`);
});

// 5. Generate thumbnails when a new image is uploaded to Storage
exports.onImageUploaded = onObjectFinalized(
    { memory: "512MiB", timeoutSeconds: 120, region: "europe-west1" },
    async (event) => {
        const object = event.data;
        const filePath = object.name;
        const contentType = object.contentType;

        if (!filePath || !filePath.startsWith("strips/")) return;
        if (!contentType || !contentType.startsWith("image/")) return;
        if (filePath.includes("/thumbs/")) return;

        const bucket = admin.storage().bucket(object.bucket);
        const fileName = path.basename(filePath);
        const dirName = path.dirname(filePath);

        const Jimp = require("jimp");

        try {
            const [fileBuffer] = await bucket.file(filePath).download();
            const sizes = [
                { width: 200, height: 200, suffix: "200x200" },
                { width: 800, height: 800, suffix: "800x800" },
            ];

            for (const size of sizes) {
                const thumbFileName = `${path.parse(fileName).name}_${size.suffix}.jpg`;
                const thumbPath = `${dirName}/thumbs/${thumbFileName}`;
                const image = await Jimp.read(fileBuffer);
                if (typeof image.exifRotate === "function") image.exifRotate();
                image.scaleToFit(size.width, size.height);
                image.quality(80);
                const resizedBuffer = await image.getBufferAsync(Jimp.MIME_JPEG);
                await bucket.file(thumbPath).save(resizedBuffer, {
                    metadata: { contentType: "image/jpeg", cacheControl: "public, max-age=86400", metadata: { resizedFrom: filePath } },
                });
                console.log(`Created thumbnail: ${thumbPath}`);
            }

            const stripId = path.parse(fileName).name;
            
            // Use permanent public URLs instead of signed URLs that expire
            const thumbFile = bucket.file(`${dirName}/thumbs/${path.parse(fileName).name}_800x800.jpg`);
            const smallThumbFile = bucket.file(`${dirName}/thumbs/${path.parse(fileName).name}_200x200.jpg`);
            await thumbFile.makePublic().catch(() => {});
            await smallThumbFile.makePublic().catch(() => {});
            
            const bucketName = bucket.name;
            const thumbUrl = `https://storage.googleapis.com/${bucketName}/${dirName}/thumbs/${path.parse(fileName).name}_800x800.jpg`;
            const smallThumbUrl = `https://storage.googleapis.com/${bucketName}/${dirName}/thumbs/${path.parse(fileName).name}_200x200.jpg`;

            const stripRef = admin.firestore().collection("strips").doc(stripId);
            const stripDoc = await stripRef.get();
            if (stripDoc.exists) {
                await stripRef.update({ thumbnailUrl: thumbUrl, smallThumbnailUrl: smallThumbUrl });
                console.log(`Updated Firestore strip ${stripId} with thumbnail URLs`);
                
                // Content moderation via Cloud Vision SafeSearch (with single retry)
                try {
                    const vision = require("@google-cloud/vision");
                    const client = new vision.ImageAnnotatorClient();
                    let result;
                    try {
                        [result] = await client.safeSearchDetection(`gs://${object.bucket}/${filePath}`);
                    } catch (firstErr) {
                        console.warn(`Vision API first attempt failed for ${stripId}: ${firstErr.message}, retrying in 2s...`);
                        await new Promise(resolve => setTimeout(resolve, 2000));
                        [result] = await client.safeSearchDetection(`gs://${object.bucket}/${filePath}`);
                    }
                    const safe = result.safeSearchAnnotation;
                    if (safe.adult === "VERY_LIKELY" || safe.violence === "VERY_LIKELY") {
                        await stripRef.update({ flagged: true, flagReason: "auto_moderation" });
                        console.log(`Strip ${stripId} flagged for moderation (adult: ${safe.adult}, violence: ${safe.violence})`);
                    }
                } catch (visionError) {
                    // If Vision API fails after retry, let the photo through — do NOT flag it.
                    // Flagging on API failure was causing ALL photos to disappear from feed.
                    console.warn(`Content moderation skipped for ${stripId} (Vision API unavailable after retry):`, visionError.message);
                }
            } else {
                const snapshot = await admin.firestore().collection("strips").where("imageUrl", ">=", filePath).limit(5).get();
                for (const doc of snapshot.docs) {
                    if (doc.data().imageUrl && doc.data().imageUrl.includes(fileName)) {
                        await doc.ref.update({ thumbnailUrl: thumbUrl, smallThumbnailUrl: smallThumbUrl });
                        console.log(`Updated strip ${doc.id} with thumbnails`);
                        break;
                    }
                }
            }
        } catch (error) { console.error(`Error processing image ${filePath}:`, error); }
    }
);

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");

// 6. Photo cleanup REMOVED — photos are stored permanently.
// Users can manually delete their own photos via the app.

// 6b. Scheduled notification cleanup: delete notifications older than 90 days
exports.scheduledNotificationCleanup = onSchedule({ schedule: "every day 03:30", region: "europe-west1" }, async (event) => {
    const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    let totalDeleted = 0;
    
    const oldNotifs = await admin.firestore().collection("notifications")
        .where("timestamp", "<", cutoff)
        .limit(500).get();
    
    if (!oldNotifs.empty) {
        const batch = admin.firestore().batch();
        oldNotifs.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        totalDeleted = oldNotifs.size;
    }
    console.log(`Notification cleanup: ${totalDeleted} deleted.`);
});

// 7. Daily Prompt Generator
exports.generateDailyPrompt = onSchedule({ schedule: "every day 10:55", timeZone: "Europe/Istanbul", region: "europe-west1" }, async (event) => {
    const now = new Date();
    const dateStr = now.toISOString().split("T")[0];
    const docRef = admin.firestore().collection("daily_prompts").doc(dateStr);

    const existing = await docRef.get();
    if (existing.exists) { console.log(`Prompt exists for ${dateStr}`); return; }

    const prompts = [
        { text: "bugün nasıl görünüyorsun? hadi bir selfie!", emoji: "🤳", category: "selfie" },
        { text: "en doğal halini görmek istiyoruz, filtre yok!", emoji: "🪞", category: "selfie" },
        { text: "bugünkü enerjini yüzünden okuyalım", emoji: "😁", category: "selfie" },
        { text: "en sevdiğin eşyanla bir selfie çeker misin?", emoji: "❤️", category: "selfie" },
        { text: "günaydın! sabahın ilk anı nasıl görünüyor?", emoji: "🌅", category: "mood" },
        { text: "bugün kendini nasıl hissediyorsun? tek kareyle anlat", emoji: "💭", category: "mood" },
        { text: "bugün seni gülümseten küçük şey ne oldu?", emoji: "😊", category: "mood" },
        { text: "şu anki modunu en iyi anlatan kare hangisi?", emoji: "✨", category: "mood" },
        { text: "şu an tam olarak neredesin, göster bakalım", emoji: "📍", category: "place" },
        { text: "evdeki en rahat köşeni merak ediyoruz", emoji: "🏠", category: "place" },
        { text: "pencerenden ne görünüyor şu an?", emoji: "🪟", category: "place" },
        { text: "bugün en çok vakit geçirdiğin yer neresi?", emoji: "💻", category: "place" },
        { text: "bugün ne yiyorsun, bize de göster!", emoji: "🍽️", category: "food" },
        { text: "kahven mi çayın mı? hadi görelim", emoji: "☕", category: "food" },
        { text: "bugünkü atıştırmalığın ne, merak ettik", emoji: "🍿", category: "food" },
        { text: "mutfakta bir şeyler mi pişiriyorsun? göster!", emoji: "👨‍🍳", category: "food" },
        { text: "etrafına bak, sence en güzel detay hangisi?", emoji: "🎨", category: "creative" },
        { text: "en renkli şeyi bul ve çek, renk avı!", emoji: "🌈", category: "creative" },
        { text: "telefonu ters çevir, baş aşağı bir kare çek!", emoji: "🙃", category: "creative" },
        { text: "bir gölge ya da yansıma yakala", emoji: "🌗", category: "creative" },
        { text: "bir şeyin çok yakınından çek, ne olduğunu biz tahmin edelim", emoji: "🔍", category: "creative" },
        { text: "etrafında yüze benzeyen bir şey var mı?", emoji: "👀", category: "creative" },
        { text: "yanındaki en sevdiğin insanla bir kare!", emoji: "👯", category: "social" },
        { text: "şu an kiminle birliktesin? göster!", emoji: "🫂", category: "social" },
        { text: "bugün gördüğün en tatlı canlı kim?", emoji: "🐾", category: "social" },
        { text: "birlikte olduğun arkadaşlarınla grup fotoğrafı!", emoji: "📸", category: "social" },
        { text: "başını kaldır, gökyüzü nasıl görünüyor?", emoji: "🌤️", category: "nature" },
        { text: "etrafında yeşil bir şey bul ve çek", emoji: "🌿", category: "nature" },
        { text: "bugün hava nasıl? bir kareyle anlat", emoji: "🌡️", category: "nature" },
        { text: "yakınındaki bir çiçek veya bitki var mı?", emoji: "🌸", category: "nature" },
        { text: "ayağındakilere bak, bugün ne giydin?", emoji: "👟", category: "random" },
        { text: "son aldığın şey neydi? göster bakalım", emoji: "🛍️", category: "random" },
        { text: "telefonunun ekranında şu an ne var?", emoji: "📱", category: "random" },
        { text: "etrafında mavi bir şey bul!", emoji: "💙", category: "random" },
        { text: "bugünkü kombinin nasıl?", emoji: "👗", category: "random" },
        { text: "yanındaki en rastgele objeyi çek", emoji: "🎲", category: "random" },
        { text: "gurur duyduğun bir şeyi göster bize", emoji: "🏆", category: "random" },
        { text: "sahip olduğun en eski eşya hangisi?", emoji: "🕰️", category: "random" },
        { text: "cebinde veya çantanda ne var?", emoji: "👜", category: "random" },
        { text: "bugünkü planların neler, göster!", emoji: "📝", category: "random" },
        { text: "ayna karşısında bir selfie zamanı!", emoji: "🪞", category: "selfie" },
        { text: "sabah kalktığında ilk gördüğün şey ne?", emoji: "⏰", category: "mood" },
        { text: "kapından dışarı çıkınca ilk ne görüyorsun?", emoji: "🚪", category: "place" },
        { text: "en sevdiğin bardak veya kupayı göster", emoji: "🍵", category: "food" },
        { text: "simetrik bir kare yakalayabilir misin?", emoji: "⚖️", category: "creative" },
        { text: "gün batımını veya doğumunu yakaladın mı?", emoji: "🌇", category: "nature" },
        { text: "etrafında kırmızı bir şey bul!", emoji: "❤️", category: "random" },
        { text: "şu an ne okuyorsun veya ne izliyorsun?", emoji: "📖", category: "random" },
        { text: "ellerinle bir şey yapıyorsan göster!", emoji: "🤲", category: "creative" },
        { text: "bugün gününü güzelleştiren şey ne oldu?", emoji: "🌟", category: "mood" },
        { text: "en çok sevdiğin köşeyi göster", emoji: "🛋️", category: "place" },
        { text: "bir dokunun yakın çekimini yap", emoji: "🧱", category: "creative" },
        { text: "çocukluğundan kalan bir eşyan var mı?", emoji: "🧸", category: "random" },
        { text: "bu gece gökyüzü nasıl görünüyor?", emoji: "🌙", category: "nature" },
        { text: "çok minik bir şey bul ve çek", emoji: "🐜", category: "creative" },
        { text: "siyah-beyaz çekilmeyi hak eden bir kare bul", emoji: "🖤", category: "creative" },
        { text: "ayaklarına ve zeminine bak, ne görüyorsun?", emoji: "👣", category: "random" },
        { text: "şu an kulaklığından ne çalıyor?", emoji: "🎵", category: "random" },
        { text: "ilginç bir kapı veya pencere yakala", emoji: "🚪", category: "creative" },
    ];

    const dayOfYear = Math.floor((now - new Date(now.getFullYear(), 0, 0)) / (1000 * 60 * 60 * 24));
    const index = (dayOfYear - 1) % prompts.length;
    const selected = prompts[index];

    await docRef.set({
        promptText: selected.text,
        promptKey: "",
        emoji: selected.emoji,
        category: selected.category,
        activeDate: admin.firestore.Timestamp.fromDate(now),
    });
    console.log(`Daily prompt: "${selected.text}" ${selected.emoji}`);

    // Direct push — skip es-ES users until a localized Spain prompt library lands
    try {
        let lastDoc = null;
        let sentCount = 0;
        let skippedSpainCount = 0;

        while (true) {
            let query = admin.firestore().collection("users").limit(500);
            if (lastDoc) query = query.startAfter(lastDoc);

            const usersSnapshot = await query.get();
            if (usersSnapshot.empty) break;
            lastDoc = usersSnapshot.docs[usersSnapshot.docs.length - 1];

            const eligibleUserIds = [];
            for (const userDoc of usersSnapshot.docs) {
                const userData = userDoc.data();
                if (userData.disabled === true) continue;
                if (preferredLanguage(userData) === "es-ES") {
                    skippedSpainCount++;
                    continue;
                }
                if (await isSilentHoursForUser(userDoc.id)) continue;
                if (!(await shouldSendNotification(userDoc.id, "prompts"))) continue;
                eligibleUserIds.push(userDoc.id);
            }

            const tokenEntries = await getFCMTokensBatch(eligibleUserIds);
            for (const batchEntries of chunkArray(tokenEntries, 500)) {
                const response = await admin.messaging().sendEachForMulticast({
                    tokens: batchEntries.map((entry) => entry.token),
                    notification: { title: "anlik.", body: selected.text },
                    android: { collapseKey: `prompt_${dateStr}` },
                    apns: { headers: { "apns-priority": "5", "apns-push-type": "alert", "apns-collapse-id": collapseId(`prompt_${dateStr}`) }, payload: { aps: { sound: "daily_prompt.caf", badge: 1, "content-available": 1 } } },
                    data: { type: "daily_prompt", promptDate: dateStr },
                });
                sentCount += response.successCount;
                await cleanupInvalidTokens(response, batchEntries);
            }

            if (usersSnapshot.docs.length < 500) break;
        }
        console.log(`Daily prompt direct push sent to ${sentCount} users. Skipped ${skippedSpainCount} es-ES users.`);
    } catch (error) { console.error("Prompt push error:", error); }
});

// 8. Streak Expiry Check — per-streak notifications, staggered 30s apart per user.
// Skips streaks that are currently frozen (frozenUntil in the future) so the
// "bağ donduruldu" feature actually preserves the streak instead of letting
// the cron eat it.
exports.checkStreakExpiry = onSchedule({ schedule: "every day 04:00", region: "europe-west1" }, async (event) => {
    const now = Date.now();
    const twoDaysAgo = new Date(now - 2 * 24 * 60 * 60 * 1000);
    const expiredStreaks = await admin.firestore().collection("streaks")
        .where("currentStreak", ">", 0)
        .where("lastExchangeDate", "<", twoDaysAgo)
        .limit(500).get();

    if (expiredStreaks.empty) { console.log("No expired streaks."); return; }

    const batch = admin.firestore().batch();
    let resetCount = 0;
    let notifCount = 0;
    let frozenSkipped = 0;

    // Collect per-user notification queue: userId -> [{ streakCount, docId }]
    const userNotifQueue = {};
    const userDataCache = {};

    for (const doc of expiredStreaks.docs) {
        const data = doc.data();
        const currentStreak = data.currentStreak || 0;

        // Frozen streak — extend grace and skip the reset path entirely.
        const frozenUntilTs = data.frozenUntil;
        const frozenUntilMs = frozenUntilTs && typeof frozenUntilTs.toMillis === "function"
            ? frozenUntilTs.toMillis()
            : 0;
        if (frozenUntilMs > now) {
            frozenSkipped++;
            continue;
        }

        if (currentStreak >= 3) {
            for (const userId of data.userIds || []) {
                if (!userNotifQueue[userId]) userNotifQueue[userId] = [];
                userNotifQueue[userId].push({
                    streakCount: currentStreak,
                    longestStreak: data.longestStreak || 0,
                    docId: doc.id
                });
                // Cache user data (fetch once per user)
                if (!userDataCache[userId]) {
                    const userDoc = await admin.firestore().collection("users").doc(userId).get();
                    if (userDoc.exists) {
                        userDataCache[userId] = userDoc.data();
                    }
                }
            }
        }

        batch.update(doc.ref, {
            currentStreak: 0,
            friendshipScore: Math.min(400, Math.floor(Math.log2((data.totalExchanges || 1) + 1) * 45)),
        });
        resetCount++;
    }

    // Send per-streak notifications, staggered 30s apart for each user
    const STAGGER_DELAY_MS = 30000;
    for (const [userId, streakList] of Object.entries(userNotifQueue)) {
        const userData = userDataCache[userId];
        if (!userData || userData.disabled === true) continue;
        if (await isSilentHoursForUser(userId)) continue;
        if (!(await shouldSendNotification(userId, "streaks"))) continue;

        const tokenEntries = await getFCMTokensBatch([userId]);
        if (tokenEntries.length === 0) continue;

        // Sort by streak count descending so the most important one arrives first
        streakList.sort((a, b) => b.streakCount - a.streakCount);

        for (let i = 0; i < streakList.length; i++) {
            // Stagger: wait 30s between each notification to the same user (skip first)
            if (i > 0) await new Promise((resolve) => setTimeout(resolve, STAGGER_DELAY_MS));

            try {
                const copy = copyForUser(userData);
                // If the user previously hit a higher record on this streak,
                // tease the comeback — "rekorun X gündü, yeniden başlat" gives
                // a concrete target instead of a generic "share again".
                const lostCount = streakList[i].streakCount;
                const longest = streakList[i].longestStreak || 0;
                let body = copy.streakLostBody(lostCount);
                if (longest > lostCount && longest >= 7) {
                    body = `${body} rekorun ${longest} gündü.`;
                }
                const response = await admin.messaging().sendEachForMulticast({
                    tokens: tokenEntries.map((entry) => entry.token),
                    notification: { title: copy.brandTitle, body },
                    android: { collapseKey: `streak_lost_${streakList[i].docId}` },
                    apns: { headers: { "apns-priority": "5", "apns-push-type": "alert", "apns-collapse-id": collapseId(`streak_lost_${streakList[i].docId}`) }, payload: { aps: { sound: "streak_alert.caf", badge: 1 } } },
                    data: { type: "streak_lost", streakCount: String(lostCount) },
                });
                await cleanupInvalidTokens(response, tokenEntries);
                notifCount++;
            } catch (e) {}
        }
    }

    await batch.commit();
    console.log(`Streak expiry: ${resetCount} reset, ${notifCount} notifications sent, ${frozenSkipped} frozen-skipped.`);
});

// 8c. Streak At-Risk Warning — runs every day 22:00 İstanbul. For streaks where
// last exchange was 22-26 hours ago and freeze isn't already active, sends a
// "bağın sona yaklaşıyor" push and surfaces freeze availability if unused.
// This is the proactive warning channel that gives users a chance to dondur
// before the cron at 04:00 sweeps the streak.
exports.streakAtRiskWarning = onSchedule({ schedule: "every day 22:00", timeZone: "Europe/Istanbul", region: "europe-west1" }, async (event) => {
    const now = Date.now();
    const cutoffStart = new Date(now - 26 * 3600 * 1000);
    const cutoffEnd = new Date(now - 22 * 3600 * 1000);

    const atRisk = await admin.firestore().collection("streaks")
        .where("currentStreak", ">", 0)
        .where("lastExchangeDate", ">=", cutoffStart)
        .where("lastExchangeDate", "<", cutoffEnd)
        .limit(500).get();
    if (atRisk.empty) { console.log("at-risk: none"); return; }

    let sent = 0;
    let frozenSkipped = 0;

    for (const doc of atRisk.docs) {
        const data = doc.data();
        if (data.currentStreak < 3) continue;
        const frozenUntilMs = data.frozenUntil && typeof data.frozenUntil.toMillis === "function"
            ? data.frozenUntil.toMillis() : 0;
        if (frozenUntilMs > now) { frozenSkipped++; continue; }

        const userIds = data.userIds || [];
        const freezeAvailable = data.freezeUsedThisWeek !== true;

        for (const userId of userIds) {
            const userDoc = await admin.firestore().collection("users").doc(userId).get();
            const userData = userDoc.exists ? userDoc.data() : null;
            if (!userData || userData.disabled === true) continue;
            if (await isSilentHoursForUser(userId)) continue;
            if (!(await shouldSendNotification(userId, "streaks"))) continue;

            const tokenEntries = await getFCMTokensBatch([userId]);
            if (tokenEntries.length === 0) continue;

            const otherId = userIds.find((u) => u !== userId);
            const otherDoc = otherId ? await admin.firestore().collection("users").doc(otherId).get() : null;
            const otherName = otherDoc && otherDoc.exists
                ? (otherDoc.data().displayName || otherDoc.data().username || "")
                : "";

            const copy = copyForUser(userData);
            const baseBody = otherName
                ? `${otherName} ile ${data.currentStreak} günlük bağın sona yaklaşıyor.`
                : `${data.currentStreak} günlük bağın sona yaklaşıyor.`;
            const body = freezeAvailable
                ? `${baseBody} dondurma hakkın hazır.`
                : `${baseBody}`;

            try {
                const response = await admin.messaging().sendEachForMulticast({
                    tokens: tokenEntries.map((e) => e.token),
                    notification: { title: copy.brandTitle, body },
                    android: { collapseKey: `streak_warn_${doc.id}` },
                    apns: { headers: { "apns-priority": "5", "apns-push-type": "alert", "apns-collapse-id": collapseId(`streak_warn_${doc.id}`) }, payload: { aps: { sound: "streak_alert.caf", badge: 1 } } },
                    data: {
                        type: "streak_warning",
                        streakId: doc.id,
                        streakCount: String(data.currentStreak),
                        freezeAvailable: String(freezeAvailable)
                    }
                });
                await cleanupInvalidTokens(response, tokenEntries);
                sent++;
            } catch (e) { console.warn("at-risk push failed:", e.message); }
        }
    }
    console.log(`at-risk: sent=${sent}, frozenSkipped=${frozenSkipped}`);
});

// 8b. Weekly Freeze Reset — clears freezeUsedThisWeek every Monday 00:05 local
// time so users get a fresh "donduruldu" right at the start of the week. Also
// clears stale frozenUntil timestamps that have already passed.
exports.weeklyFreezeReset = onSchedule({ schedule: "every monday 00:05", timeZone: "Europe/Istanbul", region: "europe-west1" }, async (event) => {
    const now = admin.firestore.Timestamp.now();
    const used = await admin.firestore().collection("streaks")
        .where("freezeUsedThisWeek", "==", true)
        .limit(500).get();
    if (used.empty) { console.log("freeze reset: no docs"); return; }

    const batch = admin.firestore().batch();
    used.docs.forEach((doc) => {
        batch.update(doc.ref, {
            freezeUsedThisWeek: false,
            // Drop frozenUntil if it's already past — keeps reads simple.
            frozenUntil: doc.data().frozenUntil && doc.data().frozenUntil.toMillis() < now.toMillis()
                ? admin.firestore.FieldValue.delete()
                : doc.data().frozenUntil
        });
    });
    await batch.commit();
    console.log(`freeze reset: cleared ${used.size} streaks.`);
});

// 9. Weekly Summary Push (every Sunday at 18:00) — with pagination for scale
exports.weeklySummary = onSchedule({ schedule: "every sunday 18:00", region: "europe-west1" }, async (event) => {
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const twoWeeksAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000);
    const now = new Date();
    const weekNumber = getISOWeekNumber(now);
    const year = now.getFullYear();
    let lastDoc = null;
    let totalProcessed = 0;
    const batchSize = 500;

    while (true) {
        let query = admin.firestore().collection("users").limit(batchSize);
        if (lastDoc) query = query.startAfter(lastDoc);
        const usersSnapshot = await query.get();
        if (usersSnapshot.empty) break;
        lastDoc = usersSnapshot.docs[usersSnapshot.docs.length - 1];

    for (const userDoc of usersSnapshot.docs) {
        try {
            const userId = userDoc.id;
            const userData = userDoc.data();
            const copy = copyForUser(userData);

            // Sent strips (dokümanları al - top friend hesaplamak için)
            const [sentDocs, receivedCount, activeStreaks, prevSentCount, prevReceivedCount] = await Promise.all([
                admin.firestore().collection("strips")
                    .where("senderId", "==", userId)
                    .where("timestamp", ">=", weekAgo)
                    .limit(100).get(),
                admin.firestore().collection("strips")
                    .where("receiverIds", "array-contains", userId)
                    .where("timestamp", ">=", weekAgo)
                    .count().get(),
                admin.firestore().collection("streaks")
                    .where("userIds", "array-contains", userId)
                    .where("currentStreak", ">", 0)
                    .count().get(),
                admin.firestore().collection("strips")
                    .where("senderId", "==", userId)
                    .where("timestamp", ">=", twoWeeksAgo)
                    .where("timestamp", "<", weekAgo)
                    .count().get(),
                admin.firestore().collection("strips")
                    .where("receiverIds", "array-contains", userId)
                    .where("timestamp", ">=", twoWeeksAgo)
                    .where("timestamp", "<", weekAgo)
                    .count().get()
            ]);

            const sentCount = sentDocs.size;
            const recvCount = receivedCount.data().count || 0;
            const streakCount = activeStreaks.data().count || 0;
            const totalThisWeek = sentCount + recvCount;
            const totalLastWeek = (prevSentCount.data().count || 0) + (prevReceivedCount.data().count || 0);

            if (totalThisWeek === 0 && totalLastWeek === 0) continue;
            if (userData.disabled === true) continue;
            if (await isSilentHoursForUser(userId)) continue;
            if (!(await shouldSendNotification(userId, "weekly_summary"))) continue;

            const token = await getFCMToken(userId);
            if (!token) continue;

            // Top friend hesapla
            let topFriendName = null;
            const friendFreq = {};
            sentDocs.forEach(doc => {
                const receivers = doc.data().receiverIds || [];
                receivers.forEach(rid => { friendFreq[rid] = (friendFreq[rid] || 0) + 1; });
            });
            const topFriendId = Object.entries(friendFreq).sort((a, b) => b[1] - a[1])[0]?.[0];
            if (topFriendId) {
                const friendDoc = await admin.firestore().collection("users").doc(topFriendId).get();
                topFriendName = friendDoc.exists ? friendDoc.data().displayName : null;
            }

            // Kişiselleştirilmiş mesaj seç
            let body;
            if (totalThisWeek === 0) {
                body = copy.weeklyQuiet;
            } else if (totalLastWeek > 0 && totalThisWeek > totalLastWeek) {
                const growth = Math.round(((totalThisWeek - totalLastWeek) / totalLastWeek) * 100);
                body = copy.weeklyGrowth(growth);
            } else if (streakCount > 0 && topFriendName) {
                body = copy.weeklyTopFriendWithStreaks(streakCount, topFriendName);
            } else if (topFriendName) {
                body = copy.weeklyTopFriend(totalThisWeek, topFriendName);
            } else {
                body = copy.weeklyFallback(sentCount, recvCount, streakCount);
            }

            await admin.messaging().send({
                token,
                notification: { title: copy.weeklyTitle, body },
                android: { collapseKey: `weekly_${year}_w${weekNumber}` },
                apns: { headers: { "apns-priority": "5", "apns-collapse-id": collapseId(`weekly_${year}_w${weekNumber}`) }, payload: { aps: { sound: "daily_prompt.caf" } } },
                data: { type: "weekly_summary", weekNumber: String(weekNumber), year: String(year) },
            });
            totalProcessed++;
        } catch (e) { /* skip user */ }
    }
        if (usersSnapshot.docs.length < batchSize) break;
    }
    console.log(`Weekly summary sent to ${totalProcessed} users.`);
});

// ISO week number helper
function getISOWeekNumber(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
}

// 10. Cascading Delete — Clean up all user data when account is deleted
exports.onAccountDeleted = functions.region("europe-west1").auth.user().onDelete(async (user) => {
    const userId = user.uid;
    const db = admin.firestore();
    const storage = admin.storage().bucket();
    const userRef = db.collection("users").doc(userId);

    // Helper: split an array into chunks to stay under Firestore batch 500 limit
    function chunkArray(arr, size) {
        const chunks = [];
        for (let i = 0; i < arr.length; i += size) {
            chunks.push(arr.slice(i, i + size));
        }
        return chunks;
    }

    // Helper: batch-delete an array of document refs in chunks of 450
    async function batchDeleteRefs(refs) {
        const chunks = chunkArray(refs, 450);
        for (const chunk of chunks) {
            const batch = db.batch();
            chunk.forEach(ref => batch.delete(ref));
            await batch.commit();
        }
    }

    async function deleteSubcollectionDocs(collectionRef) {
        const snapshot = await collectionRef.get();
        if (!snapshot.empty) {
            await batchDeleteRefs(snapshot.docs.map((doc) => doc.ref));
        }
    }

    async function deleteStorageObjectFromDownloadURL(downloadURL) {
        if (!downloadURL) return;
        try {
            const url = new URL(downloadURL);
            const encodedPath = decodeURIComponent(url.pathname).split("/o/")[1];
            if (!encodedPath) return;
            const objectPath = encodedPath.split("?")[0];
            if (!objectPath) return;
            await storage.file(objectPath).delete().catch(() => {});
        } catch (e) {}
    }

    console.log(`Cascading delete for user: ${userId}`);

    try {
        const userSnapshot = await userRef.get();
        const username = String(userSnapshot.data()?.username || "").trim().toLowerCase();

        // 1. Delete user's strips and their comments + storage files
        const userStrips = await db.collection("strips").where("senderId", "==", userId).get();
        for (const doc of userStrips.docs) {
            const data = doc.data();

            // Delete active strip chat structure
            const chats = await doc.ref.collection("chats").get();
            for (const chatDoc of chats.docs) {
                await deleteSubcollectionDocs(chatDoc.ref.collection("messages"));
                await chatDoc.ref.delete().catch(() => {});
            }

            // Delete legacy comments subcollection if it still exists
            const comments = await doc.ref.collection("comments").get();
            if (!comments.empty) {
                await batchDeleteRefs(comments.docs.map((c) => c.ref));
            }

            // Delete storage files
            await deleteStorageObjectFromDownloadURL(data.imageUrl);
            await deleteStorageObjectFromDownloadURL(data.videoUrl);

            if (data.imageUrl) {
                try {
                    const fileName = decodeURIComponent(new URL(data.imageUrl).pathname).split("/o/")[1]?.split("?")[0]?.split("/").pop();
                    if (fileName) {
                        const baseName = fileName.substring(0, fileName.lastIndexOf(".")) || fileName;
                        await storage.file(`strips/thumbs/${baseName}_800x800.jpg`).delete().catch(() => {});
                        await storage.file(`strips/thumbs/${baseName}_200x200.jpg`).delete().catch(() => {});
                    }
                } catch (e) {}
            }

            await doc.ref.delete();
        }

        // 2. Remove user from receiverIds in other people's strips
        const receivedStrips = await db.collection("strips").where("receiverIds", "array-contains", userId).get();
        for (const doc of receivedStrips.docs) {
            const currentReceivers = doc.data().receiverIds || [];
            const updated = currentReceivers.filter(id => id !== userId);
            await doc.ref.update({ receiverIds: updated });
        }

        // 3. Delete friendships (both sides)
        const friendships = await db.collection("users").doc(userId).collection("friendships").get();
        for (const friendDoc of friendships.docs) {
            const friendId = friendDoc.id;
            // Remove reverse friendship
            await db.collection("users").doc(friendId).collection("friendships").doc(userId).delete().catch(() => {});
            await friendDoc.ref.delete();
        }

        // 4. Delete streaks involving this user
        const streaks = await db.collection("streaks").where("userIds", "array-contains", userId).get();
        if (!streaks.empty) await batchDeleteRefs(streaks.docs.map(d => d.ref));

        // 5. Delete notifications for this user
        const notifications = await db.collection("notifications").where("userId", "==", userId).get();
        if (!notifications.empty) await batchDeleteRefs(notifications.docs.map(d => d.ref));

        // 6. Delete DM threads and all messages for conversations involving this user
        const dmThreads = await db.collection("direct_messages").where("participants", "array-contains", userId).get();
        for (const dmDoc of dmThreads.docs) {
            await deleteSubcollectionDocs(dmDoc.ref.collection("messages"));
            await dmDoc.ref.delete().catch(() => {});
        }

        // 7. Delete private subcollection
        const privateTokens = await userRef.collection("private").get();
        if (!privateTokens.empty) await batchDeleteRefs(privateTokens.docs.map(d => d.ref));

        // 8. Delete achievements and support chat
        await deleteSubcollectionDocs(userRef.collection("achievements"));
        await deleteSubcollectionDocs(db.collection("support_chats").doc(userId).collection("messages"));
        await db.collection("support_chats").doc(userId).delete().catch(() => {});

        // 9. Release reserved username if it still exists
        if (username) {
            await db.collection("usernames").doc(username).delete().catch(() => {});
        }

        // 10. Delete user document
        await userRef.delete().catch(() => {});

        // 11. Delete avatar from storage
        await storage.file(`avatars/${userId}.jpg`).delete().catch(() => {});

        console.log(`Cascading delete complete for user: ${userId}`);
    } catch (error) {
        console.error(`Cascading delete error for ${userId}:`, error);
    }
});

// 11. Username Uniqueness Enforcement
// Maintains a `usernames` collection for atomic uniqueness checks.
// When a user profile is created/updated with a username, reserve it in `usernames/{lowercased}`.
exports.onUserProfileWrite = onDocumentWritten({ document: "users/{userId}", region: "europe-west1" }, async (event) => {
    const userId = event.params.userId;
    const afterData = event.data?.after?.data();
    const beforeData = event.data?.before?.data();
    
    const newUsername = afterData?.username?.toLowerCase().trim();
    const oldUsername = beforeData?.username?.toLowerCase().trim();
    
    // No username change — skip
    if (newUsername === oldUsername) return;
    
    const db = admin.firestore();
    
    // Release old username and reserve new one in a transaction
    await db.runTransaction(async (transaction) => {
        if (newUsername) {
            const existingRef = db.collection("usernames").doc(newUsername);
            const existing = await transaction.get(existingRef);
            if (existing.exists && existing.data().userId !== userId) {
                // Username taken by another user — revert the change
                console.warn(`Username "${newUsername}" already taken. Reverting for user ${userId}.`);
                transaction.update(db.collection("users").doc(userId), { username: oldUsername || admin.firestore.FieldValue.delete() });
                return;
            }
            transaction.set(existingRef, {
                userId: userId,
                reservedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
        if (oldUsername) {
            transaction.delete(db.collection("usernames").doc(oldUsername));
        }
        if (newUsername) {
            console.log(`Username "${newUsername}" reserved for user ${userId}`);
        }
    });
});

// 11b. Friend Count Maintenance — update friendCount when friendship changes
// This avoids N+1 subcollection reads in automation queries
exports.onFriendshipChange = onDocumentWritten({ document: "users/{userId}/friendships/{friendId}", region: "europe-west1" }, async (event) => {
    const userId = event.params.userId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    const wasAccepted = before && !before.isPending;
    const isAccepted = after && !after.isPending;
    const wasDeleted = !after;

    if (!wasAccepted && isAccepted) {
        // Friendship accepted — increment both users
        const friendId = event.params.friendId;
        const batch = admin.firestore().batch();
        batch.update(admin.firestore().collection("users").doc(userId), { friendCount: admin.firestore.FieldValue.increment(1) });
        batch.update(admin.firestore().collection("users").doc(friendId), { friendCount: admin.firestore.FieldValue.increment(1) });
        await batch.commit().catch(() => {});
    } else if (wasAccepted && wasDeleted) {
        // Friendship removed — decrement both users
        const friendId = event.params.friendId;
        const batch = admin.firestore().batch();
        batch.update(admin.firestore().collection("users").doc(userId), { friendCount: admin.firestore.FieldValue.increment(-1) });
        batch.update(admin.firestore().collection("users").doc(friendId), { friendCount: admin.firestore.FieldValue.increment(-1) });
        await batch.commit().catch(() => {});
    }
});

// 12. Admin Push Notification Delivery
// Triggers when admin panel writes to notification_logs collection.
// Actually sends FCM push notifications based on targetType.
exports.onAdminNotification = onDocumentCreated({ document: "notification_logs/{logId}", region: "europe-west1" }, async (event) => {
    const data = event.data.data();
    if (!data) return;

    // Skip if already processed (safety check)
    if (data.processed === true) return;

    const title = data.title || "";
    const body = data.body || "";
    const targetType = data.targetType || "all";
    const targetUserIds = data.targetUserIds || [];
    const topic = data.topic || "";
    const logRef = event.data.ref;

    let successCount = 0;
    let failureCount = 0;

    try {
        if ((targetType === "specific" || targetType === "segment") && targetUserIds.length > 0) {
            // Send to specific users
            const tokenEntries = await getFCMTokensBatch(targetUserIds);
            const tokens = tokenEntries.map(e => e.token);

            if (tokens.length > 0) {
                // FCM multicast supports max 500 tokens per call
                for (let i = 0; i < tokens.length; i += 500) {
                    const batch = tokens.slice(i, i + 500);
                    const batchEntries = tokenEntries.slice(i, i + 500);
                    const response = await admin.messaging().sendEachForMulticast({
                        tokens: batch,
                        notification: { title, body },
                        android: { collapseKey: `admin_${event.params.logId}` },
                        apns: {
                            headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`admin_${event.params.logId}`) },
                            payload: { aps: { sound: "default", badge: 1, "content-available": 1 } }
                        },
                        data: { type: "admin_push" }
                    });
                    successCount += response.successCount;
                    failureCount += response.failureCount;
                    await cleanupInvalidTokens(response, batchEntries);
                }
            }
            console.log(`Admin notification (specific): ${successCount} success, ${failureCount} failed out of ${targetUserIds.length} targets`);

        } else if (targetType === "topic" && topic) {
            // Send to FCM topic
            await admin.messaging().send({
                topic: topic,
                notification: { title, body },
                android: { collapseKey: `admin_${event.params.logId}` },
                apns: {
                    headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`admin_${event.params.logId}`) },
                    payload: { aps: { sound: "default", badge: 1, "content-available": 1 } }
                },
                data: { type: "admin_push", topic }
            });
            successCount = 1;
            console.log(`Admin notification sent to topic: ${topic}`);

        } else {
            // Send to ALL users — paginate through users collection
            let lastDoc = null;
            const batchSize = 200;

            while (true) {
                let query = admin.firestore().collection("users").limit(batchSize);
                if (lastDoc) query = query.startAfter(lastDoc);
                const usersSnapshot = await query.get();
                if (usersSnapshot.empty) break;
                lastDoc = usersSnapshot.docs[usersSnapshot.docs.length - 1];

                const userIds = usersSnapshot.docs.map(d => d.id);
                const tokenEntries = await getFCMTokensBatch(userIds);
                const tokens = tokenEntries.map(e => e.token);

                if (tokens.length > 0) {
                    for (let i = 0; i < tokens.length; i += 500) {
                        const batch = tokens.slice(i, i + 500);
                        const batchEntries = tokenEntries.slice(i, i + 500);
                        const response = await admin.messaging().sendEachForMulticast({
                            tokens: batch,
                            notification: { title, body },
                            android: { collapseKey: `admin_${event.params.logId}` },
                            apns: {
                                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`admin_${event.params.logId}`) },
                                payload: { aps: { sound: "default", badge: 1, "content-available": 1 } }
                            },
                            data: { type: "admin_push" }
                        });
                        successCount += response.successCount;
                        failureCount += response.failureCount;
                        await cleanupInvalidTokens(response, batchEntries);
                    }
                }

                if (usersSnapshot.docs.length < batchSize) break;
            }
            console.log(`Admin notification (all): ${successCount} success, ${failureCount} failed`);
        }

        // Mark as processed with delivery stats
        await logRef.update({
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            deliverySuccess: successCount,
            deliveryFailure: failureCount
        });

    } catch (error) {
        console.error("Admin notification error:", error);
        await logRef.update({
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            deliveryError: error.message,
            deliverySuccess: successCount,
            deliveryFailure: failureCount
        });
    }
});

// 13. Process Scheduled Notifications
// Runs every 5 minutes, checks scheduled_notifications for unsent items where scheduledAt <= now.
// Moves them to notification_logs to trigger onAdminNotification.
// =====================================================
// 14. AUTOMATION ENGINE — Runs every hour
// Reads enabled automation_rules from Firestore,
// finds matching users, sends push notifications,
// and logs results to automation_logs.
// =====================================================
exports.processAutomationRules = onSchedule({ schedule: "every 1 hours", region: "europe-west1" }, async (event) => {
    const db = admin.firestore();
    const now = new Date();

    console.log("⚙️ Automation engine started at", now.toISOString());

    // 1. Fetch all enabled automation rules
    const rulesSnap = await db.collection("automation_rules")
        .where("enabled", "==", true)
        .get();

    if (rulesSnap.empty) {
        console.log("No enabled automation rules found.");
        return;
    }

    console.log(`Found ${rulesSnap.size} enabled rule(s).`);

    for (const ruleDoc of rulesSnap.docs) {
        const rule = ruleDoc.data();
        const ruleId = ruleDoc.id;
        const trigger = rule.trigger || "";
        const title = rule.title || "";
        const body = rule.body || "";
        const cooldownHours = rule.cooldownHours || 24;
        const conditionDays = rule.conditionDays || 7;
        const conditionCount = rule.conditionCount || 10;

        console.log(`Processing rule "${title}" (trigger: ${trigger})`);

        try {
            // 2. Find target users based on trigger type
            const targetUserIds = await findUsersForTrigger(db, trigger, conditionDays, conditionCount, now);

            if (targetUserIds.length === 0) {
                console.log(`  No matching users for rule "${title}".`);
                continue;
            }

            console.log(`  Found ${targetUserIds.length} matching user(s).`);

            // 3. Filter out users who received this rule recently (cooldown)
            const eligibleUserIds = await filterByCooldown(db, ruleId, targetUserIds, cooldownHours, now);

            if (eligibleUserIds.length === 0) {
                console.log(`  All users in cooldown for rule "${title}".`);
                continue;
            }

            console.log(`  ${eligibleUserIds.length} user(s) eligible after cooldown filter.`);

            // 4. Send push notifications
            const tokenEntries = await getFCMTokensBatch(eligibleUserIds);
            let successCount = 0;
            let failureCount = 0;

            if (tokenEntries.length > 0) {
                const tokens = tokenEntries.map(e => e.token);
                for (let i = 0; i < tokens.length; i += 500) {
                    const batch = tokens.slice(i, i + 500);
                    const batchEntries = tokenEntries.slice(i, i + 500);
                    const response = await admin.messaging().sendEachForMulticast({
                        tokens: batch,
                        notification: { title, body },
                        android: { collapseKey: `automation_${ruleId}` },
                        apns: {
                            headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`automation_${ruleId}`) },
                            payload: { aps: { sound: "default", badge: 1, "content-available": 1 } }
                        },
                        data: { type: "automation", ruleId, trigger }
                    });
                    successCount += response.successCount;
                    failureCount += response.failureCount;
                    await cleanupInvalidTokens(response, batchEntries);
                }
            }

            console.log(`  Sent: ${successCount} success, ${failureCount} failed.`);

            // 5. Log each user notification to automation_logs (chunked to stay under 500 batch limit)
            const BATCH_LIMIT = 450;
            for (let i = 0; i < eligibleUserIds.length; i += BATCH_LIMIT) {
                const chunk = eligibleUserIds.slice(i, i + BATCH_LIMIT);
                const logBatch = db.batch();
                for (const uid of chunk) {
                    const logRef = db.collection("automation_logs").doc();
                    logBatch.set(logRef, {
                        ruleId,
                        ruleName: title,
                        trigger,
                        targetUserId: uid,
                        title,
                        body,
                        sentAt: admin.firestore.FieldValue.serverTimestamp(),
                        delivered: tokenEntries.some(e => e.uid === uid)
                    });
                }
                await logBatch.commit();
            }

            // 6. Update rule stats
            await ruleDoc.ref.update({
                lastTriggeredAt: admin.firestore.FieldValue.serverTimestamp(),
                totalSent: admin.firestore.FieldValue.increment(eligibleUserIds.length),
                totalDelivered: admin.firestore.FieldValue.increment(successCount)
            });

            console.log(`  Rule "${title}" completed. Logs written.`);

        } catch (error) {
            console.error(`  Error processing rule "${title}":`, error);
        }
    }

    console.log("⚙️ Automation engine finished.");
});

// Helper: Find users matching an automation trigger
async function findUsersForTrigger(db, trigger, conditionDays, conditionCount, now) {
    try {
    const userIds = [];

    switch (trigger) {
        case "new_user": {
            // Users registered in the last 24 hours
            const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
            const snap = await db.collection("users")
                .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(oneDayAgo))
                .get();
            // Also check createTime metadata for users without createdAt field
            if (snap.empty) {
                const allSnap = await db.collection("users").limit(500).get();
                for (const doc of allSnap.docs) {
                    const createTime = doc.createTime ? doc.createTime.toDate() : null;
                    if (createTime && createTime >= oneDayAgo) {
                        userIds.push(doc.id);
                    }
                }
            } else {
                snap.docs.forEach(d => userIds.push(d.id));
            }
            break;
        }

        case "inactive_user": {
            // Users whose lastActive is older than conditionDays
            const thresholdDate = new Date(now.getTime() - conditionDays * 24 * 60 * 60 * 1000);
            const inactiveUsers = await db.collection("users")
                .where("lastActive", "<", admin.firestore.Timestamp.fromDate(thresholdDate))
                .limit(500)
                .get();

            for (const doc of inactiveUsers.docs) {
                if (doc.data().disabled) continue;
                userIds.push(doc.id);
            }

            // Also include users who never had lastActive set
            const noActivityUsers = await db.collection("users")
                .where("lastActive", "==", null)
                .limit(500)
                .get();
            for (const doc of noActivityUsers.docs) {
                if (doc.data().disabled) continue;
                const created = doc.createTime?.toDate() || new Date(0);
                if (created < thresholdDate) userIds.push(doc.id);
            }
            break;
        }

        case "streak_at_risk": {
            // Users with active streaks that haven't been updated today
            const todayStart = new Date(now);
            todayStart.setHours(0, 0, 0, 0);

            const streaks = await db.collection("streaks")
                .where("currentStreak", ">", 0)
                .get();

            const atRiskUserIds = new Set();
            for (const doc of streaks.docs) {
                const data = doc.data();
                const lastExchange = data.lastExchangeDate ? data.lastExchangeDate.toDate() : null;
                // If last exchange was before today, streak is at risk
                if (lastExchange && lastExchange < todayStart) {
                    (data.userIds || []).forEach(uid => atRiskUserIds.add(uid));
                }
            }
            userIds.push(...atRiskUserIds);
            break;
        }

        case "profile_incomplete": {
            // Users without avatar or bio — use filtered queries instead of full scan
            const [noAvatarSnap, emptyAvatarSnap, noBioSnap, emptyBioSnap] = await Promise.all([
                db.collection("users").where("avatarUrl", "==", "").limit(500).get(),
                db.collection("users").where("avatarUrl", "==", null).limit(500).get(),
                db.collection("users").where("bio", "==", "").limit(500).get(),
                db.collection("users").where("bio", "==", null).limit(500).get(),
            ]);
            const seen = new Set();
            for (const snap of [noAvatarSnap, emptyAvatarSnap, noBioSnap, emptyBioSnap]) {
                for (const doc of snap.docs) {
                    if (doc.data().disabled) continue;
                    if (!seen.has(doc.id)) {
                        seen.add(doc.id);
                        userIds.push(doc.id);
                    }
                }
            }
            break;
        }

        case "birthday": {
            // Users whose birthday is today
            const todayMonth = now.getMonth() + 1;
            const todayDay = now.getDate();

            // Try denormalized birthMonth/birthDay fields first
            const fastSnap = await db.collection("users")
                .where("birthMonth", "==", todayMonth)
                .where("birthDay", "==", todayDay)
                .limit(500)
                .get();

            if (!fastSnap.empty) {
                for (const doc of fastSnap.docs) {
                    if (doc.data().disabled) continue;
                    userIds.push(doc.id);
                }
            } else {
                // Fallback: scan with limit for legacy data
                const snap = await db.collection("users").limit(500).get();
                for (const doc of snap.docs) {
                    const data = doc.data();
                    if (data.disabled) continue;
                    if (data.dateOfBirth) {
                        const dob = data.dateOfBirth.toDate ? data.dateOfBirth.toDate() : new Date(data.dateOfBirth);
                        if (dob.getMonth() + 1 === todayMonth && dob.getDate() === todayDay) {
                            userIds.push(doc.id);
                        }
                    }
                }
            }
            break;
        }

        case "no_friends": {
            // Users with no friendships — use friendCount field instead of N+1 subcollection reads
            const [zeroSnap, nullSnap] = await Promise.all([
                db.collection("users").where("friendCount", "==", 0).where("disabled", "!=", true).limit(200).get(),
                db.collection("users").where("friendCount", "==", null).where("disabled", "!=", true).limit(200).get()
            ]);
            const seen = new Set();
            for (const snap of [zeroSnap, nullSnap]) {
                for (const doc of snap.docs) {
                    if (!seen.has(doc.id)) {
                        seen.add(doc.id);
                        userIds.push(doc.id);
                    }
                }
            }
            break;
        }

        case "first_strip": {
            // Users who have never sent a strip — use stripCount field instead of full collection scan
            const [zeroSnap, nullSnap] = await Promise.all([
                db.collection("users").where("stripCount", "==", 0).where("disabled", "!=", true).limit(500).get(),
                db.collection("users").where("stripCount", "==", null).where("disabled", "!=", true).limit(500).get()
            ]);
            const seen = new Set();
            for (const snap of [zeroSnap, nullSnap]) {
                for (const doc of snap.docs) {
                    if (!seen.has(doc.id)) {
                        seen.add(doc.id);
                        userIds.push(doc.id);
                    }
                }
            }
            break;
        }

        case "milestone_strips": {
            // Users who hit a milestone number of strips — use stripCount field
            const snap = await db.collection("users")
                .where("stripCount", "==", conditionCount)
                .where("disabled", "!=", true)
                .limit(500)
                .get();
            for (const doc of snap.docs) {
                userIds.push(doc.id);
            }
            break;
        }

        default:
            console.log(`Unknown trigger type: ${trigger}`);
    }

    return userIds;
    } catch (error) {
        console.error(`findUsersForTrigger error (trigger: ${trigger}):`, error);
        return [];
    }
}

// Helper: Filter out users who already received this rule within cooldown period
async function filterByCooldown(db, ruleId, userIds, cooldownHours, now) {
    const cooldownThreshold = new Date(now.getTime() - cooldownHours * 60 * 60 * 1000);

    // Get recent logs for this rule
    const logsSnap = await db.collection("automation_logs")
        .where("ruleId", "==", ruleId)
        .where("sentAt", ">=", admin.firestore.Timestamp.fromDate(cooldownThreshold))
        .get();

    const recentlyNotified = new Set();
    logsSnap.docs.forEach(d => {
        const targetUserId = d.data().targetUserId;
        if (targetUserId) recentlyNotified.add(targetUserId);
    });

    return userIds.filter(uid => !recentlyNotified.has(uid));
}

// =====================================================
// 15. Automation Trigger on New User Registration
// Immediately checks if there's a "new_user" rule and sends welcome notification.
// =====================================================
exports.onNewUserAutomation = onDocumentCreated({ document: "users/{userId}", region: "europe-west1" }, async (event) => {
    const db = admin.firestore();
    const userId = event.params.userId;
    const now = new Date();

    // Check for enabled new_user automation rules
    const rulesSnap = await db.collection("automation_rules")
        .where("trigger", "==", "new_user")
        .where("enabled", "==", true)
        .get();

    if (rulesSnap.empty) return;

    for (const ruleDoc of rulesSnap.docs) {
        const rule = ruleDoc.data();
        const delayMinutes = rule.delayMinutes || 0;

        if (delayMinutes > 0) {
            // Schedule for later — create a scheduled notification
            await db.collection("scheduled_notifications").add({
                title: rule.title || "",
                body: rule.body || "",
                targetType: "specific",
                targetUserIds: [userId],
                scheduledAt: admin.firestore.Timestamp.fromDate(
                    new Date(now.getTime() + delayMinutes * 60 * 1000)
                ),
                createdBy: "automation",
                sent: false,
                automationRuleId: ruleDoc.id
            });
            console.log(`Scheduled welcome notification for user ${userId} in ${delayMinutes} minutes.`);
        } else {
            // Send immediately
            const token = await getFCMToken(userId);
            if (token) {
                try {
                    await admin.messaging().send({
                        token,
                        notification: { title: rule.title, body: rule.body },
                        android: { collapseKey: `a_${ruleDoc.id}` },
                        apns: {
                            headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`a_${ruleDoc.id}`) },
                            payload: { aps: { sound: "default", badge: 1, "content-available": 1 } }
                        },
                        data: { type: "automation", ruleId: ruleDoc.id, trigger: "new_user" }
                    });
                    console.log(`Sent welcome notification to user ${userId}.`);
                } catch (e) {
                    console.error(`Failed to send welcome notification to ${userId}:`, e);
                }
            }

            // Log it
            await db.collection("automation_logs").add({
                ruleId: ruleDoc.id,
                ruleName: rule.title || "",
                trigger: "new_user",
                targetUserId: userId,
                title: rule.title || "",
                body: rule.body || "",
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                delivered: !!token
            });

            // Update stats
            await ruleDoc.ref.update({
                lastTriggeredAt: admin.firestore.FieldValue.serverTimestamp(),
                totalSent: admin.firestore.FieldValue.increment(1),
                totalDelivered: admin.firestore.FieldValue.increment(token ? 1 : 0)
            });
        }
    }
});

// 13. Process Scheduled Notifications
exports.processScheduledNotifications = onSchedule({ schedule: "every 5 minutes", region: "europe-west1" }, async (event) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snapshot = await db.collection("scheduled_notifications")
        .where("sent", "==", false)
        .where("scheduledAt", "<=", now)
        .limit(20)
        .get();

    if (snapshot.empty) {
        console.log("No scheduled notifications to process.");
        return;
    }

    console.log(`Processing ${snapshot.size} scheduled notification(s)...`);

    // Staleness guard: skip notifications scheduled more than 24 hours ago
    const staleThreshold = new Date(Date.now() - 24 * 60 * 60 * 1000);

    for (const doc of snapshot.docs) {
        const data = doc.data();

        // Skip stale notifications — mark them sent without delivering
        const scheduledDate = data.scheduledAt?.toDate ? data.scheduledAt.toDate() : null;
        if (scheduledDate && scheduledDate < staleThreshold) {
            console.log(`Skipping stale scheduled notification ${doc.id} (scheduled at ${scheduledDate.toISOString()})`);
            await doc.ref.update({ sent: true, skippedStale: true, sentAt: admin.firestore.FieldValue.serverTimestamp() });
            continue;
        }

        try {
            // Create notification_logs entry (triggers onAdminNotification)
            const logEntry = {
                title: data.title || "",
                body: data.body || "",
                targetType: data.targetType || "all",
                sentBy: data.createdBy || "scheduled",
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                targetCount: 0,
                scheduledNotificationId: doc.id
            };
            // Forward targetUserIds for "specific" target type
            if (data.targetUserIds && data.targetUserIds.length > 0) {
                logEntry.targetUserIds = data.targetUserIds;
            }
            await db.collection("notification_logs").add(logEntry);

            // Mark as sent
            await doc.ref.update({
                sent: true,
                sentAt: admin.firestore.FieldValue.serverTimestamp()
            });

            console.log(`Scheduled notification ${doc.id} processed successfully.`);
        } catch (error) {
            console.error(`Error processing scheduled notification ${doc.id}:`, error);
        }
    }
});

// ── Nudge / Dürtme ──────────────────────────────────────────────────────────
// Triggered when a nudge document is created under the receiver's nudges subcollection.
// Validates daily limit (max 3 per sender→receiver pair per day), then sends FCM push.
exports.onNudgeSent = onDocumentCreated({ document: "users/{userId}/nudges/{nudgeId}", region: "europe-west1" }, async (event) => {
    const nudgeData = event.data.data();
    if (!nudgeData) return;

    const receiverId = event.params.userId;
    const senderId = nudgeData.senderId;

    if (!senderId || senderId === receiverId) return;

    updateLastActive(senderId);

    const db = admin.firestore();

    // Check if sender is blocked by receiver
    try {
        const blockedDoc = await db.collection("users").doc(receiverId)
            .collection("blocked").doc(senderId).get();
        if (blockedDoc.exists) {
            console.log(`Nudge blocked: ${senderId} is blocked by ${receiverId}`);
            await event.data.ref.delete();
            return;
        }
        // Also check if receiver is blocked by sender
        const reverseBlock = await db.collection("users").doc(senderId)
            .collection("blocked").doc(receiverId).get();
        if (reverseBlock.exists) {
            await event.data.ref.delete();
            return;
        }
        // Verify they are actually friends
        const friendDoc = await db.collection("users").doc(senderId)
            .collection("friendships").doc(receiverId).get();
        if (!friendDoc.exists || friendDoc.data().isPending) {
            console.log(`Nudge rejected: ${senderId} and ${receiverId} are not friends`);
            await event.data.ref.delete();
            return;
        }
    } catch (e) {
        console.error("Error checking nudge eligibility:", e);
        return;
    }

    // Check daily limit: max 3 nudges from this sender to this receiver today
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    try {
        const todayNudges = await db.collection("users").doc(receiverId)
            .collection("nudges")
            .where("senderId", "==", senderId)
            .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
            .get();

        if (todayNudges.size > 3) {
            console.log(`Nudge daily limit exceeded: ${senderId} -> ${receiverId} (${todayNudges.size})`);
            // Delete the excess nudge document
            await event.data.ref.delete();
            return;
        }
    } catch (e) {
        console.error("Error checking nudge limit:", e);
    }

    // Get sender name
    const receiverDoc = await db.collection("users").doc(receiverId).get();
    const receiverCopy = copyForUser(receiverDoc.exists ? receiverDoc.data() : null);
    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.exists
        ? (senderDoc.data().displayName || senderDoc.data().username || receiverCopy.someone)
        : receiverCopy.someone;

    // Get receiver FCM token
    const receiverToken = await getFCMToken(receiverId);
    if (!receiverToken) return;

    // Check silent hours & notification preferences
    if (await isSilentHoursForUser(receiverId)) return;
    if (!(await shouldSendNotification(receiverId, "nudge"))) return;

    // Send FCM notification
    try {
        await admin.messaging().send({
            token: receiverToken,
            android: { collapseKey: `n_${senderId}` },
            apns: {
                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapseId(`n_${senderId}`) },
                payload: {
                    aps: {
                        alert: { title: receiverCopy.brandTitle, body: receiverCopy.nudgeBody(senderName) },
                        sound: "default",
                        badge: 1,
                        "content-available": 1,
                        "mutable-content": 1,
                        "thread-id": "nudges"
                    }
                }
            },
            data: { type: "nudge", senderId, senderName }
        });
        console.log(`Nudge notification sent: ${senderId} -> ${receiverId}`);
    } catch (error) {
        console.error("Error sending nudge notification:", error);
        // Clean up invalid token
        if (error.code === "messaging/registration-token-not-registered" ||
            error.code === "messaging/invalid-registration-token") {
            const tokenDoc = db.collection("users").doc(receiverId).collection("private").doc("tokens");
            await tokenDoc.update({ fcmToken: admin.firestore.FieldValue.delete() }).catch(() => {});
            console.log(`Cleaned up invalid FCM token for ${receiverId}`);
        }
    }
});

// Admin: Disable/enable a user account
exports.adminSetUserStatus = onCall({ maxInstances: 5, region: "europe-west1" }, async (request) => {
    // Verify admin
    if (!request.auth || !request.auth.token.admin) {
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    }

    const { userId, disabled, reason } = request.data;
    if (!userId) throw new functions.https.HttpsError("invalid-argument", "userId required");

    const db = admin.firestore();

    // Update user doc
    await db.collection("users").doc(userId).update({
        disabled: disabled === true,
        disabledReason: reason || "",
        disabledAt: disabled ? admin.firestore.FieldValue.serverTimestamp() : admin.firestore.FieldValue.delete(),
        disabledBy: request.auth.uid
    });

    // Log admin action
    await db.collection("admin_audit_log").add({
        action: disabled ? "disable_user" : "enable_user",
        targetUserId: userId,
        adminId: request.auth.uid,
        reason: reason || "",
        timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Admin ${request.auth.uid} ${disabled ? "disabled" : "enabled"} user ${userId}`);
    return { success: true };
});

// ── Contact Sync: match phone hashes against registered users ──
// NOTE: phoneNumberHash should be stored on the user document at registration time.
// When a new user registers, write SHA-256(normalizedPhone) to users/{uid}.phoneNumberHash.
exports.matchContacts = onCall({ maxInstances: 10, region: "europe-west1" }, async (request) => {
    // 1. Auth check
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const callerId = request.auth.uid;
    const firestore = admin.firestore();

    // 2. Rate limit: max 3 calls/day per user
    const metaRef = firestore.doc(`users/${callerId}/private/contactSyncMeta`);
    const meta = await metaRef.get();
    const today = new Date().toISOString().split("T")[0];
    if (meta.exists) {
        const d = meta.data();
        if (d.lastSyncDate === today && (d.syncCount || 0) >= 3) {
            throw new HttpsError("resource-exhausted", "Daily sync limit reached");
        }
    }

    // 3. Validate input
    const { phoneHashes } = request.data;
    if (!Array.isArray(phoneHashes) || phoneHashes.length === 0) {
        throw new HttpsError("invalid-argument", "phoneHashes required");
    }
    const hashes = phoneHashes.slice(0, 500);

    // 4. Query in batches of 30 (Firestore 'in' limit)
    const results = [];
    for (let i = 0; i < hashes.length; i += 30) {
        const batch = hashes.slice(i, i + 30);
        const snap = await firestore.collection("users")
            .where("phoneNumberHash", "in", batch)
            .get();
        snap.forEach(doc => {
            if (doc.id === callerId) return; // skip self
            const d = doc.data();
            results.push({
                userId: doc.id,
                displayName: d.displayName || "",
                username: d.username || "",
                avatarUrl: d.avatarUrl || ""
            });
        });
    }

    // 5. Update rate limit meta
    await metaRef.set({
        lastSyncDate: today,
        syncCount: meta.exists && meta.data().lastSyncDate === today ? (meta.data().syncCount || 0) + 1 : 1
    });

    return { matches: results };
});

// ── SERVER-SIDE AGE GATE ──
// Blocks account creation if the user's custom claims or metadata suggest underage.
// This is a defense-in-depth measure — clients also validate, but this prevents
// direct Firebase Auth REST API bypass. Requires the client to pass dateOfBirth
// as a custom claim or the server to check after profile creation.
//
// Note: beforeUserCreated fires BEFORE the user document exists in Firestore,
// so we use a Firestore onCreate trigger as a secondary check instead.
exports.validateAgeOnProfileCreate = onDocumentCreated({ document: "users/{userId}", region: "europe-west1" }, async (event) => {
    const data = event.data.data();
    if (!data) return;

    const dateOfBirth = data.dateOfBirth;
    if (!dateOfBirth) return; // No DOB provided — cannot enforce (legacy users)

    const dob = dateOfBirth.toDate ? dateOfBirth.toDate() : new Date(dateOfBirth);
    const now = new Date();
    const ageDiff = now.getFullYear() - dob.getFullYear();
    const monthDiff = now.getMonth() - dob.getMonth();
    const dayDiff = now.getDate() - dob.getDate();
    const age = monthDiff < 0 || (monthDiff === 0 && dayDiff < 0) ? ageDiff - 1 : ageDiff;

    if (age < 16) {
        console.warn(`Age gate: blocking user ${event.params.userId} (age=${age}). Disabling account and deleting document.`);
        try {
            // Disable the Firebase Auth account
            await admin.auth().updateUser(event.params.userId, { disabled: true });
            // Delete the user document
            await event.data.ref.delete();
        } catch (e) {
            console.error("Age gate enforcement error:", e.message);
        }
    }
});

// ── COLD-START WELCOME STRIPS ──
// On user document creation, write 3 "welcome" strips into /strips so the new
// user's history feed isn't empty before they add a friend. The system bot
// "anlik_system_bot" is the senderId; receiverIds = [userId] so only that
// user sees them. Idempotent via the welcomeSeeded flag.
exports.seedWelcomeStrips = onDocumentCreated({ document: "users/{userId}", region: "europe-west1" }, async (event) => {
    const userId = event.params.userId;
    const userData = event.data ? event.data.data() : null;
    if (!userData) return;

    // Idempotency: skip if already seeded (e.g., if function retries)
    if (userData.welcomeSeeded === true) return;

    const bot = "anlik_system_bot";
    const now = admin.firestore.FieldValue.serverTimestamp();
    const senderProfile = {
        displayName: "anlık.",
        username: "anlik",
        avatarUrl: "system://avatars/anlik"
    };

    const strips = [
        {
            id: `welcome_${userId}_1`,
            senderId: bot,
            receiverIds: [userId],
            imageUrl: "system://welcome/1",
            timestamp: now,
            isSecret: false,
            flagged: false,
            reactions: {},
            isWelcomeStrip: true,
            welcomeKind: "intro",
            senderProfileSnapshot: senderProfile,
            comment: "merhaba 👋 burası senin anlık kareleri akışın"
        },
        {
            id: `welcome_${userId}_2`,
            senderId: bot,
            receiverIds: [userId],
            imageUrl: "system://welcome/2",
            timestamp: now,
            latitude: 41.0082,
            longitude: 28.9784,
            cityName: "Istanbul",
            isSecret: false,
            flagged: false,
            reactions: {},
            isWelcomeStrip: true,
            welcomeKind: "location",
            senderProfileSnapshot: senderProfile,
            comment: "konumunu eklersen arkadaşların nerede olduğunu görür"
        },
        {
            id: `welcome_${userId}_3`,
            senderId: bot,
            receiverIds: [userId],
            imageUrl: "system://welcome/3",
            timestamp: now,
            isSecret: false,
            flagged: false,
            reactions: {},
            isWelcomeStrip: true,
            welcomeKind: "howto",
            senderProfileSnapshot: senderProfile,
            comment: "kameraya geç, ilk anını yakala. arkadaşların seni bekliyor."
        }
    ];

    const batch = admin.firestore().batch();
    for (const strip of strips) {
        const ref = admin.firestore().collection("strips").doc(strip.id);
        batch.set(ref, strip);
    }
    // Mark user as seeded so we never repeat
    const userRef = admin.firestore().collection("users").doc(userId);
    batch.update(userRef, { welcomeSeeded: true });

    try {
        await batch.commit();
        console.log(`seedWelcomeStrips: seeded 3 strips for user ${userId}`);
    } catch (e) {
        console.error(`seedWelcomeStrips failed for ${userId}:`, e.message);
    }
});

// ── ONE-SHOT MAINTENANCE TOGGLE ──
// HTTP endpoint to flip the maintenance flag. Auth via shared secret in the
// query string. Used to disable maintenance mode quickly when an old App Store
// build is locking real users out and the new build hasn't shipped yet.
//
// IMPORTANT: Remove this function after the issue is resolved — it's a
// one-shot operational tool, not a permanent API.
exports.toggleMaintenance = onRequest({ region: "europe-west1", cors: true }, async (req, res) => {
    const SECRET = "anlik-maint-2026-04-26-flip";
    if (req.query.secret !== SECRET) {
        res.status(403).json({ error: "forbidden" });
        return;
    }
    const enabled = req.query.enabled === "true";
    try {
        await admin.firestore().collection("app_config").doc("settings").set(
            {
                maintenanceMode: enabled,
                maintenanceMessage: enabled
                    ? "Uygulama bakımda. Lütfen daha sonra tekrar deneyin."
                    : ""
            },
            { merge: true }
        );
        const doc = await admin.firestore().collection("app_config").doc("settings").get();
        res.json({ ok: true, after: doc.data() });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── SET ANDROID VERSION CONFIG ──
// One-shot HTTP endpoint to update the in-app update version metadata at
// app_config/settings. Secret-protected — flip in browser/curl after a release.
exports.setAndroidVersion = onRequest({ region: "europe-west1", cors: true }, async (req, res) => {
    const SECRET = "anlik-version-2026";
    if (req.query.secret !== SECRET) {
        res.status(403).json({ error: "forbidden" });
        return;
    }
    try {
        const data = {};
        if (req.query.versionCode) data.androidLatestVersionCode = Number(req.query.versionCode);
        if (req.query.versionName) data.androidLatestVersionName = String(req.query.versionName);
        if (req.query.apkUrl) data.androidApkUrl = String(req.query.apkUrl);
        if (req.query.minRequired !== undefined) data.androidMinRequiredVersionCode = Number(req.query.minRequired);
        if (req.query.notes) data.androidUpdateNotes = String(req.query.notes);
        await admin.firestore().collection("app_config").doc("settings").set(data, { merge: true });
        const doc = await admin.firestore().collection("app_config").doc("settings").get();
        res.json({ ok: true, after: doc.data() });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── ACCEPT INVITE ──
// Atomically creates a bilateral accepted friendship between the authenticated
// caller and the user who owns `inviteCode`. Used by the deep-link/clipboard
// flow so SMS-invited users land in the app already connected to their inviter.
//
// Idempotent: re-calling for an existing accepted friendship is a no-op.
// Self-invite (caller is the inviter) is rejected.
exports.acceptInvite = onCall({ maxInstances: 10, region: "europe-west1" }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const callerId = request.auth.uid;
    const code = (request.data && request.data.inviteCode) || "";
    const trimmed = String(code).trim().toUpperCase();
    if (trimmed.length < 4 || trimmed.length > 16) {
        throw new HttpsError("invalid-argument", "inviteCode invalid");
    }
    const firestore = admin.firestore();

    // Find inviter by code
    const snap = await firestore.collection("users")
        .where("inviteCode", "==", trimmed)
        .limit(1)
        .get();
    if (snap.empty) throw new HttpsError("not-found", "Invite code not found");
    const inviter = snap.docs[0];
    const inviterId = inviter.id;

    if (inviterId === callerId) {
        // Self-invite — silent success so the client UX doesn't show an error.
        return { ok: true, inviter: null, alreadyFriends: false };
    }

    // Check if either side is blocked — refuse to bridge a blocked relationship.
    const [callerBlocked, inviterBlocked] = await Promise.all([
        firestore.doc(`users/${callerId}/blocked/${inviterId}`).get(),
        firestore.doc(`users/${inviterId}/blocked/${callerId}`).get()
    ]);
    if (callerBlocked.exists || inviterBlocked.exists) {
        throw new HttpsError("permission-denied", "blocked");
    }

    // Idempotency: if friendship exists and accepted, return success without write.
    const existing = await firestore.doc(`users/${callerId}/friendships/${inviterId}`).get();
    if (existing.exists && existing.data().isPending === false) {
        return {
            ok: true,
            alreadyFriends: true,
            inviter: {
                userId: inviterId,
                displayName: inviter.data().displayName || "",
                username: inviter.data().username || "",
                avatarUrl: inviter.data().avatarUrl || ""
            }
        };
    }

    // Atomic bilateral write — both sides start as accepted (isPending=false)
    // since the invite link is treated as mutual consent (inviter sent the link;
    // invitee acted on it).
    const batch = firestore.batch();
    const now = admin.firestore.FieldValue.serverTimestamp();
    batch.set(firestore.doc(`users/${callerId}/friendships/${inviterId}`), {
        userId: inviterId,
        isPending: false,
        requesterId: inviterId,
        timestamp: now
    }, { merge: true });
    batch.set(firestore.doc(`users/${inviterId}/friendships/${callerId}`), {
        userId: callerId,
        isPending: false,
        requesterId: inviterId,
        timestamp: now
    }, { merge: true });
    await batch.commit();

    return {
        ok: true,
        alreadyFriends: false,
        inviter: {
            userId: inviterId,
            displayName: inviter.data().displayName || "",
            username: inviter.data().username || "",
            avatarUrl: inviter.data().avatarUrl || ""
        }
    };
});
