package com.example.mobarandom

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import java.util.concurrent.Executors

class Bo3AvatarRepository(private val context: Context) {
    private val index: Bo3AvatarIndex? = runCatching {
        context.assets.open("BO3/avatar-index.json").bufferedReader().use { it.readText() }
    }.getOrNull()?.let(Bo3AvatarIndex::fromJson)

    private val cache = LruCache<String, Bitmap>(48)
    private val executor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    val avatarCount: Int
        get() = index?.avatarCount ?: 0

    fun descriptor(name: String): Bo3AvatarDescriptor =
        index?.descriptor(name) ?: Bo3AvatarDescriptor(
            displayName = name.trim().ifEmpty { "?" },
            officialName = null,
            file = null,
            element = null,
            fallbackSeed = Bo3Palette.hash(name),
        )

    fun load(name: String, sizePx: Int, callback: (Bitmap?) -> Unit) {
        val descriptor = descriptor(name)
        val file = descriptor.file
        if (file == null) {
            callback(null)
            return
        }
        val key = "$file@$sizePx"
        cache.get(key)?.let {
            callback(it)
            return
        }
        executor.execute {
            val bitmap = decode(file, sizePx)
            if (bitmap != null) cache.put(key, bitmap)
            mainHandler.post { callback(bitmap) }
        }
    }

    private fun decode(file: String, sizePx: Int): Bitmap? = runCatching {
        context.assets.open("BO3/avatars/$file.webp").use { stream ->
            BitmapFactory.decodeStream(stream)
        }?.let { source ->
            if (source.width == sizePx && source.height == sizePx) {
                source
            } else {
                Bitmap.createScaledBitmap(source, sizePx, sizePx, true).also {
                    if (it !== source) source.recycle()
                }
            }
        }
    }.getOrNull()
}
