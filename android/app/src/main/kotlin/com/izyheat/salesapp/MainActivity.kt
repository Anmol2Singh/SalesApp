package com.izyheat.salesapp

import android.app.DownloadManager
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.izyheat.salesapp/file_folder"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openDownloadFolder") {
                try {
                    val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(Uri.parse("content://com.android.externalstorage.documents/document/primary:Download"), DocumentsContract.Document.MIME_TYPE_DIR)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e2: Exception) {
                        try {
                            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                                setDataAndType(Uri.parse(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).path), "*/*")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e3: Exception) {
                            result.error("UNAVAILABLE", "Cannot open file manager", e3.message)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
