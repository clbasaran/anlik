#!/bin/bash
set -e

echo "🚀 Starting automated Firebase Cloud Functions deployment for Push Notifications..."

if ! command -v firebase &> /dev/null
then
    echo "❌ firebase-tools not found. Please run setup script first."
    exit 1
fi

echo "📦 Initializing Functions Directory..."
# We use a temp directory to build the function to keep the main repo ultra clean
mkdir -p functions
cd functions

echo "📝 Creating package.json..."
cat > package.json << 'EOF'
{
  "name": "stripmate-functions",
  "description": "Cloud Functions for StripMate",
  "scripts": {
    "lint": "eslint .",
    "serve": "firebase serve --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "22"
  },
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^11.8.0",
    "firebase-functions": "^4.3.1"
  }
}
EOF

echo "📝 Creating index.js (Cloud Function Logic)..."
cat > index.js << 'EOF'
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// 1. Send push notification when a new photo is sent
exports.onNewStrip = onDocumentCreated("strips/{stripId}", async (event) => {
    const stripData = event.data.data();
    if (!stripData) return;

    const senderId = stripData.senderId;
    const receiverIds = stripData.receiverIds || [];

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderName = senderDoc.exists ? (senderDoc.data().displayName || senderDoc.data().username || "Someone") : "Someone";

    const tokens = [];
    for (const rid of receiverIds) {
        if (rid === senderId) continue;
        const userDoc = await admin.firestore().collection("users").doc(rid).get();
        if (userDoc.exists && userDoc.data().fcmToken) {
            tokens.push(userDoc.data().fcmToken);
        }
    }

    if (tokens.length > 0) {
        console.log(`Sending notification to ${tokens.length} tokens for sender ${senderName}`);
        try {
            await admin.messaging().sendEachForMulticast({
                tokens: tokens,
                notification: {
                    title: "New Photo!",
                    body: `${senderName} sent you a new Strip.`,
                },
                apns: {
                    headers: {
                        "apns-priority": "10",
                        "apns-push-type": "alert"
                    },
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                            "content-available": 1,
                            "mutable-content": 1
                        },
                    },
                },
                data: {
                    type: "new_strip",
                    stripId: event.params.stripId,
                    imageUrl: stripData.imageUrl,
                    latitude: String(stripData.latitude || ""),
                    longitude: String(stripData.longitude || ""),
                    cityName: stripData.cityName || ""
                }
            });
            console.log("Multicast sent successfully");
        } catch (error) {
            console.error("Error sending multicast:", error);
        }
    } else {
        console.log("No recipient tokens found for this strip.");
    }
});

// 2. Send push notification for Direct Messages
exports.onNewDirectMessage = onDocumentCreated("direct_messages/{threadId}/messages/{messageId}", async (event) => {
    const msgData = event.data.data();
    if (!msgData) return;

    const senderId = msgData.senderId;
    const threadId = event.params.threadId;

    const ids = threadId.split("_");
    const receiverId = ids.find(id => id !== senderId);
    if (!receiverId) return;

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderName = senderDoc.exists ? (senderDoc.data().displayName || senderDoc.data().username || "Someone") : "Someone";

    const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
    if (!receiverDoc.exists || !receiverDoc.data().fcmToken) return;

    console.log(`Sending DM notification from ${senderName} to ${receiverId}`);
    try {
        await admin.messaging().send({
            token: receiverDoc.data().fcmToken,
            notification: {
                title: senderName,
                body: msgData.text || "Sent an attachment"
            },
            apns: {
                headers: {
                    "apns-priority": "10",
                    "apns-push-type": "alert"
                },
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        "content-available": 1,
                        "mutable-content": 1,
                        "thread-id": threadId
                    },
                },
            },
            data: {
                type: "direct_message",
                threadId: threadId
            }
        });
        console.log("DM sent successfully");
    } catch (error) {
        console.error("Error sending DM:", error);
    }
});

// 3. Send push notification for comments on a photo
exports.onNewComment = onDocumentCreated("strips/{stripId}/comments/{commentId}", async (event) => {
    const commentData = event.data.data();
    if (!commentData) return;

    const senderId = commentData.senderId;
    const stripId = event.params.stripId;

    const stripDoc = await admin.firestore().collection("strips").doc(stripId).get();
    if (!stripDoc.exists) return;

    const stripData = stripDoc.data();
    const usersToNotify = new Set(stripData.receiverIds || []);
    if (stripData.senderId) usersToNotify.add(stripData.senderId);
    usersToNotify.delete(senderId); // Don't notify the person commenting

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderName = senderDoc.exists ? (senderDoc.data().displayName || senderDoc.data().username || "Someone") : "Someone";

    const tokens = [];
    for (const uid of usersToNotify) {
        const uDoc = await admin.firestore().collection("users").doc(uid).get();
        if (uDoc.exists && uDoc.data().fcmToken) {
            tokens.push(uDoc.data().fcmToken);
        }
    }

    if (tokens.length > 0) {
        console.log(`Sending comment notification to ${tokens.length} tokens`);
        try {
            await admin.messaging().sendEachForMulticast({
                tokens: tokens,
                notification: {
                    title: "New Comment",
                    body: `${senderName}: ${commentData.text || "reacted"}`,
                },
                apns: {
                    headers: {
                        "apns-priority": "10",
                        "apns-push-type": "alert"
                    },
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                            "content-available": 1,
                            "mutable-content": 1
                        },
                    },
                },
                data: {
                    type: "new_comment",
                    stripId: stripId
                }
            });
            console.log("Comment multicast sent successfully");
        } catch (error) {
            console.error("Error sending comment multicast:", error);
        }
    } else {
        console.log("No recipient tokens found for comment.");
    }
});

// 4. Send push notification for Friend Requests
exports.onNewFriendRequest = onDocumentCreated("users/{userId}/friendships/{friendId}", async (event) => {
    const friendData = event.data.data();
    if (!friendData) return;

    const userId = event.params.userId; // The person whose collection this is
    const requesterId = friendData.requesterId;

    // Only notify if the person receiving the document is NOT the one who sent the request
    if (userId === requesterId) {
        console.log("Friend request document created by the sender, skipping notification.");
        return;
    }

    if (!friendData.isPending) {
        console.log("Friendship not pending, skipping notification.");
        return;
    }

    const requesterDoc = await admin.firestore().collection("users").doc(requesterId).get();
    const requesterName = requesterDoc.exists ? (requesterDoc.data().displayName || requesterDoc.data().username || "Someone") : "Someone";

    const receiverDoc = await admin.firestore().collection("users").doc(userId).get();
    if (!receiverDoc.exists || !receiverDoc.data().fcmToken) {
        console.log(`No token found for receiver ${userId}`);
        return;
    }

    console.log(`Sending Friend Request notification from ${requesterName} to ${userId}`);
    try {
        await admin.messaging().send({
            token: receiverDoc.data().fcmToken,
            notification: {
                title: "New Friend Request",
                body: `${requesterName} wants to be your friend!`
            },
            apns: {
                headers: {
                    "apns-priority": "10",
                    "apns-push-type": "alert"
                },
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        "content-available": 1,
                        "mutable-content": 1
                    },
                },
            },
            data: {
                type: "friend_request",
                requesterId: requesterId
            }
        });
        console.log("Friend request notification sent successfully");
    } catch (error) {
        console.error("Error sending friend request notification:", error);
    }
});
EOF

echo "📥 Installing dependencies..."
npm install

echo "🔥 Deploying Cloud Function to stripmate-app..."
cd ..
firebase deploy --only functions --force --project stripmate-app

echo "✅ Cloud Functions deployed successfully!"
