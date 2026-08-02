package com.sharedcore.sharedcore_flutter

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.TimeZone

/** Collects Android-owned device information for the Rust SharedCore client. */
class SharedcoreFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var applicationContext: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "collectDeviceInfo" -> result.success(
                    collectDeviceInfo(call.argument<String>("appId").orEmpty()),
                )
                "loadSession" -> result.success(loadSession(sessionPrefix(call)))
                "saveSession" -> {
                    saveSession(call, sessionPrefix(call))
                    result.success(null)
                }
                "clearSession" -> {
                    clearSession(sessionPrefix(call))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            val code = if (call.method == "collectDeviceInfo") {
                "device_info_unavailable"
            } else {
                "session_storage_unavailable"
            }
            result.error(code, error.message, null)
        }
    }

    private fun sessionPrefix(call: MethodCall): String =
        call.argument<String>("prefix") ?: DEFAULT_SESSION_PREFIX

    private fun loadSession(prefix: String): Map<String, String>? {
        val preferences = sessionPreferences()
        val accessToken = preferences.getString(prefix + "AccessToken", "").orEmpty()
        if (accessToken.isEmpty()) return null
        return mapOf(
            "accessToken" to accessToken,
            "userId" to preferences.getString(prefix + "UserId", "").orEmpty(),
            "email" to preferences.getString(prefix + "Email", "").orEmpty(),
        )
    }

    private fun saveSession(call: MethodCall, prefix: String) {
        val accessToken = call.argument<String>("accessToken").orEmpty()
        if (accessToken.isEmpty()) {
            clearSession(prefix)
            return
        }
        check(
            sessionPreferences().edit()
                .putString(prefix + "AccessToken", accessToken)
                .putString(prefix + "UserId", call.argument<String>("userId").orEmpty())
                .putString(prefix + "Email", call.argument<String>("email").orEmpty())
                .commit(),
        ) { "Unable to persist SharedCore session" }
    }

    private fun clearSession(prefix: String) {
        check(
            sessionPreferences().edit()
                .remove(prefix + "AccessToken")
                .remove(prefix + "UserId")
                .remove(prefix + "Email")
                .commit(),
        ) { "Unable to clear SharedCore session" }
    }

    private fun sessionPreferences() = applicationContext.getSharedPreferences(
        SESSION_PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    private fun collectDeviceInfo(appId: String): Map<String, Any> {
        val locale = Locale.getDefault()
        val language = locale.language
        val telephonyManager =
            applicationContext.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

        return mapOf(
            "appId" to appId,
            "bundleId" to applicationContext.packageName,
            "udid" to Settings.Secure.getString(
                applicationContext.contentResolver,
                Settings.Secure.ANDROID_ID,
            ).orEmpty(),
            "appVersion" to appVersion(),
            "platform" to "android",
            "deviceName" to listOf(Build.MANUFACTURER, Build.MODEL)
                .filter { it.isNotBlank() }
                .joinToString(" "),
            "systemName" to "Android",
            "osVersion" to Build.VERSION.RELEASE.orEmpty(),
            "language" to language,
            "templateLanguage" to language,
            "timezone" to TimeZone.getDefault().id,
            "inputLanguage" to inputLanguage(),
            "vpn" to isVpnActive(),
            "hasWxOrQq" to (isPackageInstalled(WECHAT_PACKAGE) ||
                isPackageInstalled(QQ_PACKAGE)),
            "networkOperator" to runCatching {
                telephonyManager?.networkOperatorName.orEmpty()
            }.getOrDefault(""),
            "simOperator" to runCatching {
                telephonyManager?.simOperatorName.orEmpty()
            }.getOrDefault(""),
            "installReferrer" to "",
        )
    }

    @Suppress("DEPRECATION")
    private fun appVersion(): String = runCatching {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            applicationContext.packageManager.getPackageInfo(
                applicationContext.packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            applicationContext.packageManager.getPackageInfo(applicationContext.packageName, 0)
        }
        packageInfo.versionName.orEmpty()
    }.getOrDefault("")

    private fun inputLanguage(): String = runCatching {
        val context = activity ?: applicationContext
        val manager = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        val languageTag = manager.currentInputMethodSubtype?.languageTag
        if (!languageTag.isNullOrEmpty()) {
            languageTag
        } else {
            Locale.getDefault().country.ifEmpty { Locale.getDefault().language }
        }
    }.getOrDefault("")

    private fun isVpnActive(): Boolean = runCatching {
        val manager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager
        manager.allNetworks.any { network ->
            manager.getNetworkCapabilities(network)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        }
    }.getOrDefault(false)

    @Suppress("DEPRECATION")
    private fun isPackageInstalled(packageName: String): Boolean = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            applicationContext.packageManager.getApplicationInfo(
                packageName,
                PackageManager.ApplicationInfoFlags.of(0),
            )
        } else {
            applicationContext.packageManager.getApplicationInfo(packageName, 0)
        }
        true
    }.getOrDefault(false)

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

    private companion object {
        const val CHANNEL_NAME = "sharedcore_flutter/device_info"
        const val SESSION_PREFERENCES_NAME = "sharedcore_flutter.session"
        const val DEFAULT_SESSION_PREFIX = "SharedCore"
        const val WECHAT_PACKAGE = "com.tencent.mm"
        const val QQ_PACKAGE = "com.tencent.mobileqq"
    }
}
