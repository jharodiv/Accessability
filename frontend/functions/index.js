const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Function for private chat notifications
exports.sendMessageNotification = functions.firestore
  .document("chat_rooms/{chatRoomID}/messages/{messageID}")
  .onCreate(async (snap, context) => {
    try {
      const messageData = snap.data();
      const senderID = messageData.senderID;
      const receiverID = messageData.receiverID;
      const message = messageData.message;

      // Get sender info
      const senderDoc = await admin
        .firestore()
        .collection("Users")
        .doc(senderID)
        .get();
      const senderData = senderDoc.data();
      if (!senderData) return;

      const senderName = senderData.username || senderData.email || "Someone";
      const senderEmail = senderData.email;
      if (!senderEmail) return;

      // Get receiver info and FCM token
      const receiverDoc = await admin
        .firestore()
        .collection("Users")
        .doc(receiverID)
        .get();
      const receiverData = receiverDoc.data();
      if (!receiverData) return;

      const receiverToken = receiverData.fcmToken;
      if (!receiverToken) return;

      // Prepare notification payload
      const payload = {
        notification: {
          title: `${senderName}`,
          body: `${message}`,
        },
        data: {
          senderID: senderID,
          senderEmail: senderEmail,
          receiverID: receiverID,
          message: message,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            sound: "default",
            priority: "high",
            visibility: "public",
            channel_id: "higher",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        token: receiverToken,
      };

      // Send notification
      await admin.messaging().send(payload);
      console.log("Private chat notification sent successfully");
    } catch (error) {
      console.error("Error sending private chat notification:", error);
    }
  });

// Function for space chat room notifications
exports.sendSpaceChatNotification = functions.firestore
  .document("space_chat_rooms/{spaceId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    try {
      const messageData = snap.data();
      const senderID = messageData.senderID;
      const spaceId = context.params.spaceId;
      const message = messageData.message;

      // Get sender info
      const senderDoc = await admin
        .firestore()
        .collection("Users")
        .doc(senderID)
        .get();
      const senderData = senderDoc.data();
      if (!senderData) return;

      const senderName = senderData.username || senderData.email || "Someone";
      const senderEmail = senderData.email;
      if (!senderEmail) return;

      // Get space info
      const spaceDoc = await admin
        .firestore()
        .collection("space_chat_rooms")
        .doc(spaceId)
        .get();
      const spaceData = spaceDoc.data();
      if (!spaceData) return;

      const spaceName = spaceData.name || "Space";
      const members = spaceData.members || [];

      // Get FCM tokens for all members except sender
      const tokens = [];
      for (const memberId of members) {
        if (memberId !== senderID) {
          const memberDoc = await admin
            .firestore()
            .collection("Users")
            .doc(memberId)
            .get();
          const memberData = memberDoc.data();
          if (memberData && memberData.fcmToken) {
            tokens.push(memberData.fcmToken);
          }
        }
      }

      if (tokens.length === 0) return;

      // Prepare the base payload (without token)
      const basePayload = {
        notification: {
          title: `${senderName} in ${spaceName}`,
          body: `${message}`,
        },
        data: {
          senderID: senderID,
          senderEmail: senderEmail,
          spaceId: spaceId,
          message: message,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            sound: "default",
            priority: "high",
            visibility: "public",
            channel_id: "space_chat",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      // Send to each token
      for (const token of tokens) {
        try {
          const individualPayload = { ...basePayload, token };
          await admin.messaging().send(individualPayload);
          console.log("Space chat notification sent to:", token);
        } catch (error) {
          console.error("Error sending to token:", token, error);

          // Remove invalid tokens from the database
          if (
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered"
          ) {
            console.log("Removing invalid token from the database:", token);
            // Add logic to remove invalid tokens from Firestore if needed
          }
        }
      }
    } catch (error) {
      console.error("Error in space chat notification:", error);
    }
  });

// Function for distance movement notifications
exports.sendDistanceNotification = functions.firestore
  .document("DistanceNotifications/{notificationId}")
  .onCreate(async (snap, context) => {
    try {
      const notificationData = snap.data();
      const targetFCMToken = notificationData.targetFCMToken;
      const movingUserName = notificationData.movingUserName;
      const spaceName = notificationData.spaceName;
      const distanceKm = notificationData.distanceKm;
      const address = notificationData.address;
      const movingUserId = notificationData.movingUserId;
      const spaceId = notificationData.spaceId;

      if (!targetFCMToken) {
        await snap.ref.delete();
        return;
      }

      const payload = {
        notification: {
          title: `🚀 ${movingUserName} Moved ${distanceKm.toFixed(1)} km!`,
          body: `In ${spaceName} space`,
        },
        data: {
          type: "distance_alert",
          movingUserId: movingUserId,
          movingUserName: movingUserName,
          spaceId: spaceId,
          spaceName: spaceName,
          distanceKm: distanceKm.toString(),
          address: address,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            sound: "default",
            priority: "high",
            visibility: "public",
            channel_id: "distance_alerts",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        token: targetFCMToken,
      };

      await admin.messaging().send(payload);
      console.log("Distance notification sent successfully");

      // Clean up
      await snap.ref.delete();
    } catch (error) {
      console.error("Error sending distance notification:", error);
      await snap.ref.delete();
    }
  });

exports.sendNavigationUpdateNotification = functions.firestore
  .document("DistanceNotifications/{notificationId}")
  .onCreate(async (snapshot, context) => {
    try {
      const notificationData = snapshot.data();

      // Only handle navigation updates
      if (notificationData.type !== "navigation_update") return;

      const targetFCMToken = notificationData.targetFCMToken;
      const movingUserName = notificationData.movingUserName;
      const message = notificationData.message;
      const movingUserId = notificationData.movingUserId;

      if (!targetFCMToken) {
        console.log("No FCM token found for target member");
        await snapshot.ref.delete();
        return;
      }

      const payload = {
        notification: {
          title: `📍 ${movingUserName} Navigation Update`,
          body: message,
        },
        data: {
          type: "navigation_update",
          movingUserId: movingUserId,
          movingUserName: movingUserName,
          message: message,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            sound: "default",
            priority: "high",
            visibility: "public",
            channel_id: "navigation_updates",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        token: targetFCMToken,
      };

      console.log("Sending navigation update payload:", payload);

      const response = await admin.messaging().send(payload);
      console.log("Navigation update sent successfully:", response);

      // Clean up
      await snapshot.ref.delete();
    } catch (error) {
      console.error("Error sending navigation update:", error);
      await snapshot.ref.delete();
    }
  });

exports.sendHomeDistanceNotification = functions.firestore
  .document("DistanceNotifications/{notificationId}")
  .onCreate(async (snap, context) => {
    try {
      const notificationData = snap.data();

      // Only handle home distance alerts
      if (notificationData.type !== "home_distance_alert") return;

      const targetFCMToken = notificationData.targetFCMToken;
      const homeOwnerName = notificationData.homeOwnerName;
      const movingUserName = notificationData.movingUserName;
      const distanceKm = notificationData.distanceKm;
      const message = notificationData.message;

      if (!targetFCMToken) {
        await snap.ref.delete();
        return;
      }

      const payload = {
        notification: {
          title: `🏠 ${movingUserName} near ${homeOwnerName}'s Home`,
          body: message,
        },
        data: {
          type: "home_distance_alert",
          homeOwnerName: homeOwnerName,
          movingUserName: movingUserName,
          distanceKm: distanceKm.toString(),
          message: message,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            sound: "default",
            priority: "high",
            visibility: "public",
            channel_id: "home_distance_alerts",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        token: targetFCMToken,
      };

      await admin.messaging().send(payload);
      console.log("Home distance notification sent successfully");

      // Clean up
      await snap.ref.delete();
    } catch (error) {
      console.error("Error sending home distance notification:", error);
      await snap.ref.delete();
    }
  });
