package ng.com.hamduk.chess

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hamduk/device").setMethodCallHandler { call, result ->
            when (call.method) {
                // Where Android unpacked the app's native files, including the Stockfish program.
                "nativeLibraryDir" -> result.success(applicationInfo.nativeLibraryDir)
                // Total memory, so the heaviest bots can be kept off 2 GB phones.
                "totalRamMb" -> {
                    val info = ActivityManager.MemoryInfo()
                    (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(info)
                    result.success((info.totalMem / (1024 * 1024)).toInt())
                }
                else -> result.notImplemented()
            }
        }
    }
}
