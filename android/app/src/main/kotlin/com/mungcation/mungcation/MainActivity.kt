package com.mungcation.mungcation

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private data class FileOperation(val importing: Boolean, val result: MethodChannel.Result, val source: File? = null)
    private var pendingFile: FileOperation? = null
    private var notificationResult: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val exportRequest = 60071
    private val importRequest = 60072
    private val notificationRequest = 60073
    private val maxBackupBytes = 32 * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mungcation/android").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotifications" -> {
                    if (notificationResult != null) { result.error("busy", "권한 요청이 진행 중이에요.", null) }
                    else if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        notificationResult = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequest)
                    } else { result.success((getSystemService(android.app.NotificationManager::class.java)?.areNotificationsEnabled() == true)) }
                }
                "openMap" -> {
                    val lat = call.argument<Number>("lat")?.toDouble()
                    val lon = call.argument<Number>("lon")?.toDouble()
                    if (lat == null || lon == null || !lat.isFinite() || !lon.isFinite() || lat !in -90.0..90.0 || lon !in -180.0..180.0) {
                        result.error("coordinates", "장소의 좌표가 올바르지 않아요.", null)
                    } else {
                        val name = Uri.encode(call.argument<String>("name") ?: "목적지")
                        try { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("geo:$lat,$lon?q=$lat,$lon($name)"))); result.success(true) }
                        catch (_: ActivityNotFoundException) { result.success(openHttps("https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=16/$lat/$lon")) }
                    }
                }
                "openUrl" -> result.success(openHttps(call.argument<String>("url") ?: ""))
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mungcation/files").setMethodCallHandler { call, result ->
            if (pendingFile != null) { result.error("busy", "열려 있는 파일 작업을 먼저 마쳐 주세요.", null); return@setMethodCallHandler }
            try {
                when (call.method) {
                    "share" -> {
                        val path = call.argument<String>("path") ?: throw IllegalArgumentException()
                        val file = File(path).canonicalFile
                        val base = File(cacheDir, "mungcation_exports").canonicalPath + File.separator
                        if (!file.path.startsWith(base) || !file.isFile || file.extension !in listOf("json", "gpx")) throw IllegalArgumentException()
                        pendingFile = FileOperation(false, result, file)
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = if (file.extension == "json") "application/json" else "application/gpx+xml"
                            putExtra(Intent.EXTRA_TITLE, file.name)
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, exportRequest)
                    }
                    "pickBackup" -> {
                        pendingFile = FileOperation(true, result)
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "application/octet-stream", "text/plain"))
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, importRequest)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                pendingFile = null
                result.error("file", "파일 화면을 열지 못했어요. 앱에서 만든 JSON 또는 GPX 파일만 내보낼 수 있어요.", null)
            }
        }
    }
    private fun openHttps(value: String): Boolean {
        val uri = Uri.parse(value)
        if (uri.scheme != "https" || uri.host.isNullOrBlank() || uri.userInfo != null) return false
        return try { startActivity(Intent(Intent.ACTION_VIEW, uri)); true } catch (_: ActivityNotFoundException) { false }
    }
    @Deprecated("Android activity result compatibility bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != exportRequest && requestCode != importRequest) { super.onActivityResult(requestCode, resultCode, data); return }
        val operation = pendingFile ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { finishFile(operation, if (operation.importing) null else false); return }
        if (uri.scheme != "content") { finishFile(operation, error = "파일 제공자의 주소가 올바르지 않아요."); return }
        worker.execute {
            try {
                if (operation.importing) {
                    contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst() && !cursor.isNull(0) && cursor.getLong(0) > maxBackupBytes) throw IllegalArgumentException("32MB 이하의 백업을 선택해 주세요.")
                    }
                    val bytes = contentResolver.openInputStream(uri)?.use { input ->
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            if (output.size() + count > maxBackupBytes) throw IllegalArgumentException("32MB 이하의 백업을 선택해 주세요.")
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    } ?: throw IllegalArgumentException("백업 파일을 읽지 못했어요.")
                    finishFile(operation, bytes)
                } else {
                    val file = operation.source ?: throw IllegalArgumentException()
                    contentResolver.openOutputStream(uri, "w")?.use { output -> file.inputStream().use { it.copyTo(output) }; output.flush() }
                        ?: throw IllegalArgumentException("파일을 저장하지 못했어요.")
                    finishFile(operation, true)
                }
            } catch (error: Exception) { finishFile(operation, error = if (error is IllegalArgumentException) error.message else "파일 작업을 완료하지 못했어요.") }
        }
    }
    private fun finishFile(operation: FileOperation, value: Any? = null, error: String? = null) {
        main.post {
            if (pendingFile !== operation) return@post
            pendingFile = null
            if (error != null) operation.result.error("file", error, null) else operation.result.success(value)
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationRequest) {
            notificationResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            notificationResult = null
        }
    }
    override fun onDestroy() {
        pendingFile?.result?.error("cancelled", "파일 작업이 중단됐어요.", null)
        pendingFile = null
        notificationResult?.success(false)
        notificationResult = null
        worker.shutdownNow()
        super.onDestroy()
    }
}
