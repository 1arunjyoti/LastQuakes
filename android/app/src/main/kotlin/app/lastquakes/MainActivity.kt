package app.lastquakes

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import app.lastquakes.foss.FossLocationPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register FOSS location channel
        // We register it for all flavors now since we removed the plugins globally
        // Or we can check BuildConfig.FLAVOR if we want strict separation
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FossLocationPlugin.CHANNEL)
        channel.setMethodCallHandler(FossLocationPlugin(context))
    }
}
