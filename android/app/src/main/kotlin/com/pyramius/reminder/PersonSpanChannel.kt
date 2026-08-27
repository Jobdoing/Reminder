package com.pyramius.reminder

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

internal fun validPersonWords(text: String, words: Array<String>): List<String> =
    words.filter { it.isNotBlank() && text.contains(it) }

class PersonSpanChannel private constructor(context: Context) {
    companion object {
        private const val METHOD_CHANNEL = "reminder/person_spans"

        fun register(messenger: BinaryMessenger, context: Context) {
            val channel = PersonSpanChannel(context.applicationContext)
            MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
                if (call.method != "detect") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.arguments as? String
                if (text == null) {
                    result.success(emptyList<String>())
                    return@setMethodCallHandler
                }
                channel.detect(text) { words -> result.success(words) }
            }
        }
    }

    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    // NOTE(ceiling): One worker serializes short LAC calls; use a pool only if
    // batch inference is introduced with one native predictor per worker.
    private val worker = Executors.newSingleThreadExecutor()
    private val detector by lazy { PersonDetector(appContext) }

    private fun detect(text: String, complete: (List<String>) -> Unit) {
        if (text.isBlank()) {
            complete(emptyList())
            return
        }
        worker.execute {
            val words = try {
                validPersonWords(text, detector.detect(text))
            } catch (_: Exception) {
                emptyList()
            } catch (_: LinkageError) {
                emptyList()
            }
            mainHandler.post { complete(words) }
        }
    }
}

private class PersonDetector(private val context: Context) {
    companion object {
        private const val MODEL_DIRECTORY = "lac_lite_v2_0"
        private val assets = mapOf(
            "model.nb" to (
                1932895L to "df087c346e626586fc6d9a7ff2c27bf3ee373bf74577e042f72a8a4c6e541104"
            ),
            "q2b.dic" to (
                45051L to "c776a03c9cfd0f7d250c82d405030ce282d65e0e41083a35f81b8ab7f91aa4c7"
            ),
            "tag.dic" to (
                425L to "0e10caa505cd12e6f43630505503ccf24ee081f61a155fcc186041601cfd0bfe"
            ),
            "word.dic" to (
                72549L to "fe4cf2f3c6ebfc229d756a2c26934472d7bc8999f3d07d2b8f70a60741782e70"
            ),
        )

        init {
            System.loadLibrary("person_ner")
        }
    }

    private external fun detectNative(modelPath: String, text: String): Array<String>

    private val modelDirectory by lazy(::prepareModel)

    fun detect(text: String): Array<String> =
        detectNative(modelDirectory.absolutePath, text)

    private fun prepareModel(): File {
        val directory = File(context.cacheDir, MODEL_DIRECTORY)
        check(directory.isDirectory || directory.mkdirs())
        for ((name, expected) in assets) {
            val (expectedSize, expectedHash) = expected
            val target = File(directory, name)
            if (target.isFile && target.length() == expectedSize && sha256(target) == expectedHash) {
                continue
            }
            val temporary = File(directory, "$name.tmp")
            context.assets.open("lac_model/$name").use { input ->
                temporary.outputStream().use(input::copyTo)
            }
            check(temporary.length() == expectedSize)
            check(sha256(temporary) == expectedHash)
            if (target.exists()) check(target.delete())
            check(temporary.renameTo(target))
        }
        return directory
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { byte ->
            "%02x".format(byte.toInt() and 0xff)
        }
    }
}
