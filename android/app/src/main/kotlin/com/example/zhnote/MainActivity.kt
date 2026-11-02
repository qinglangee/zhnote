package com.example.zhnote

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.FileNotFoundException
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {

    companion object {
        private const val REQUEST_OPEN_DOCUMENT = 1001
        private const val REQUEST_CREATE_DOCUMENT = 1002
        private const val REQUEST_NOTIFICATION_PERMISSION = 1003
    }

    private var pendingOpenResult: MethodChannel.Result? = null
    private var pendingCreateResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerFloatingBallChannel(flutterEngine)
        registerFileAccessChannel(flutterEngine)
    }

    private fun registerFloatingBallChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zhnote/floating_ball")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        if (!FloatingBallManager.hasPermission(this)) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        requestNotificationPermissionIfNeeded()
                        FloatingBallService.start(this)
                        result.success(true)
                    }

                    "hide" -> {
                        FloatingBallService.stop(this)
                        result.success(null)
                    }

                    "isVisible" -> result.success(FloatingBallManager.isVisible())

                    "hasPermission" -> result.success(FloatingBallManager.hasPermission(this))

                    "openPermissionSettings" -> {
                        openOverlayPermissionSettings()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun registerFileAccessChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zhnote/file_access")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFile" -> {
                        pendingOpenResult?.success(null)
                        pendingOpenResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "text/plain"
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        }
                        startActivityForResult(intent, REQUEST_OPEN_DOCUMENT)
                    }

                    "createFile" -> {
                        pendingCreateResult?.success(null)
                        pendingCreateResult = result
                        val fileName = call.argument<String>("fileName") ?: "notes.txt"
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TITLE, fileName)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        }
                        startActivityForResult(intent, REQUEST_CREATE_DOCUMENT)
                    }

                    "readText" -> readText(call, result)
                    "writeText" -> writeText(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun readText(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        if (uriString.isNullOrEmpty()) {
            result.error("invalid_uri", "笔记文件位置为空", null)
            return
        }
        try {
            val input = contentResolver.openInputStream(Uri.parse(uriString))
            if (input == null) {
                result.success(null)
                return
            }
            input.use { stream ->
                val text = BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).readText()
                result.success(text)
            }
        } catch (error: FileNotFoundException) {
            // 文件还不存在，按空内容处理。
            result.success(null)
        } catch (error: Exception) {
            result.error("read_failed", error.message, null)
        }
    }

    private fun writeText(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        val text = call.argument<String>("text") ?: ""
        if (uriString.isNullOrEmpty()) {
            result.error("invalid_uri", "笔记文件位置为空", null)
            return
        }
        try {
            val output = contentResolver.openOutputStream(Uri.parse(uriString), "wt")
            if (output == null) {
                result.error("write_failed", "无法打开笔记文件", null)
                return
            }
            output.use { stream ->
                stream.write(text.toByteArray(Charsets.UTF_8))
                stream.flush()
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("write_failed", error.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_OPEN_DOCUMENT || requestCode == REQUEST_CREATE_DOCUMENT) {
            val pending = if (requestCode == REQUEST_OPEN_DOCUMENT) {
                pendingOpenResult.also { pendingOpenResult = null }
            } else {
                pendingCreateResult.also { pendingCreateResult = null }
            }
            val uri = data?.data
            if (resultCode == Activity.RESULT_OK && uri != null) {
                persistPermission(uri)
                pending?.success(uri.toString())
            } else {
                pending?.success(null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun persistPermission(uri: Uri) {
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (error: SecurityException) {
            // 部分提供方只授予读权限，退化为只持久化读权限。
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (ignored: SecurityException) {
                // 无法持久化时，重启应用后需要重新选择文件。
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATION_PERMISSION,
        )
    }

    private fun openOverlayPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }
}
