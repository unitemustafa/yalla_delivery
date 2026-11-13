package com.yallamarket.yalla_home

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var waitingForInstallPermission = false
    private var installing = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yalla_delivery/app_updates")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installedVersion" -> result.success(AppUpdateDownloads.installedVersion(this))
                        "status" -> result.success(AppUpdateDownloads.status(this))
                        "download" -> {
                            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7412)
                            }
                            result.success(AppUpdateDownloads.start(this, call.arguments as Map<*, *>))
                        }
                        "install" -> installUpdate(result)
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("UPDATE_FAILED", error.message ?: "تعذّر تنفيذ التحديث.", null)
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        waitingForInstallPermission = savedInstanceState?.getBoolean("update_install_permission") ?: false
        handleUpdateIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleUpdateIntent(intent)
    }

    private fun handleUpdateIntent(intent: Intent?) {
        if (intent?.action == AppUpdateDownloads.INSTALL_ACTION) {
            intent.action = null
            installUpdate(null)
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("update_install_permission", waitingForInstallPermission)
        super.onSaveInstanceState(outState)
    }

    override fun onResume() {
        super.onResume()
        if (waitingForInstallPermission) {
            waitingForInstallPermission = false
            if (Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls()) installUpdate(null)
        }
    }

    private fun installUpdate(result: MethodChannel.Result?) {
        if (installing) { result?.success(null); return }
        installing = true
        Thread {
            val verified = runCatching { AppUpdateDownloads.verifiedFile(this) }
            runOnUiThread {
                installing = false
                try {
                    val apk = verified.getOrThrow()
                    if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                        waitingForInstallPermission = true
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                        result?.success("permission")
                    } else {
                        val uri = FileProvider.getUriForFile(this, "$packageName.update_files", apk)
                        startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        })
                        result?.success("opened")
                    }
                } catch (error: Exception) {
                    val message = error.message ?: "تعذّر فتح تثبيت التحديث."
                    if (result != null) result.error("INSTALL_FAILED", message, null)
                    else Toast.makeText(this, message, Toast.LENGTH_LONG).show()
                }
            }
        }.start()
    }
}
