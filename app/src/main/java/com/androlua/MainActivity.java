package com.androlua;

import android.content.Intent;
import android.os.Bundle;
import android.widget.ArrayAdapter;
import android.widget.ListView;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setTitle("AndroLua Professional - Native");

        ListView listView = new ListView(this);
        List<MoreOptions.Option> options = MoreOptions.create();
        List<String> titles = new ArrayList<>();
        for (MoreOptions.Option option : options) {
            titles.add(option.title);
        }

        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, titles);
        listView.setAdapter(adapter);
        listView.setOnItemClickListener((parent, view, position, id) -> {
            MoreOptions.Option option = options.get(position);
            Intent intent = new Intent(MainActivity.this, option.activityClass);
            startActivity(intent);
        });

        setContentView(listView);
        maybeShowVersionDialog();
    }

    private void maybeShowVersionDialog() {
        Intent intent = getIntent();
        if (!intent.getBooleanExtra("isVersionChanged", false)) {
            return;
        }

        String newVersion = intent.getStringExtra("newVersionName");
        String oldVersion = intent.getStringExtra("oldVersionName");

        String message = "Updated from " + (oldVersion == null ? "unknown" : oldVersion)
                + " to " + (newVersion == null ? "unknown" : newVersion)
                + "\n\nThe app is now using native Java AndroidX screens.";

        new AlertDialog.Builder(this)
                .setTitle("Version Updated")
                .setMessage(message)
                .setPositiveButton("OK", null)
                .show();
    }
}
