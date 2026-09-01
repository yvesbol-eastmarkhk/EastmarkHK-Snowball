package com.eastmarkhk.eastmarkhk_snowball

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.pdf.PdfRenderer
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.pdf.PrintedPdfDocument
import java.io.File
import java.io.FileOutputStream
import kotlin.math.min

/**
 * Samsung / Android Print Services often rasterize a vector PDF at ~72–150 DPI,
 * which looks nothing like iOS. We rasterize each page ourselves at print DPI
 * (RENDER_MODE_FOR_PRINT) and hand the print service a bitmap PDF.
 */
class HighQualityPdfPrintAdapter(
  private val context: Context,
  private val jobName: String,
  private val pdfBytes: ByteArray,
) : PrintDocumentAdapter() {
  private var attributes: PrintAttributes? = null
  private var pageCount = PrintDocumentInfo.PAGE_COUNT_UNKNOWN
  private var sourceFile: File? = null

  override fun onStart() {
    val file = File.createTempFile("snowball-print", ".pdf", context.cacheDir)
    file.writeBytes(pdfBytes)
    sourceFile = file
    pageCount = countPages(file)
  }

  override fun onFinish() {
    sourceFile?.delete()
    sourceFile = null
  }

  override fun onLayout(
    oldAttributes: PrintAttributes?,
    newAttributes: PrintAttributes,
    cancellationSignal: CancellationSignal,
    callback: LayoutResultCallback,
    extras: Bundle?,
  ) {
    if (cancellationSignal.isCanceled) {
      callback.onLayoutCancelled()
      return
    }
    attributes = newAttributes
    val info = PrintDocumentInfo.Builder(jobName)
      .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
      .setPageCount(pageCount)
      .build()
    callback.onLayoutFinished(info, true)
  }

  override fun onWrite(
    pages: Array<PageRange>,
    destination: ParcelFileDescriptor,
    cancellationSignal: CancellationSignal,
    callback: WriteResultCallback,
  ) {
    if (cancellationSignal.isCanceled) {
      callback.onWriteCancelled()
      return
    }
    val attrs = attributes
    val file = sourceFile
    if (attrs == null || file == null || !file.exists()) {
      callback.onWriteFailed("PDF print source missing")
      return
    }

    try {
      writeRasterizedPdf(file, attrs, pages, destination, cancellationSignal)
      if (cancellationSignal.isCanceled) {
        callback.onWriteCancelled()
      } else {
        callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
      }
    } catch (oom: OutOfMemoryError) {
      callback.onWriteFailed("Not enough memory to print at high quality")
    } catch (e: Exception) {
      callback.onWriteFailed(e.message)
    }
  }

  private fun writeRasterizedPdf(
    file: File,
    attrs: PrintAttributes,
    pages: Array<PageRange>,
    destination: ParcelFileDescriptor,
    cancellationSignal: CancellationSignal,
  ) {
    val printed = PrintedPdfDocument(context, attrs)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
      PdfRenderer(pfd).use { renderer ->
        for (index in 0 until renderer.pageCount) {
          if (cancellationSignal.isCanceled) break
          if (!pageInRanges(pages, index)) continue
          renderer.openPage(index).use { page ->
            val bitmap = renderPage(page)
            val docPage = printed.startPage(index)
            val canvas = docPage.canvas
            val dest = fitRect(
              bitmap.width.toFloat(),
              bitmap.height.toFloat(),
              canvas.width.toFloat(),
              canvas.height.toFloat(),
            )
            canvas.drawColor(Color.WHITE)
            canvas.drawBitmap(bitmap, null, dest, paint)
            printed.finishPage(docPage)
            bitmap.recycle()
          }
        }
      }
    }
    FileOutputStream(destination.fileDescriptor).use { printed.writeTo(it) }
    printed.close()
  }

  private fun renderPage(page: PdfRenderer.Page): Bitmap {
    for (dpi in intArrayOf(300, 220, 160)) {
      val scale = dpi / 72f
      val width = (page.width * scale).toInt().coerceAtLeast(1)
      val height = (page.height * scale).toInt().coerceAtLeast(1)
      try {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
        return bitmap
      } catch (_: OutOfMemoryError) {
        // Try a lower DPI.
      }
    }
    val fallback = Bitmap.createBitmap(
      page.width.coerceAtLeast(1),
      page.height.coerceAtLeast(1),
      Bitmap.Config.ARGB_8888,
    )
    fallback.eraseColor(Color.WHITE)
    page.render(fallback, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
    return fallback
  }

  private fun countPages(file: File): Int {
    return try {
      ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
        PdfRenderer(pfd).use { it.pageCount }
      }
    } catch (_: Exception) {
      PrintDocumentInfo.PAGE_COUNT_UNKNOWN
    }
  }

  private fun pageInRanges(ranges: Array<PageRange>, index: Int): Boolean {
    if (ranges.isEmpty()) return true
    for (range in ranges) {
      if (range === PageRange.ALL_PAGES) return true
      if (index >= range.start && index <= range.end) return true
    }
    return false
  }

  private fun fitRect(srcW: Float, srcH: Float, dstW: Float, dstH: Float): RectF {
    val scale = min(dstW / srcW, dstH / srcH)
    val w = srcW * scale
    val h = srcH * scale
    val left = (dstW - w) / 2f
    val top = (dstH - h) / 2f
    return RectF(left, top, left + w, top + h)
  }
}
