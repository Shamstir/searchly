package io.searchly.launcher

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.content.BroadcastReceiver
import android.content.IntentFilter

class MainActivity: FlutterActivity() {
    private val CHANNEL = "searchly/launcher"
    private val EVENT_CHANNEL = "searchly/package_changes"
    private var pendingLauncherResult: MethodChannel.Result? = null
    private var packageReceiver: BroadcastReceiver? = null

    override fun getRenderMode(): RenderMode {
        return RenderMode.surface
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestDefaultLauncher") {
                pendingLauncherResult = result
                requestDefaultLauncher()
            } else if (call.method == "isDefaultLauncher") {
                val isDefault = isDefaultLauncher()
                result.success(isDefault)
            } else if (call.method == "launchAppExplicitly") {
                val pkg = call.argument<String>("package_name")
                if (pkg != null) {
                    val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(launchIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                } else {
                    result.success(false)
                }
            } else if (call.method == "getAppCategories") {
                val categories = mutableMapOf<String, String>()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val packages = packageManager.getInstalledApplications(0)
                    for (appInfo in packages) {
                        val cat = when (appInfo.category) {
                            android.content.pm.ApplicationInfo.CATEGORY_GAME -> "Games"
                            android.content.pm.ApplicationInfo.CATEGORY_AUDIO,
                            android.content.pm.ApplicationInfo.CATEGORY_VIDEO,
                            android.content.pm.ApplicationInfo.CATEGORY_IMAGE -> "Media"
                            android.content.pm.ApplicationInfo.CATEGORY_SOCIAL -> "Social"
                            android.content.pm.ApplicationInfo.CATEGORY_PRODUCTIVITY,
                            android.content.pm.ApplicationInfo.CATEGORY_NEWS -> "Work"
                            android.content.pm.ApplicationInfo.CATEGORY_MAPS,
                            android.content.pm.ApplicationInfo.CATEGORY_ACCESSIBILITY -> "Tools"
                            else -> null
                        }
                        if (cat != null) {
                            categories[appInfo.packageName] = cat
                        }
                    }
                }
                result.success(categories)
            } else {
                result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            val action = intent?.action
                            val packageName = intent?.data?.schemeSpecificPart
                            if (action != null && packageName != null) {
                                events?.success(mapOf("action" to action, "package" to packageName))
                            }
                        }
                    }
                    packageReceiver = receiver
                    val filter = IntentFilter().apply {
                        addAction(Intent.ACTION_PACKAGE_ADDED)
                        addAction(Intent.ACTION_PACKAGE_REMOVED)
                        addAction(Intent.ACTION_PACKAGE_REPLACED)
                        addDataScheme("package")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                    } else {
                        registerReceiver(receiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    packageReceiver?.let {
                        try {
                            unregisterReceiver(it)
                        } catch (_: Exception) {}
                        packageReceiver = null
                    }
                }
            }
        )
    }

    private fun isDefaultLauncher(): Boolean {
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        val resolveInfo = packageManager.resolveActivity(intent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY)
        return resolveInfo?.activityInfo?.packageName == packageName
    }

    private fun requestDefaultLauncher() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (roleManager.isRoleAvailable(RoleManager.ROLE_HOME) && !roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
                startActivityForResult(intent, 1001)
                return
            }
        }
        
        // Fallback for older Android versions
        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
        startActivity(intent)
        pendingLauncherResult?.success(null)
        pendingLauncherResult = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001) {
            pendingLauncherResult?.success(null)
            pendingLauncherResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).invokeMethod("onHomePressed", null)
        }
    }
}
