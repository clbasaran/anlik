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

// Helper: Update user's lastActive timestamp (fire-and-forget, non-blocking)
function updateLastActive(userId) {
    if (!userId) return;
    admin.firestore().collection("users").doc(userId)
        .update({ lastActive: admin.firestore.FieldValue.serverTimestamp() })
        .catch(() => {}); // ignore errors — non-critical
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
                const turkeyHour = (now.getUTCHours() + 3) % 24;
                if (start > end) {
                    // Overnight range (e.g., 23:00 - 07:00)
                    return turkeyHour >= start || turkeyHour < end;
                } else {
                    // Same-day range (e.g., 14:00 - 18:00)
                    return turkeyHour >= start && turkeyHour < end;
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
        const key = `notif_${type}`;
        return prefs[key] !== false;
    } catch (e) { return true; }
}

// Helper: Check if senderId is blocked by receiverId (bidirectional)
async function isBlockedBetween(senderId, receiverId) {
    try {
        const [blocked, reverseBlocked] = await Promise.all([
            admin.firestore().collection("users").doc(receiverId).collection("blocked").doc(senderId).get(),
            admin.firestore().collection("users").doc(senderId).collection("blocked").doc(receiverId).get()
        ]);
        return blocked.exists || reverseBlocked.exists;
    } catch (e) { return false; }
}

// Helper: Get FCM token from private subcollection (secure path)
async function getFCMToken(userId) {
    const privateDoc = await admin.firestore().collection("users").doc(userId).collection("private").doc("tokens").get();
    if (privateDoc.exists && privateDoc.data().fcmToken) {
        return privateDoc.data().fcmToken;
    }
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (userDoc.exists && userDoc.data().fcmToken) {
        return userDoc.data().fcmToken;
    }
    return null;
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
            const doc = await admin.firestore().collection("users").doc(uid).collection("private").doc("tokens").get();
            const token = doc.exists ? (doc.data().widgetPushToken || null) : null;
            return { uid, token };
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
                    "apns-priority": "5",
                    "content-type": "application/json"
                });

                let data = "";
                let statusCode = 0;
                req.on("response", (headers) => { statusCode = headers[":status"]; });
                req.on("data", (chunk) => data += chunk);
                req.on("end", () => { client.close(); resolve({ statusCode, data, token: token.substring(0, 8) }); });
                req.on("error", (err) => { client.close(); reject(err); });
                req.write(JSON.stringify({ aps: { "content-changed": true } }));
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
    const batch = admin.firestore().batch();
    let cleanupCount = 0;
    response.responses.forEach((resp, idx) => {
        if (resp.error && invalidCodes.includes(resp.error.code)) {
            const uid = tokenEntries[idx]?.uid;
            if (uid) {
                const tokenRef = admin.firestore().collection("users").doc(uid).collection("private").doc("tokens");
                batch.update(tokenRef, { fcmToken: admin.firestore.FieldValue.delete() });
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
        const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
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
    const senderName = senderDoc.exists ? (senderDoc.data().displayName || senderDoc.data().username || "Someone") : "Someone";

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
    await Promise.all(streakRecipients.map(async (receiverId) => {
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

    // ── PUSH NOTIFICATIONS (with per-user silent hours + preferences check) ──
    
    // Filter recipients based on notification preferences AND per-user silent hours
    const filteredRecipients = [];
    for (const rid of unblockedRecipientIds) {
        if (await isSilentHoursForUser(rid)) continue;
        if (await shouldSendNotification(rid, "strips")) filteredRecipients.push(rid);
    }
    
    const tokenEntries = await getFCMTokensBatch(filteredRecipients);
    const tokens = tokenEntries.map(e => e.token);

    if (tokens.length > 0) {
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

            const notificationBody = isSecret
                ? `${senderName} sana gizli bir an gönderdi. açmak için sen de bir an paylaş!`
                : `${senderName} sana yeni bir an paylaştı.`;

            // 1. Visible notification (alert + image attachment via NSE)
            const response = await admin.messaging().sendEachForMulticast({
                tokens,
                android: { collapseKey: `strip_${event.params.stripId}` },
                apns: {
                    headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `strip_${event.params.stripId}` },
                    payload: {
                        aps: {
                            alert: { title: isSecret ? "gizli an" : "anlık.", body: notificationBody },
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
            console.log(`Strip multicast: ${response.successCount} success, ${response.failureCount} failed`);
            await cleanupInvalidTokens(response, tokenEntries);

        } catch (error) { console.error("Error sending strip multicast:", error); }
    }

    // 2. Widget push via APNs — triggers WidgetKit timeline reload instantly
    // Delay 5s so NSE has time to download image to shared container first
    try {
        const widgetTokenEntries = await getWidgetPushTokensBatch(unblockedRecipientIds);
        console.log(`Widget push: found ${widgetTokenEntries.length} tokens for ${unblockedRecipientIds.length} recipients`);
        if (widgetTokenEntries.length > 0) {
            await new Promise(resolve => setTimeout(resolve, 5000));
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

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderName = senderDoc.exists ? (senderDoc.data().displayName || senderDoc.data().username || "Someone") : "Someone";

    const receiverToken = await getFCMToken(receiverId);
    if (!receiverToken) return;
    if (await isSilentHoursForUser(receiverId)) return;
    if (!(await shouldSendNotification(receiverId, "dms"))) return;

    try {
        await admin.messaging().send({
            token: receiverToken,
            android: { collapseKey: `dm_${threadId}_${event.params.messageId}` },
            apns: {
                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `dm_${threadId}_${event.params.messageId}` },
                payload: {
                    aps: {
                        alert: { title: `anlık. — ${senderName}`, body: msgData.text || "Bir mesaj gönderdi" },
                        sound: "dm_message.caf",
                        badge: 1,
                        "content-available": 1,
                        "mutable-content": 1,
                        "thread-id": threadId,
                        category: "direct_message"
                    }
                }
            },
            data: { type: "direct_message", threadId, senderId, senderName, messageText: msgData.text || "" }
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

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderName = senderDoc.exists ? (senderDoc.data().displayName || senderDoc.data().username || "Someone") : "Someone";

    const tokenEntries = await getFCMTokensBatch([notifyUserId]);
    const tokens = tokenEntries.map(e => e.token);

    if (tokens.length > 0) {
        try {
            const response = await admin.messaging().sendEachForMulticast({
                tokens,
                android: { collapseKey: `chat_${stripId}_${event.params.messageId}` },
                apns: {
                    headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `chat_${stripId}_${event.params.messageId}` },
                    payload: {
                        aps: {
                            alert: { title: "anlık.", body: `${senderName}: ${messageData.text || "anına tepki verdi"}` },
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
                data: { type: "new_strip_chat", stripId, relatedId: stripId, receiverId, senderId, senderName, messageText: messageData.text || "" }
            });
            console.log(`Strip chat notification: ${response.successCount} success, ${response.failureCount} failed`);
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

    const userToken = await getFCMToken(userId);
    if (!userToken) return;

    const messageText = msgData.text || "Destek ekibinden yeni mesaj";

    try {
        await admin.messaging().send({
            token: userToken,
            android: { collapseKey: `support_${userId}_${event.params.messageId}` },
            apns: {
                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `support_${userId}_${event.params.messageId}` },
                payload: {
                    aps: {
                        alert: { title: "anlık. destek", body: messageText },
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

    const requesterDoc = await admin.firestore().collection("users").doc(requesterId).get();
    const requesterName = requesterDoc.exists ? (requesterDoc.data().displayName || requesterDoc.data().username || "Someone") : "Someone";

    const receiverToken = await getFCMToken(userId);
    if (!receiverToken) return;
    if (await isSilentHoursForUser(userId)) return;
    if (!(await shouldSendNotification(userId, "friends"))) return;

    try {
        await admin.messaging().send({
            token: receiverToken,
            android: { collapseKey: `friend_${requesterId}` },
            apns: {
                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `friend_${requesterId}` },
                payload: {
                    aps: {
                        alert: { title: "anlık.", body: `${requesterName} arkadaş olmak istiyor.` },
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
                
                // Content moderation via Cloud Vision SafeSearch
                try {
                    const vision = require("@google-cloud/vision");
                    const client = new vision.ImageAnnotatorClient();
                    const [result] = await client.safeSearchDetection(`gs://${object.bucket}/${filePath}`);
                    const safe = result.safeSearchAnnotation;
                    if (safe.adult === "VERY_LIKELY" || safe.violence === "VERY_LIKELY") {
                        await stripRef.update({ flagged: true, flagReason: "auto_moderation" });
                        console.log(`⚠️ Strip ${stripId} flagged for moderation (adult: ${safe.adult}, violence: ${safe.violence})`);
                    }
                } catch (visionError) {
                    // If Vision API fails, let the photo through — do NOT flag it.
                    // Flagging on API failure was causing ALL photos to disappear from feed.
                    console.warn(`Content moderation skipped for ${stripId} (Vision API unavailable):`, visionError.message);
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

// 5b. ONE-TIME FIX: Unflag all strips that were incorrectly flagged due to Vision API failures
// Call via: firebase functions:shell → unflagModerationUnavailable()
// Or via HTTP: https://REGION-PROJECT.cloudfunctions.net/unflagModerationUnavailable
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
exports.unflagModerationUnavailable = onRequest({ region: "europe-west1" }, async (req, res) => {
    // Admin auth check
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
        res.status(403).json({ error: "Missing or invalid Authorization header" });
        return;
    }
    try {
        const idToken = authHeader.split("Bearer ")[1];
        const decoded = await admin.auth().verifyIdToken(idToken);
        if (decoded.admin !== true) {
            res.status(403).json({ error: "Forbidden: admin claim required" });
            return;
        }
    } catch (e) {
        res.status(403).json({ error: "Invalid token: " + e.message });
        return;
    }

    let totalFixed = 0;
    let hasMore = true;
    while (hasMore) {
        const flagged = await admin.firestore().collection("strips")
            .where("flagged", "==", true)
            .where("flagReason", "==", "moderation_unavailable")
            .limit(200)
            .get();
        if (flagged.empty) { hasMore = false; break; }
        const batch = admin.firestore().batch();
        flagged.docs.forEach(doc => {
            batch.update(doc.ref, { flagged: false, flagReason: admin.firestore.FieldValue.delete() });
        });
        await batch.commit();
        totalFixed += flagged.size;
    }
    console.log(`Unflagged ${totalFixed} incorrectly flagged strips.`);
    res.json({ success: true, totalFixed });
});

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

    // Topic-based push — single message to all subscribed users
    try {
        await admin.messaging().send({
            topic: "daily_prompt",
            notification: { title: `${selected.emoji} hey, bugün seni bekliyoruz!`, body: selected.text },
            android: { collapseKey: `prompt_${dateStr}` },
            apns: { headers: { "apns-priority": "5", "apns-push-type": "alert", "apns-collapse-id": `prompt_${dateStr}` }, payload: { aps: { sound: "daily_prompt.caf", badge: 1, "content-available": 1 } } },
            data: { type: "daily_prompt", promptDate: dateStr },
        });
        console.log("Daily prompt topic push sent.");
    } catch (error) { console.error("Prompt push error:", error); }
});

// 8. Streak Expiry Check
exports.checkStreakExpiry = onSchedule({ schedule: "every day 04:00", region: "europe-west1" }, async (event) => {
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000);
    const expiredStreaks = await admin.firestore().collection("streaks")
        .where("currentStreak", ">", 0)
        .where("lastExchangeDate", "<", twoDaysAgo)
        .limit(500).get();

    if (expiredStreaks.empty) { console.log("No expired streaks."); return; }

    const batch = admin.firestore().batch();
    let resetCount = 0;

    for (const doc of expiredStreaks.docs) {
        const data = doc.data();
        const currentStreak = data.currentStreak || 0;
        if (currentStreak >= 3) {
            const tokenEntries = await getFCMTokensBatch(data.userIds || []);
            const tokens = tokenEntries.map(e => e.token);
            if (tokens.length > 0) {
                try {
                    await admin.messaging().sendEachForMulticast({
                        tokens,
                        notification: { title: "anlık. — 💔 Seri Bitti", body: `${currentStreak} günlük serin sona erdi. Yeni bir an paylaş ve tekrar başla!` },
                        android: { collapseKey: `streak_lost_${doc.id}` },
                        apns: { headers: { "apns-priority": "5", "apns-push-type": "alert", "apns-collapse-id": `streak_lost_${doc.id}` }, payload: { aps: { sound: "streak_alert.caf", badge: 1 } } },
                        data: { type: "streak_lost", streakCount: String(currentStreak) },
                    });
                } catch (e) {}
            }
        }
        batch.update(doc.ref, {
            currentStreak: 0,
            friendshipScore: Math.min(400, Math.floor(Math.log2((data.totalExchanges || 1) + 1) * 45)),
        });
        resetCount++;
    }
    await batch.commit();
    console.log(`Streak expiry: ${resetCount} reset.`);
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
            const displayName = userDoc.data().displayName || "hey";

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
                body = "bu hafta biraz sessizdin, arkadaşların seni bekliyor 👀";
            } else if (totalLastWeek > 0 && totalThisWeek > totalLastWeek) {
                const growth = Math.round(((totalThisWeek - totalLastWeek) / totalLastWeek) * 100);
                body = `geçen haftaya göre %${growth} daha aktif bir hafta geçirdin! 🚀`;
            } else if (streakCount > 0 && topFriendName) {
                body = `${streakCount} aktif serin var! en çok ${topFriendName} ile paylaştın 🔥`;
            } else if (topFriendName) {
                body = `bu hafta ${totalThisWeek} an! en çok ${topFriendName} ile paylaştın 📸`;
            } else {
                body = `bu hafta ${sentCount} an paylaştın, ${recvCount} an aldın.${streakCount > 0 ? ` ${streakCount} aktif serin var!` : ""}`;
            }

            await admin.messaging().send({
                token,
                notification: { title: "anlık. — haftalık özet 📊", body },
                android: { collapseKey: `weekly_${year}_w${weekNumber}` },
                apns: { headers: { "apns-priority": "5", "apns-collapse-id": `weekly_${year}_w${weekNumber}` }, payload: { aps: { sound: "daily_prompt.caf" } } },
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

    console.log(`Cascading delete for user: ${userId}`);

    try {
        // 1. Delete user's strips and their comments + storage files
        const userStrips = await db.collection("strips").where("senderId", "==", userId).get();
        for (const doc of userStrips.docs) {
            const data = doc.data();
            // Delete comments subcollection
            const comments = await doc.ref.collection("comments").get();
            if (!comments.empty) {
                await batchDeleteRefs(comments.docs.map(c => c.ref));
            }
            // Delete storage files
            if (data.imageUrl) {
                try {
                    const url = new URL(data.imageUrl);
                    const pathParts = decodeURIComponent(url.pathname).split("/o/")[1];
                    if (pathParts) {
                        const fp = pathParts.split("?")[0];
                        await storage.file(fp).delete().catch(() => {});
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

        // 6. Delete DM threads
        const dmThreads = await db.collectionGroup("messages").where("senderId", "==", userId).get();
        if (!dmThreads.empty) await batchDeleteRefs(dmThreads.docs.map(d => d.ref));

        // 7. Delete private subcollection
        const privateTokens = await db.collection("users").doc(userId).collection("private").get();
        if (!privateTokens.empty) await batchDeleteRefs(privateTokens.docs.map(d => d.ref));

        // 8. Delete user document
        await db.collection("users").doc(userId).delete();

        // 9. Delete avatar from storage
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
                            headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `admin_${event.params.logId}` },
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
                    headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `admin_${event.params.logId}` },
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
                                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `admin_${event.params.logId}` },
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
                            headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `automation_${ruleId}` },
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

            // 5. Log each user notification to automation_logs
            const logBatch = db.batch();
            for (const uid of eligibleUserIds) {
                const logRef = db.collection("automation_logs").doc();
                logRef; // reference
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
                        android: { collapseKey: `automation_${ruleDoc.id}_${userId}` },
                        apns: {
                            headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `automation_${ruleDoc.id}_${userId}` },
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
    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.exists
        ? (senderDoc.data().displayName || senderDoc.data().username || "Birisi")
        : "Birisi";

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
            android: { collapseKey: `nudge_${senderId}_${receiverId}` },
            apns: {
                headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": `nudge_${senderId}_${receiverId}` },
                payload: {
                    aps: {
                        alert: { title: "anlık.", body: `${senderName} seni dürtü! 📸` },
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

