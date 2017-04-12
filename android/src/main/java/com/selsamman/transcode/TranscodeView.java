package com.selsamman.transcode;

import android.content.Context;
import android.graphics.Color;
import android.widget.FrameLayout;
import android.widget.TextView;

public class TranscodeView extends FrameLayout {

  public TranscodeView(Context context) {
    super(context);

    TextView label = new TextView(context);
    label.setText("Hello world!");
    setBackgroundColor(Color.YELLOW);
    addView(label);
  }
}
