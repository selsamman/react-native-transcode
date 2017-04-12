package com.selsamman.transcode.tests;

import com.selsamman.transcode.TranscodeModule;

import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class TranscodeModuleTests {

  @Test
  public void shouldSayHello() {
    TranscodeModule transcodeModule = new TranscodeModule(new ReactContextMock());
    String hello = transcodeModule.sayHello();
    assertEquals("Native hello world!", hello);
  }
}
