package com.sharedcore.sharedcore_flutter

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.telephony.TelephonyManager
import android.util.Base64
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.TimeZone
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

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
        val encryptedToken = preferences.getString(encryptedTokenKey(prefix), "").orEmpty()
        val encodedIv = preferences.getString(tokenIvKey(prefix), "").orEmpty()
        if (encryptedToken.isNotEmpty() != encodedIv.isNotEmpty()) {
            clearSession(prefix)
            return null
        }
        var accessToken = ""
        if (encryptedToken.isNotEmpty() && encodedIv.isNotEmpty()) {
            val key = existingSessionKey(prefix)
            if (key == null) {
                clearStoredValues(prefix)
                return null
            }
            accessToken = runCatching { decrypt(encryptedToken, encodedIv, key) }
                .getOrElse {
                    clearSession(prefix)
                    return null
                }
        } else {
            val legacyToken = preferences.getString(prefix + "AccessToken", "").orEmpty()
            if (legacyToken.isNotEmpty()) {
                saveEncryptedToken(prefix, legacyToken)
                check(preferences.edit().remove(prefix + "AccessToken").commit()) {
                    "Unable to remove the legacy SharedCore credential"
                }
                accessToken = legacyToken
            }
        }
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
        saveEncryptedToken(prefix, accessToken)
        check(
            sessionPreferences().edit()
                .putString(prefix + "UserId", call.argument<String>("userId").orEmpty())
                .putString(prefix + "Email", call.argument<String>("email").orEmpty())
                .remove(prefix + "AccessToken")
                .commit(),
        ) { "Unable to persist SharedCore session" }
    }

    private fun clearSession(prefix: String) {
        clearStoredValues(prefix)
        val keyStore = androidKeyStore()
        if (keyStore.containsAlias(sessionKeyAlias(prefix))) {
            keyStore.deleteEntry(sessionKeyAlias(prefix))
        }
    }

    private fun clearStoredValues(prefix: String) {
        check(
            sessionPreferences().edit()
                .remove(prefix + "AccessToken")
                .remove(encryptedTokenKey(prefix))
                .remove(tokenIvKey(prefix))
                .remove(prefix + "UserId")
                .remove(prefix + "Email")
                .commit(),
        ) { "Unable to clear SharedCore session" }
    }

    private fun saveEncryptedToken(prefix: String, accessToken: String) {
        val cipher = Cipher.getInstance(SESSION_CIPHER)
        cipher.init(Cipher.ENCRYPT_MODE, sessionKey(prefix))
        val encrypted = cipher.doFinal(accessToken.toByteArray(Charsets.UTF_8))
        check(
            sessionPreferences().edit()
                .putString(
                    encryptedTokenKey(prefix),
                    Base64.encodeToString(encrypted, Base64.NO_WRAP),
                )
                .putString(
                    tokenIvKey(prefix),
                    Base64.encodeToString(cipher.iv, Base64.NO_WRAP),
                )
                .commit(),
        ) { "Unable to persist encrypted SharedCore credential" }
    }

    private fun decrypt(encodedToken: String, encodedIv: String, key: SecretKey): String {
        val cipher = Cipher.getInstance(SESSION_CIPHER)
        cipher.init(
            Cipher.DECRYPT_MODE,
            key,
            GCMParameterSpec(SESSION_GCM_TAG_BITS, Base64.decode(encodedIv, Base64.NO_WRAP)),
        )
        return cipher.doFinal(Base64.decode(encodedToken, Base64.NO_WRAP))
            .toString(Charsets.UTF_8)
    }

    private fun sessionKey(prefix: String): SecretKey = existingSessionKey(prefix)
        ?: KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE).run {
            init(
                KeyGenParameterSpec.Builder(
                    sessionKeyAlias(prefix),
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(true)
                    .build(),
            )
            generateKey()
        }

    private fun existingSessionKey(prefix: String): SecretKey? =
        androidKeyStore().getKey(sessionKeyAlias(prefix), null) as? SecretKey

    private fun androidKeyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply {
        load(null)
    }

    private fun sessionKeyAlias(prefix: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(prefix.toByteArray(Charsets.UTF_8))
            .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
        return "$SESSION_KEY_ALIAS_PREFIX${digest.take(24)}"
    }

    private fun encryptedTokenKey(prefix: String) = prefix + "EncryptedAccessToken"

    private fun tokenIvKey(prefix: String) = prefix + "AccessTokenIv"

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
                telephonyManager?.networkOperator.orEmpty()
            }.getOrDefault(""),
            "simOperator" to runCatching {
                telephonyManager?.simOperator.orEmpty()
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
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val SESSION_CIPHER = "AES/GCM/NoPadding"
        const val SESSION_GCM_TAG_BITS = 128
        const val SESSION_KEY_ALIAS_PREFIX = "sharedcore_flutter.session."
        const val DEFAULT_SESSION_PREFIX = "SharedCore"
        const val WECHAT_PACKAGE = "com.tencent.mm"
        const val QQ_PACKAGE = "com.tencent.mobileqq"
    }
}
