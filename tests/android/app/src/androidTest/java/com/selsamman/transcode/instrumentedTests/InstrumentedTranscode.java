package com.selsamman.transcode.instrumentedTests;


import com.selsamman.transcode.TranscodeModule;
import android.support.test.runner.AndroidJUnit4;
import org.junit.Test;
import org.junit.runner.RunWith;

import static junit.framework.Assert.assertEquals;

@RunWith(AndroidJUnit4.class)
public class InstrumentedTranscode {

    @Test
    public void shouldSayHello() {
        TranscodeModule transcodeModule = new TranscodeModule(new ReactContextMock());
        String hello = transcodeModule.sayHello();
        assertEquals("Native hello world!", hello);
    }
}