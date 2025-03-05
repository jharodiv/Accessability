package com.example.frontend

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

@SuppressLint("MissingFirebaseInstanceTokenRefresh")
class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        remoteMessage.notification?.let { notification ->
            sendNotification(notification.title, notification.body)
        }
    }

    private fun sendNotification(title: String?, messageBody: String?) {
        val channelId = "high"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "High Importance Notifications",
                NotificationManager.IMPORTANCE_LOW
            )
            notificationManager.createNotificationChannel(channel)
        }

        // Create a separate channel for space chat notifications
         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val spaceChatChannel = NotificationChannel(
                "space_chat", // Channel ID for space chat notifications
                "Space Chat Notifications",
                 NotificationManager.IMPORTANCE_HIGH // Set importance to HIGH
            )
                notificationManager.createNotificationChannel(spaceChatChannel)
        }

        val notificationBuilder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(messageBody)
            .setSmallIcon(R.mipmap.ic_launcher) // Use your app's launcher icon
            .setAutoCancel(true)

        notificationManager.notify(0, notificationBuilder.build())
    }
}