package com.eastmarkhk.eastmarkhk_snowball

import android.print.PrintAttributes
import android.print.PrintManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "com.eastmarkhk.snowball/print",
    ).setMethodCallHandler { call, result ->
      if (call.method != "printPdf") {
        result.notImplemented()
        return@setMethodCallHandler
      }
      val name = call.argument<String>("fileName") ?: "report.pdf"
      val bytes = readBytes(call.argument("bytes"))
      if (bytes == null || bytes.isEmpty()) {
        result.error("bad_args", "printPdf requires bytes", null)
        return@setMethodCallHandler
      }
      printPdf(name, bytes)
      result.success(true)
    }
  }

  private fun printPdf(name: String, data: ByteArray) {
    val printManager = getSystemService(PRINT_SERVICE) as PrintManager
    val attrs = PrintAttributes.Builder()
      .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
      .setResolution(PrintAttributes.Resolution("pdf", "pdf", 300, 300))
      .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
      .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
      .build()
    printManager.print(name, HighQualityPdfPrintAdapter(this, name, data), attrs)
  }

  private fun readBytes(raw: Any?): ByteArray? {
    return when (raw) {
      is ByteArray -> raw
      is ByteBuffer -> ByteArray(raw.remaining()).also { raw.duplicate().get(it) }
      else -> null
    }
  }
}
