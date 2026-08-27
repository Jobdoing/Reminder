package com.pyramius.reminder

import org.junit.Assert.assertEquals
import org.junit.Test

class PersonSpanChannelTest {
    @Test
    fun keepsOnlyPersonWordsPresentInTranscript() {
        val words = validPersonWords(
            "李佩瑜明天和李佩瑜吃飯",
            arrayOf("", "王小明", "李佩瑜", "李佩瑜"),
        )

        assertEquals(listOf("李佩瑜", "李佩瑜"), words)
    }
}
