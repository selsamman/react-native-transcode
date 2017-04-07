package com.benwixen.helloworld.instrumentedTests;


import com.benwixen.helloworld.HelloWorldModule;
import android.support.test.runner.AndroidJUnit4;
import org.junit.Test;
import org.junit.runner.RunWith;

import static junit.framework.Assert.assertEquals;

@RunWith(AndroidJUnit4.class)
public class InstrumentedHelloWorld {

    @Test
    public void shouldSayHello() {
        HelloWorldModule helloWorldModule = new HelloWorldModule(new ReactContextMock());
        String hello = helloWorldModule.sayHello();
        assertEquals("Native hello world!", hello);
    }
}