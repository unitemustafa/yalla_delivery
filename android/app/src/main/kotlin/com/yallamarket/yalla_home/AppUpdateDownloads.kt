package com.yallamarket.yalla_home

import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

/** System-owned downloads survive activity/process destruction. No storage permission. */
object AppUpdateDownloads {
    const val INSTALL_ACTION = "com.yallamarket.yalla_home.INSTALL_UPDATE"
    private const val CHANNEL = "app_updates"
    private const val NOTIFICATION_ID = 7412
    private val verifying = AtomicBoolean(false)
    private fun prefs(context: Context) = context.getSharedPreferences("app_updates", Context.MODE_PRIVATE)
    private fun manager(context: Context) = context.getSystemService(DownloadManager::class.java)
    private fun file(context: Context, code: Long) =
        File(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "yalla-delivery-$code.apk")

    @Suppress("DEPRECATION")
    private fun code(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()

    fun installedVersion(context: Context): Long =
        code(context.packageManager.getPackageInfo(context.packageName, 0))

    fun start(context: Context, args: Map<*, *>): Map<String, Any> {
        val url = args["download_url"] as? String ?: error("رابط التحميل غير صالح.")
        val uri = Uri.parse(url)
        require(uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null && uri.fragment == null) {
            "يلزم رابط تحميل HTTPS صالح."
        }
        val version = (args["version_code"] as? Number)?.toLong() ?: 0
        val size = (args["file_size"] as? Number)?.toLong() ?: 0
        val sha = args["sha256"] as? String ?: ""
        val name = args["version_name"] as? String ?: ""
        require(version > installedVersion(context) && version <= 2_100_000_000 && size in 1..100_000_000 &&
            sha.matches(Regex("[a-f0-9]{64}")) && name.isNotBlank() && name.length <= 40) {
            "بيانات التحديث غير صالحة."
        }
        val saved = prefs(context)
        if (saved.getLong("version", 0) == version) {
            val current = status(context)
            if (current["status"] in listOf("downloading", "verifying", "ready")) return current
        }
        manager(context).remove(saved.getLong("id", -1))
        val oldCode = saved.getLong("version", 0)
        if (oldCode > 0) file(context, oldCode).delete()
        file(context, version).delete()
        val request = DownloadManager.Request(uri)
            .setTitle("تحديث يلا دليفيري $name")
            .setDescription("جارٍ تحميل التحديث — يمكنك متابعة استخدام التطبيق")
            .setMimeType("application/vnd.android.package-archive")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
            .setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS, "yalla-delivery-$version.apk")
        val id = manager(context).enqueue(request)
        saved.edit().clear().putLong("id", id).putLong("version", version)
            .putLong("size", size).putString("sha256", sha).putString("name", name).commit()
        return status(context)
    }

    fun status(context: Context): Map<String, Any> {
        val saved = prefs(context)
        val version = saved.getLong("version", 0)
        val id = saved.getLong("id", -1)
        if (version <= installedVersion(context) || id < 0) {
            if (id >= 0) {
                manager(context).remove(id)
                file(context, version).delete()
                saved.edit().clear().apply()
                context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
            }
            return mapOf("status" to "idle")
        }
        var state = "failed"
        var downloaded = 0L
        var total = saved.getLong("size", 0)
        manager(context).query(DownloadManager.Query().setFilterById(id)).use { cursor ->
            if (cursor.moveToFirst()) {
                downloaded = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                val measured = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                if (measured > 0) total = measured
                state = when (cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
                    DownloadManager.STATUS_SUCCESSFUL -> when {
                        !saved.getString("error", "").isNullOrEmpty() -> "failed"
                        saved.getBoolean("verified", false) && file(context, version).isFile -> "ready"
                        else -> "verifying"
                    }
                    DownloadManager.STATUS_PENDING, DownloadManager.STATUS_PAUSED, DownloadManager.STATUS_RUNNING -> "downloading"
                    else -> "failed"
                }
            }
        }
        if (state == "verifying") verifyAsync(context, id)
        return mapOf(
            "status" to state, "version_code" to version,
            "version_name" to saved.getString("name", "").orEmpty(),
            "downloaded" to downloaded, "total" to total,
            "message" to saved.getString("error", "تعذّر تحميل التحديث. حاول مرة أخرى.").orEmpty(),
        )
    }

    @Suppress("DEPRECATION")
    private fun signatures(info: PackageInfo): Set<String> {
        val values = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        return values?.map { it.toCharsString() }?.toSet().orEmpty()
    }

    @Suppress("DEPRECATION")
    fun verifiedFile(context: Context): File {
        val saved = prefs(context)
        val version = saved.getLong("version", 0)
        val apk = file(context, version)
        require(apk.isFile && apk.length() == saved.getLong("size", -1)) { "ملف التحديث غير مكتمل. أعد تحميله." }
        val digest = MessageDigest.getInstance("SHA-256")
        apk.inputStream().buffered().use { stream ->
            val buffer = ByteArray(65536)
            var count = stream.read(buffer)
            while (count != -1) {
                digest.update(buffer, 0, count)
                count = stream.read(buffer)
            }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        require(actual == saved.getString("sha256", "")) { "تعذّر التحقق من سلامة التحديث. أعد تحميله." }
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val archive = context.packageManager.getPackageArchiveInfo(apk.absolutePath, flags)
            ?: error("ملف التحديث غير صالح للتثبيت.")
        val installed = context.packageManager.getPackageInfo(context.packageName, flags)
        require(archive.packageName == context.packageName && code(archive) == version && version > code(installed)) {
            "الملف ليس إصدارًا أحدث من يلا دليفيري."
        }
        require(signatures(archive).isNotEmpty() && signatures(archive) == signatures(installed)) {
            "توقيع التحديث مختلف عن التطبيق المثبّت."
        }
        return apk
    }

    fun verifyAsync(context: Context, id: Long, finished: (() -> Unit)? = null) {
        val app = context.applicationContext
        if (prefs(app).getLong("id", -1) != id || !verifying.compareAndSet(false, true)) {
            finished?.invoke()
            return
        }
        Thread {
            try {
                // Broadcasts can be spoofed: check the persisted download ID and
                // DownloadManager's state before reading or advertising the APK.
                var completed = false
                manager(app).query(DownloadManager.Query().setFilterById(id)).use {
                    completed = it.moveToFirst() && it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)) == DownloadManager.STATUS_SUCCESSFUL
                }
                if (!completed) return@Thread
                val issue = runCatching { verifiedFile(app) }.exceptionOrNull()
                if (prefs(app).getLong("id", -1) != id) return@Thread
                prefs(app).edit().putBoolean("verified", issue == null)
                    .putString("error", issue?.message.orEmpty()).commit()
                notifyCompleted(app, issue == null)
            } finally {
                verifying.set(false)
                finished?.invoke()
            }
        }.start()
    }

    private fun notifyCompleted(context: Context, success: Boolean) {
        val notifications = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            notifications.createNotificationChannel(NotificationChannel(CHANNEL, "تحديثات التطبيق", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val intent = Intent(context, MainActivity::class.java).apply {
            if (success) action = INSTALL_ACTION
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(context, NOTIFICATION_ID, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(if (success) "اكتمل تحميل تحديث يلا دليفيري" else "تعذّر تجهيز التحديث")
            .setContentText(if (success) "اضغط لتثبيت التحديث" else "افتح التطبيق لإعادة المحاولة")
            .setContentIntent(pending).setAutoCancel(true).build()
        // Denying notifications never prevents downloading or in-app installation.
        runCatching { notifications.notify(NOTIFICATION_ID, notification) }
    }
}
