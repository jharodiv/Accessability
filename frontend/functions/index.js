const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendMessageNotification = functions.firestore
  .document('chat_rooms/{chatRoomID}/messages/{messageID}')
  .onCreate(async (snapshot, context) => {
    try {
      // Extract message data
      const messageData = snapshot.data();
      const senderID = messageData.senderID;
      const receiverID = messageData.receiverID;
      const message = messageData.message;

      // Fetch sender's details (e.g., username or email)
      const senderDoc = await admin.firestore().collection('Users').doc(senderID).get();
      const senderName = senderDoc.data()?.username || senderDoc.data()?.email || 'Someone';
      const senderEmail = senderDoc.data()?.email;
      if (!senderEmail) {
        console.log('Sender email not found');
        return;
      }



      // Fetch receiver's FCM token
      const receiverDoc = await admin.firestore().collection('Users').doc(receiverID).get();
      const receiverName = receiverDoc.data()?.username || receiverDoc.data()?.email || 'Someone';
      const receiverToken = receiverDoc.data()?.fcmToken;

      if (!receiverToken) {
        console.log('Receiver FCM token not found');
        return;
      }

      // Prepare the notification payload
      const payload = {
        notification: {
          title: `${receiverName}`,
          body: `${message}`,
        },
        data: {
          senderID: senderID,
          senderEmail: senderEmail, // Add senderEmail to the data payload
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

      // Send the notification
      const response = await admin.messaging().send(payload);
      console.log('Notification sent successfully:', response);
    } catch (error) {
      console.error('Error sending notification:', error);
    }
  });