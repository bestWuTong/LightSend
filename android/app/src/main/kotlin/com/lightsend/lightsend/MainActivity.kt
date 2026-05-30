package com.lightsend.lightsend

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val STORAGE_PERMISSION_CHANNEL = "lightsend/storage_permission"
    private val SHARE_CHANNEL = "lightsend/share"
    private val FILE_CHANNEL = "lightsend/file"

    private val pendingSharePaths = mutableListOf<String>()
    private var shareChannel: MethodChannel? = null
    private var dartShareHandlerReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STORAGE_PERMISSION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasManageStoragePermission" -> {
                    result.success(hasManageStoragePermission())
                }
                "openManageStorageSettings" -> {
                    openManageStorageSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_CHANNEL
        )
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingSharedFiles" -> {
                    dartShareHandlerReady = true
                    result.success(mapOf("paths" to consumePendingSharePaths()))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FILE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDirectory" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        openDirectory(path)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return

        val paths = mutableListOf<String>()

        when (intent.action) {
            Intent.ACTION_SEND -> {
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uri ->
                    val path = copySharedFileToCache(uri)
                    if (path != null) paths.add(path)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris ->
                    for (uri in uris) {
                        val path = copySharedFileToCache(uri)
                        if (path != null) paths.add(path)
                    }
                }
            }
        }

        if (paths.isNotEmpty()) {
            pendingSharePaths.addAll(paths)
            notifySharedFilesIfReady()
        }
    }

    private fun notifySharedFilesIfReady() {
        if (!dartShareHandlerReady || pendingSharePaths.isEmpty()) return
        shareChannel?.invokeMethod("onSharedFiles", mapOf("paths" to consumePendingSharePaths()))
    }

    private fun consumePendingSharePaths(): List<String> {
        val paths = pendingSharePaths.toList()
        pendingSharePaths.clear()
        return paths
    }

    /**
     * Copies a shared content URI to a local cache file so Flutter can access it.
     * Returns the absolute path of the cached file, or null on failure.
     */
    private fun copySharedFileToCache(uri: Uri): String? {
        return try {
            val fileName = getFileName(uri)
            val cacheDir = cacheDir.resolve("shared")
            cacheDir.mkdirs()
            val destFile = File(cacheDir, fileName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }

            destFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Tries to resolve a display name from the content URI.
     * Falls back to a timestamp-based name.
     */
    private fun getFileName(uri: Uri): String {
        var name: String? = null
        try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) name = cursor.getString(idx)
                }
            }
        } catch (_: Exception) {}
        return name ?: "shared_file_${System.currentTimeMillis()}"
    }

    /**
     * Opens a directory in the system file manager.
     * Uses ACTION_VIEW with the directory URI, falling back to DocumentsUI on Android 11+.
     */
    private fun openDirectory(path: String) {
        try {
            val dir = File(path)
            if (!dir.exists() || !dir.isDirectory) return

            val uri = Uri.fromFile(dir)

            // Try standard file manager intent first
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "resource/folder")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            // Check if any app can handle this intent
            if (packageManager.resolveActivity(intent, 0) != null) {
                startActivity(intent)
            } else {
                // Fallback: open parent directory with the file selected
                val parentIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "*/*")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try {
                    startActivity(parentIntent)
                } catch (_: Exception) {
                    // Last resort: open DocumentsUI
                    val docsIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "vnd.android.document/root")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(docsIntent)
                }
            }
        } catch (_: Exception) {}
    }

    // ─── Storage permission helpers ──────────────────────────────────────────

    private fun hasManageStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    private fun openManageStorageSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:${packageName}")
                startActivity(intent)
            } catch (_: Exception) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivity(intent)
                } catch (_: Exception) {}
            }
        }
    }
}
