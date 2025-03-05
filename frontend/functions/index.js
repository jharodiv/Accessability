const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Function for private chat notifications
exports.sendMessageNotification = functions.firestore
  .document('chat_rooms/{chatRoomID}/messages/{messageID}')
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.data();
      const senderID = messageData.senderID;
      const receiverID = messageData.receiverID;
      const message = messageData.message;

      const senderDoc = await admin.firestore().collection('Users').doc(senderID).get();
      const senderName = senderDoc.data()?.username || senderDoc.data()?.email || 'Someone';
      const senderEmail = senderDoc.data()?.email;

      if (!senderEmail) {
        console.log('Sender email not found');
        return;
      }

      const receiverDoc = await admin.firestore().collection('Users').doc(receiverID).get();
      const receiverToken = receiverDoc.data()?.fcmToken;

      if (!receiverToken) {
        console.log('Receiver FCM token not found');
        return;
      }

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
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          notification: {
            sound: 'default',
            priority: 'high',
            visibility: 'public',
            channel_id: 'higher',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
        token: receiverToken,
      };

      console.log('Payload:', payload);

      const response = await admin.messaging().send(payload);
      console.log('Notification sent successfully:', response);
    } catch (error) {
      console.error('Error sending notification:', error);
    }
  });

// Function for space chat room notifications
exports.sendSpaceChatNotification = functions.firestore
  .document('space_chat_rooms/{spaceId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.data();
      const senderID = messageData.senderID;
      const spaceId = context.params.spaceId;
      const message = messageData.message;

      // Fetch sender's details
      const senderDoc = await admin.firestore().collection('Users').doc(senderID).get();
      const senderName = senderDoc.data()?.username || senderDoc.data()?.email || 'Someone';
      const senderEmail = senderDoc.data()?.email;

      if (!senderEmail) {
        console.log('Sender email not found');
        return;
      }

      // Fetch space chat room details
      const spaceDoc = await admin.firestore().collection('space_chat_rooms').doc(spaceId).get();
      const spaceName = spaceDoc.data()?.name || 'Space';
      const members = spaceDoc.data()?.members || [];

      // Fetch FCM tokens for all members (except the sender)
      const tokens = [];
      for (const memberId of members) {
        if (memberId !== senderID) {
          const memberDoc = await admin.firestore().collection('Users').doc(memberId).get();
          const memberToken = memberDoc.data()?.fcmToken;

          if (memberToken) {
            tokens.push(memberToken);
          }
        }
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for members');
        return;
      }

      // Prepare the notification payload
      const payload = {
        notification: {
          title: `${senderName} in ${spaceName}`,
          body: `${message}`,
        },
        data: {
          senderID: senderID,
          senderEmail: senderEmail,
          spaceId: spaceId,
          message: message,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          notification: {
            sound: 'default',
            priority: 'high',
            visibility: 'public',
            channel_id: 'space_chat',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      };

      console.log('Payload:', payload);

      // Send notifications one by one
      for (const token of tokens) {
        try {
          const individualPayload = { ...payload, token }; // Add the token to the payload
          const response = await admin.messaging().send(individualPayload);
          console.log('Notification sent successfully to token:', token, response);
        } catch (error) {
          console.error('Error sending notification to token:', token, error);

          // Optionally, remove invalid tokens from the database
          if (error.code === 'messaging/invalid-registration-token' || error.code === 'messaging/registration-token-not-registered') {
            console.log('Removing invalid token from the database:', token);
            // Add logic to remove invalid tokens from Firestore
          }
        }
      }
    } catch (error) {
      console.error('Error in sendSpaceChatNotification:', error);
    }
  });