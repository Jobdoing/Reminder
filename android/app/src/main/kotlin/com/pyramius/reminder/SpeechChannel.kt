package com.pyramius.reminder

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.ModelDownloadListener
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

internal class SpeechTranscriptAccumulator {
    private var committed = ""
    private var current = ""

    val fullText: String
        get() = join(committed, current)

    fun updatePartial(text: String) {
        val trimmed = text.trim()
        if (trimmed.isNotEmpty()) current = trimmed
    }

    fun commitCurrent() {
        committed = join(committed, current)
        current = ""
    }

    private fun join(earlier: String, later: String): String =
        listOf(earlier.trim(), later.trim()).filter(String::isNotEmpty).joinToString(" ")
}

internal class SpeechRestartGate {
    private var generation = 0
    private var pendingGeneration: Int? = null

    fun cancel() {
        generation += 1
        pendingGeneration = null
    }

    fun schedule(): Int? {
        if (pendingGeneration != null) return null
        pendingGeneration = generation
        return generation
    }

    fun consume(token: Int): Boolean {
        if (token != generation || pendingGeneration != token) return false
        pendingGeneration = null
        return true
    }
}

internal enum class SpeechRecognizerMode {
    ON_DEVICE,
    GENERAL,
}

internal fun shouldDownloadLanguageModel(
    error: Int,
    attempted: Boolean,
    mode: SpeechRecognizerMode,
    sdk: Int,
): Boolean = error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE &&
    !attempted && mode == SpeechRecognizerMode.ON_DEVICE && sdk >= 33

class SpeechChannel(private val context: Context) :
    EventChannel.StreamHandler,
    RecognitionListener {
    companion object {
        private const val EVENT_CHANNEL = "reminder/speech_events"
        private const val METHOD_CHANNEL = "reminder/speech_cmd"

        fun register(messenger: BinaryMessenger, context: Context) {
            val channel = SpeechChannel(context.applicationContext)
            EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(channel)
            MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> channel.start(result)
                    "stop" -> channel.stop(result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val connectivityManager = context.getSystemService(ConnectivityManager::class.java)
    private var eventSink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var running = false
    private var transcript = SpeechTranscriptAccumulator()
    private var lastEmitted = ""
    private val restartGate = SpeechRestartGate()
    private var restartRunnable: Runnable? = null
    private var modelDownloadAttempted = false
    private var recognizerMode = SpeechRecognizerMode.ON_DEVICE

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        handler.post(::stopActiveSession)
    }

    private fun start(result: MethodChannel.Result) {
        handler.post {
            if (!hasRecordAudioPermission()) {
                result.error("NO_PERMISSION", "Record audio permission is not granted", null)
                return@post
            }
            val onDeviceAvailable = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
            val generalAvailable = hasValidatedNetwork() &&
                SpeechRecognizer.isRecognitionAvailable(context)
            if (!onDeviceAvailable && !generalAvailable) {
                result.error("UNAVAILABLE", "On-device speech recognition is not available", null)
                return@post
            }

            stopActiveSession()
            transcript = SpeechTranscriptAccumulator()
            lastEmitted = ""
            modelDownloadAttempted = false
            running = true
            recognizerMode = if (onDeviceAvailable) {
                SpeechRecognizerMode.ON_DEVICE
            } else {
                SpeechRecognizerMode.GENERAL
            }
            recognizer = try {
                createRecognizer()
            } catch (_: UnsupportedOperationException) {
                running = false
                result.error("UNAVAILABLE", "On-device speech recognition is not available", null)
                return@post
            }
            recognizer?.setRecognitionListener(this)
            startSession()
            result.success(null)
        }
    }

    private fun stop(result: MethodChannel.Result) {
        handler.post {
            val finalText = transcript.fullText
            stopActiveSession()
            result.success(finalText)
        }
    }

    private fun startSession() {
        if (!running) return
        try {
            recognizer?.startListening(speechIntent())
        } catch (_: Exception) {
            scheduleRestart()
        }
    }

    private fun speechIntent(): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-TW")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
        }

    // Source: https://developer.android.com/reference/android/speech/SpeechRecognizer#triggerModelDownload(android.content.Intent,java.util.concurrent.Executor,android.speech.ModelDownloadListener)
    private fun downloadLanguageModel() {
        modelDownloadAttempted = true
        val recognizer = recognizer ?: return
        if (Build.VERSION.SDK_INT >= 34) {
            recognizer.triggerModelDownload(
                speechIntent(),
                context.mainExecutor,
                object : ModelDownloadListener {
                    override fun onProgress(completedPercent: Int) {}

                    override fun onSuccess() {
                        if (running) startSession()
                    }

                    override fun onScheduled() {
                        if (!fallbackToGeneralRecognizer()) {
                            endWithError(
                                "MODEL_DOWNLOAD_SCHEDULED",
                                "The offline Traditional Chinese model is scheduled for download",
                            )
                        }
                    }

                    override fun onError(error: Int) {
                        if (!fallbackToGeneralRecognizer()) {
                            endWithError(
                                "MODEL_DOWNLOAD_FAILED",
                                "The offline Traditional Chinese model download failed",
                                error,
                            )
                        }
                    }
                },
            )
            return
        }

        // NOTE(ceiling): API 33 can schedule a model download but cannot report
        // completion; the user must retry after the system finishes it.
        recognizer.triggerModelDownload(speechIntent())
        if (!fallbackToGeneralRecognizer()) {
            endWithError(
                "MODEL_DOWNLOAD_SCHEDULED",
                "The offline Traditional Chinese model is scheduled for download",
            )
        }
    }

    private fun scheduleRestart() {
        if (!running) return
        val token = restartGate.schedule() ?: return
        val restart = Runnable {
            restartRunnable = null
            if (restartGate.consume(token) && running) startSession()
        }
        restartRunnable = restart
        handler.postDelayed(restart, 250)
    }

    private fun cancelRestart() {
        restartRunnable?.let(handler::removeCallbacks)
        restartRunnable = null
        restartGate.cancel()
    }

    private fun handleText(text: String) {
        transcript.updatePartial(text)
        val fullText = transcript.fullText
        if (fullText.isNotEmpty() && fullText != lastEmitted) {
            lastEmitted = fullText
            eventSink?.success(mapOf("text" to fullText))
        }
    }

    private fun stopActiveSession() {
        running = false
        cancelRestart()
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
    }

    private fun endWithError(code: String, message: String, details: Int? = null) {
        if (!running) return
        eventSink?.error(code, message, details)
        stopActiveSession()
    }

    private fun createRecognizer(): SpeechRecognizer =
        if (recognizerMode == SpeechRecognizerMode.ON_DEVICE) {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } else {
            SpeechRecognizer.createSpeechRecognizer(context)
        }

    private fun fallbackToGeneralRecognizer(): Boolean {
        if (!running || !hasValidatedNetwork() ||
            !SpeechRecognizer.isRecognitionAvailable(context)
        ) {
            return false
        }
        recognizer?.cancel()
        recognizer?.destroy()
        recognizerMode = SpeechRecognizerMode.GENERAL
        recognizer = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer?.setRecognitionListener(this)
        startSession()
        return true
    }

    private fun hasValidatedNetwork(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    private fun hasRecordAudioPermission(): Boolean =
        context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun firstResult(results: Bundle?): String =
        results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()

    override fun onReadyForSpeech(params: Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {}

    override fun onError(error: Int) {
        if (!running) return
        transcript.commitCurrent()
        if (shouldDownloadLanguageModel(
                error,
                modelDownloadAttempted,
                recognizerMode,
                Build.VERSION.SDK_INT,
            )
        ) {
            downloadLanguageModel()
            return
        }
        if (recognizerMode == SpeechRecognizerMode.ON_DEVICE &&
            (error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
                error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE) &&
            fallbackToGeneralRecognizer()
        ) {
            return
        }
        if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ||
            error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
            error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE
        ) {
            endWithError(
                "UNAVAILABLE",
                "On-device Traditional Chinese speech recognition is unavailable",
                error,
            )
            return
        }
        scheduleRestart()
    }

    override fun onResults(results: Bundle?) {
        if (!running) return
        handleText(firstResult(results))
        transcript.commitCurrent()
        scheduleRestart()
    }

    override fun onPartialResults(partialResults: Bundle?) {
        if (!running) return
        handleText(firstResult(partialResults))
    }

    override fun onEvent(eventType: Int, params: Bundle?) {}
}
