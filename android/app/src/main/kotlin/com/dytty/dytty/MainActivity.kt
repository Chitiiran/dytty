package com.dytty.dytty

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts a DEBUG-ONLY broadcast receiver that forwards an exact text turn to
 * Flutter (DebugTextInjector) so the acoustic demo harness can drive a live
 * daily call with perfect input while the human voice plays aloud.
 *
 * Trigger from the harness:
 *   adb shell am broadcast -a com.dytty.dytty.INJECT_TEXT --es text "Hello"
 *
 * The receiver is registered only in debuggable builds; release builds never
 * wire it up, so this is inert in production.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "dytty/debug_inject"
    private val injectAction = "com.dytty.dytty.INJECT_TEXT"

    private var methodChannel: MethodChannel? = null
    private var injectReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val debuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable) return

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        )

        injectReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val text = intent?.getStringExtra("text") ?: return
                methodChannel?.invokeMethod("injectText", text)
            }
        }
        val filter = IntentFilter(injectAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(injectReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(injectReceiver, filter)
        }
    }

    override fun onDestroy() {
        injectReceiver?.let {
            runCatching { unregisterReceiver(it) }
            injectReceiver = null
        }
        super.onDestroy()
    }
}
