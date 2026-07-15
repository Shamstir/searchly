package com.example.flutter_media_controller

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class MediaNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.notification?.extras != null) {
            val extras = sbn.notification.extras
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
            val artist = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty()

            if (title.isNotEmpty() && isMediaLikeNotification(sbn)) {
                latestTrack = title
                latestArtist = artist.ifEmpty { "Unknown artist" }
                latestPackageName = sbn.packageName
                latestUpdatedAt = System.currentTimeMillis()
            }

            Log.d("MediaNotification", "Title: $title, Artist: $artist")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (sbn.packageName == latestPackageName) {
            latestTrack = null
            latestArtist = null
            latestPackageName = null
            latestUpdatedAt = 0L
        }
        Log.d("MediaNotification", "Notification Removed: ${sbn.packageName}")
    }

    private fun isMediaLikeNotification(sbn: StatusBarNotification): Boolean {
        val notification = sbn.notification ?: return false
        return notification.category == Notification.CATEGORY_TRANSPORT ||
                notification.extras.containsKey("android.mediaSession")
    }

    companion object {
        private var latestTrack: String? = null
        private var latestArtist: String? = null
        private var latestPackageName: String? = null
        private var latestUpdatedAt: Long = 0L

        fun latestMediaInfo(): Map<String, Any>? {
            val track = latestTrack ?: return null
            if (System.currentTimeMillis() - latestUpdatedAt > 30_000L) return null

            return mapOf(
                "track" to track,
                "artist" to (latestArtist ?: "Unknown artist"),
                "thumbnailUrl" to "",
                "isPlaying" to true
            )
        }
    }
}
