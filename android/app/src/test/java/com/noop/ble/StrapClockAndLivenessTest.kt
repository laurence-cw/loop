package com.noop.ble

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Twin of the Swift `StrapClockAndLivenessTests`: same inputs, same answers. */
class StrapClockAndLivenessTest {

    @Test fun `a clock loss on a live bonded link restores the clock`() {
        assertTrue(WhoopBleClient.shouldRestoreStrapClock(true, true, null))
    }

    @Test fun `the second event of a pair does not repeat the set`() {
        assertFalse(WhoopBleClient.shouldRestoreStrapClock(true, true, 0.2))
        assertTrue(WhoopBleClient.shouldRestoreStrapClock(true, true, 30.0))
    }

    @Test fun `no link or no bond sends nothing`() {
        assertFalse(WhoopBleClient.shouldRestoreStrapClock(false, true, null))
        assertFalse(WhoopBleClient.shouldRestoreStrapClock(true, false, null))
    }

    @Test fun `an armed WHOOP 4 keeps the tight fuse`() {
        assertEquals(120_000L, WhoopBleClient.livenessBounceFuseMs(isWhoop5 = false, realtimeArmed = true))
    }

    @Test fun `an unarmed WHOOP 4 gets the wide fuse`() {
        assertEquals(600_000L, WhoopBleClient.livenessBounceFuseMs(isWhoop5 = false, realtimeArmed = false))
    }

    @Test fun `WHOOP 5 is unchanged`() {
        assertEquals(600_000L, WhoopBleClient.livenessBounceFuseMs(isWhoop5 = true, realtimeArmed = true))
        assertEquals(600_000L, WhoopBleClient.livenessBounceFuseMs(isWhoop5 = true, realtimeArmed = false))
    }
}
