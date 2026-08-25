package cc.jobdone.reminder

import android.speech.SpeechRecognizer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SpeechChannelStateTest {
    @Test
    fun pauseCommitsCurrentTextAndKeepsItWhenSpeechResumes() {
        val transcript = SpeechTranscriptAccumulator()
        transcript.updatePartial("first segment")
        transcript.commitCurrent()
        transcript.updatePartial("second segment")

        assertEquals("first segment second segment", transcript.fullText)
    }

    @Test
    fun finalCorrectionReplacesOnlyTheCurrentSegment() {
        val transcript = SpeechTranscriptAccumulator()
        transcript.updatePartial("draft")
        transcript.updatePartial("final correction")
        transcript.commitCurrent()
        transcript.updatePartial("following speech")

        assertEquals("final correction following speech", transcript.fullText)
    }

    @Test
    fun restartGateAllowsOneRestartAndRejectsCanceledWork() {
        val gate = SpeechRestartGate()
        val token = gate.schedule()

        assertTrue(token != null)
        assertNull(gate.schedule())
        gate.cancel()
        assertFalse(gate.consume(token!!))
    }

    @Test
    fun missingLanguageDownloadsOnlyOnceOnSupportedAndroid() {
        assertTrue(
            shouldDownloadLanguageModel(
                SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
                attempted = false,
                mode = SpeechRecognizerMode.ON_DEVICE,
                sdk = 34,
            ),
        )
        assertFalse(
            shouldDownloadLanguageModel(
                SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
                attempted = true,
                mode = SpeechRecognizerMode.ON_DEVICE,
                sdk = 34,
            ),
        )
        assertFalse(
            shouldDownloadLanguageModel(
                SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
                attempted = false,
                mode = SpeechRecognizerMode.ON_DEVICE,
                sdk = 32,
            ),
        )
        assertFalse(
            shouldDownloadLanguageModel(
                SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
                attempted = false,
                mode = SpeechRecognizerMode.GENERAL,
                sdk = 34,
            ),
        )
    }
}
