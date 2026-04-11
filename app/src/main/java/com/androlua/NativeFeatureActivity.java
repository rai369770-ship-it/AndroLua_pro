package com.androlua;

import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

public class NativeFeatureActivity extends AppCompatActivity {

    protected String getFeatureTitle() {
        return getClass().getSimpleName();
    }

    protected String getFeatureDescription() {
        return "Native Java UI screen using AndroidX components.";
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setTitle(getFeatureTitle());

        int padding = (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                16,
                getResources().getDisplayMetrics()
        );

        ScrollView root = new ScrollView(this);
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setPadding(padding, padding, padding, padding);

        TextView headline = new TextView(this);
        headline.setText(getFeatureTitle());
        headline.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        headline.setGravity(Gravity.START);

        TextView description = new TextView(this);
        description.setText(getFeatureDescription());
        description.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        description.setPadding(0, padding / 2, 0, 0);

        body.addView(headline);
        body.addView(description);
        root.addView(body);

        setContentView(root);
    }
}
