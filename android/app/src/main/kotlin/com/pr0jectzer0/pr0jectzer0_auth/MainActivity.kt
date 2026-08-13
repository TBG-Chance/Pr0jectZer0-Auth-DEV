package com.pr0jectzer0.pr0jectzer0_auth

import android.app.KeyguardManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "pr0jectzer0/device_security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSecurityState" -> result.success(readSecurityState())
                    else -> result.notImplemented()
                }
            }
    }

    private fun readSecurityState(): Map<String, Any?> {
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val developerMode = Settings.Global.getInt(
            contentResolver,
            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
            0
        ) == 1

        val hardwareBacked = packageManager.hasSystemFeature(PackageManager.FEATURE_SECURE_LOCK_SCREEN) ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE))

        return mapOf(
            "screenLockEnabled" to keyguard.isDeviceSecure,
            "developerMode" to developerMode,
            "hardwareBacked" to hardwareBacked,
            "compromised" to hasRootIndicators()
        )
    }

    private fun hasRootIndicators(): Boolean {
        val suspiciousPaths = listOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/sbin/su",
            "/su/bin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su"
        )
        return Build.TAGS?.contains("test-keys") == true ||
            suspiciousPaths.any { File(it).exists() }
    }
}
