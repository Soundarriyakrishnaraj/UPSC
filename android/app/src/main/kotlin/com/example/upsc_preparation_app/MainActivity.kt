
package com.example.upsc_preparation_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val DOWNLOAD_CHANNEL =
        "com.example.upsc_preparation_app/downloads"

    private val WIDGET_CHANNEL =
        "com.example.upsc_preparation_app/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Existing PDF download channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOAD_CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "savePdfToDownloads") {
                val bytes = call.argument<ByteArray>("bytes")
                val fileName =
                    call.argument<String>("fileName") ?: "UPSC_Report.pdf"

                if (bytes == null) {
                    result.error("INVALID_DATA", "Byte array is null", null)
                    return@setMethodCallHandler
                }

                try {
                    val savedPath = saveToDownloads(bytes, fileName)
                    result.success(savedPath)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }

        // New Test11 Home Screen widget channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "updateWidgetData" -> {
                    try {
                        val currentStreak =
                            call.argument<Int>("currentStreak") ?: 0

                        val testCount =
                            call.argument<Int>("testCount") ?: 0

                        val todayRecorded =
                            call.argument<Boolean>("todayRecorded") ?: false

                        StreakWidgetProvider.updateWidget(
                            applicationContext,
                            currentStreak,
                            testCount,
                            todayRecorded
                        )

                        result.success(true)

                    } catch (e: Exception) {
                        result.error(
                            "WIDGET_UPDATE_FAILED",
                            e.localizedMessage,
                            null
                        )
                    }
                }

                "clearWidgetData" -> {
                    try {
                        StreakWidgetProvider.clearWidget(applicationContext)
                        result.success(true)

                    } catch (e: Exception) {
                        result.error(
                            "WIDGET_CLEAR_FAILED",
                            e.localizedMessage,
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(bytes: ByteArray, fileName: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {

            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val resolver = applicationContext.contentResolver

            val uri = resolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                contentValues
            ) ?: throw Exception(
                "Could not initialize MediaStore Downloads entry."
            )

            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
            } ?: throw Exception(
                "Could not open output stream for Downloads."
            )

            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            "Downloads/$fileName"

        } else {

            val downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )

            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }

            var targetFile = File(downloadsDir, fileName)
            var counter = 1
            val baseName = fileName.substringBeforeLast(".")
            val ext = fileName.substringAfterLast(".", "pdf")

            while (targetFile.exists()) {
                targetFile = File(
                    downloadsDir,
                    "${baseName}_$counter.$ext"
                )
                counter++
            }

            FileOutputStream(targetFile).use {
                it.write(bytes)
            }

            targetFile.absolutePath
        }
    }
}
