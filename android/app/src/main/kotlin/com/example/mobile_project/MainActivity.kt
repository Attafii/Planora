package com.example.mobile_project

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val speechRequest = 9211
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "planify/today_widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    TodayWidget.publish(this, call.argument<String>("date"), call.argument<List<*>>("entries"))
                    result.success(null)
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "planify/voice")
            .setMethodCallHandler { call, result ->
                when {
                    call.method != "dictate" -> result.notImplemented()
                    pending != null -> result.error("busy", "Speech input is already open.", null)
                    else -> {
                        val request = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                            .putExtra(RecognizerIntent.EXTRA_PROMPT, "Task title")
                        pending = result
                        try {
                            startActivityForResult(request, speechRequest)
                        } catch (error: ActivityNotFoundException) {
                            pending = null
                            result.error("unavailable", "Speech input is unavailable.", null)
                        }
                    }
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == speechRequest) {
            val words = if (resultCode == Activity.RESULT_OK)
                data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
            else null
            pending?.success(words)
            pending = null
        }
    }
}
