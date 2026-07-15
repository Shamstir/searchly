package com.example.flutter_media_controller

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.util.Base64
import android.graphics.Bitmap
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class FlutterMediaControllerPlugin: FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

  private var activity: Activity? = null
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private val PERMISSION_REQUEST_CODE = 1001

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_media_controller")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "requestPermissions" -> {
        try {
          requestPermissions()
          result.success(true)
        } catch (e: Exception) {
          result.error("MEDIA_ERROR", "Failed to request permissions", e.message)
        }
      }
      "getMediaInfo" -> {
        try {
          val mediaInfo = getCurrentMediaInfo()
          result.success(mediaInfo)
        } catch (e: Exception) {
          result.error("MEDIA_ERROR", "Failed to get media info", e.message)
        }
      }
      "mediaAction" -> {
        val action = call.argument<String>("action")
        if (action != null) {
          handleMediaAction(action)
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENT", "Action cannot be null", null)
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun isNotificationListenerEnabled(): Boolean {
    val enabledListeners = android.provider.Settings.Secure.getString(
      context.contentResolver, "enabled_notification_listeners"
    )
    val packageName = context.packageName
    return enabledListeners != null && enabledListeners.contains(packageName)
  }

  private fun getCurrentMediaInfo(): Map<String, Any> {
    // Check permission BEFORE calling getActiveSessions to avoid SecurityException spam
    if (!isNotificationListenerEnabled()) {
      return mapOf(
        "track" to "Error: Notification access not granted",
        "artist" to "Tap to grant permission",
        "thumbnailUrl" to "",
        "isPlaying" to false
      )
    }

    val mediaSessionManager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    val componentName = ComponentName(context, MediaNotificationListener::class.java)

    try {
      val controllers = mediaSessionManager.getActiveSessions(componentName)
      if (controllers.isNotEmpty()) {
        val controller = selectBestController(controllers)
        if (controller != null) {
          return mediaInfoFromController(controller)
        }
      }
    } catch (e: SecurityException) {
      // Should not happen now with the pre-check, but handle gracefully just in case
      return mapOf(
        "track" to "Error: Missing media permission",
        "artist" to "Tap to grant permission",
        "thumbnailUrl" to "",
        "isPlaying" to false
      )
    }

    MediaNotificationListener.latestMediaInfo()?.let { return it }

    return mapOf(
            "track" to "No track playing",
            "artist" to "Unknown artist",
            "thumbnailUrl" to "",
            "isPlaying" to false
    )
  }

  private fun selectBestController(controllers: List<MediaController>): MediaController? {
    return controllers
      .map { it to controllerScore(it) }
      .filter { it.second > 0 }
      .maxByOrNull { it.second }
      ?.first
  }

  private fun controllerScore(controller: MediaController): Int {
    val metadata = controller.metadata
    val playbackState = controller.playbackState
    val state = playbackState?.state
    val title = mediaTitle(metadata)
    val artist = mediaArtist(metadata)
    var score = 0

    if (state == PlaybackState.STATE_PLAYING) score += 100
    if (state == PlaybackState.STATE_BUFFERING || state == PlaybackState.STATE_CONNECTING) score += 60
    if (!title.isNullOrBlank()) score += 30
    if (!artist.isNullOrBlank()) score += 10
    if (metadata != null) score += 5

    return score
  }

  private fun mediaInfoFromController(controller: MediaController): Map<String, Any> {
    val metadata = controller.metadata
    val playbackState = controller.playbackState
    val title = mediaTitle(metadata) ?: "Unknown Track"
    val artist = mediaArtist(metadata) ?: "Unknown Artist"
    val thumbnailBase64 = mediaArtworkBase64(metadata)

    return mapOf(
      "track" to title,
      "artist" to artist,
      "thumbnailUrl" to thumbnailBase64,
      "isPlaying" to (playbackState?.state == PlaybackState.STATE_PLAYING)
    )
  }

  private fun mediaTitle(metadata: MediaMetadata?): String? {
    return firstNonBlank(
      metadata?.getString(MediaMetadata.METADATA_KEY_TITLE),
      metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
    )
  }

  private fun mediaArtist(metadata: MediaMetadata?): String? {
    return firstNonBlank(
      metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST),
      metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST),
      metadata?.getString(MediaMetadata.METADATA_KEY_AUTHOR),
      metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE)
    )
  }

  private fun mediaArtworkBase64(metadata: MediaMetadata?): String {
    val artwork = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
      ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
      ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)
      ?: return ""

    val scaledArtwork = scaleBitmapForWidget(artwork)
    val byteArrayOutputStream = ByteArrayOutputStream()
    scaledArtwork.compress(Bitmap.CompressFormat.JPEG, 82, byteArrayOutputStream)
    return Base64.encodeToString(byteArrayOutputStream.toByteArray(), Base64.NO_WRAP)
  }

  private fun scaleBitmapForWidget(bitmap: Bitmap): Bitmap {
    val maxSize = 256
    val largestSide = maxOf(bitmap.width, bitmap.height)
    if (largestSide <= maxSize) return bitmap

    val scale = maxSize.toFloat() / largestSide.toFloat()
    val width = (bitmap.width * scale).toInt().coerceAtLeast(1)
    val height = (bitmap.height * scale).toInt().coerceAtLeast(1)
    return Bitmap.createScaledBitmap(bitmap, width, height, true)
  }

  private fun firstNonBlank(vararg values: String?): String? {
    return values.firstOrNull { !it.isNullOrBlank() }?.trim()
  }

  private fun handleMediaAction(action: String) {
    // Check permission before attempting media actions
    if (!isNotificationListenerEnabled()) return

    val mediaSessionManager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    val componentName = ComponentName(context, MediaNotificationListener::class.java)

    try {
      val controllers = mediaSessionManager.getActiveSessions(componentName)
      if (controllers.isNotEmpty()) {
        val mediaController = selectBestController(controllers) ?: controllers[0]
        when (action) {
          "previous" -> mediaController.transportControls.skipToPrevious()
          "playPause" -> {
            if (mediaController.playbackState?.state == PlaybackState.STATE_PLAYING) {
              mediaController.transportControls.pause()
            } else {
              mediaController.transportControls.play()
            }
          }
          "next" -> mediaController.transportControls.skipToNext()
        }
      }
    } catch (e: SecurityException) {
      // Permission was revoked between check and use; silently ignore
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  fun requestPermissions() {
    activity?.let { act ->
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        if (ContextCompat.checkSelfPermission(act, android.Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
          ActivityCompat.requestPermissions(
                  act,
                  arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                  PERMISSION_REQUEST_CODE
          )
        }
      }
      
      val enabledListeners = android.provider.Settings.Secure.getString(act.contentResolver, "enabled_notification_listeners")
      val packageName = act.packageName
      val isGranted = enabledListeners != null && enabledListeners.contains(packageName)
      
      if (!isGranted) {
          act.startActivity(Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
      }
    } ?: run {
      println("Activity is null, cannot request permissions")
    }
  }

  companion object {
    private const val PERMISSION_REQUEST_CODE = 1001
  }

}
