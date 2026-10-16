package com.example.flutter_media_controller

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

import android.content.Context
import android.content.SharedPreferences

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

                // Sync with media_widget_prefs for the native AppWidgetProvider
                try {
                    val prefs = getSharedPreferences("media_widget_prefs", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("track", latestTrack)
                        .putString("artist", latestArtist)
                        .putBoolean("isPlaying", true)
                        .apply()
                } catch (e: Exception) {
                    Log.e("MediaNotification", "Failed to write widget prefs: ${e.message}")
                }
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

            try {
                val prefs = getSharedPreferences("media_widget_prefs", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("track", "No track playing")
                    .putString("artist", "Unknown artist")
                    .putBoolean("isPlaying", false)
                    .apply()
            } catch (e: Exception) {
                Log.e("MediaNotification", "Failed to clear widget prefs: ${e.message}")
            }
        }
        Log.d("MediaNotification", "Notification Removed: ${sbn.packageName}")
    }

    private fun isMediaLikeNotification(sbn: StatusBarNotification): Boolean {
        val notification = sbn.notification ?: return false
        return notification.category == Notification.CATEGORY_TRANSPORT ||
                notification.extras.containsKey("android.mediaSession")
    }

    companion object {
        @Volatile
        private var latestTrack: String? = null
        @Volatile
        private var latestArtist: String? = null
        @Volatile
        private var latestPackageName: String? = null
        @Volatile
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
