package com.example.voxa

import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncSettings" -> {
                    val arguments = call.arguments as? Map<*, *>
                    if (arguments == null) {
                        result.error("bad_args", "Expected a settings map.", null)
                        return@setMethodCallHandler
                    }
                    ImePrefs(applicationContext).save(arguments)
                    result.success(null)
                }

                "openInputMethodSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK,
                        ),
                    )
                    result.success(null)
                }

                "showInputMethodPicker" -> {
                    val inputMethodManager =
                        getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager
                    inputMethodManager?.showInputMethodPicker()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        const val CHANNEL_NAME = "chivoice/ime"
    }
}
