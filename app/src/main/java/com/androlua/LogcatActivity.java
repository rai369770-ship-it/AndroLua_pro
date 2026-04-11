package com.androlua;

import android.app.Activity;
import android.os.AsyncTask;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

public class LogcatActivity extends Activity {

    private static final String[] MENU_ITEMS = new String[]{
            "All", "Lua", "Test", "Tcc", "Error", "Warning", "Info", "Debug", "Verbose", "Clear"
    };

    private ListView listView;
    private ArrayAdapter<String> adapter;
    private EditText searchEditText;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setTitle("LogCat - Lua");

        listView = new ListView(this);
        listView.setFastScrollEnabled(true);
        listView.setTextFilterEnabled(true);

        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, new ArrayList<String>());
        listView.setAdapter(adapter);

        setContentView(listView);
        loadLogcat("Lua", "lua:* *:S");
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuItem searchItem = menu.add("Search");
        searchItem.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
        searchEditText = new EditText(this);
        searchEditText.setHint("Enter keyword");
        searchEditText.setSingleLine(true);
        searchEditText.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                if (adapter != null) {
                    adapter.getFilter().filter(s);
                }
            }

            @Override
            public void afterTextChanged(Editable s) {
            }
        });
        searchItem.setActionView(searchEditText);

        for (String item : MENU_ITEMS) {
            menu.add(item);
        }

        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        String title = String.valueOf(item.getTitle());
        if ("Clear".equals(title)) {
            new ClearLogTask().execute();
            return true;
        }

        String filter;
        switch (title) {
            case "All":
                filter = "";
                break;
            case "Lua":
                filter = "lua:* *:S";
                break;
            case "Test":
                filter = "test:* *:S";
                break;
            case "Tcc":
                filter = "tcc:* *:S";
                break;
            case "Error":
                filter = "*:E";
                break;
            case "Warning":
                filter = "*:W";
                break;
            case "Info":
                filter = "*:I";
                break;
            case "Debug":
                filter = "*:D";
                break;
            case "Verbose":
                filter = "*:V";
                break;
            default:
                return super.onOptionsItemSelected(item);
        }

        loadLogcat(title, filter);
        return true;
    }

    private void loadLogcat(String label, String filter) {
        setTitle("LogCat - " + label);
        new ReadLogTask().execute(filter);
    }

    private static String runCommand(String command) {
        StringBuilder output = new StringBuilder();
        BufferedReader reader = null;
        try {
            Process process = Runtime.getRuntime().exec(new String[]{"sh", "-c", command});
            reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append('\n');
            }
            process.waitFor();
        } catch (Exception ignored) {
        } finally {
            try {
                if (reader != null) {
                    reader.close();
                }
            } catch (Exception ignored) {
            }
        }
        return output.toString();
    }

    private static List<String> splitLogChunks(String content) {
        ArrayList<String> chunks = new ArrayList<>();
        String[] lines = content.split("\\n");
        StringBuilder current = new StringBuilder();

        for (String line : lines) {
            if (line.startsWith("[") && current.length() > 0) {
                chunks.add(current.toString());
                current.setLength(0);
            }
            current.append(line).append('\n');
        }

        if (current.length() > 0) {
            chunks.add(current.toString());
        }

        if (chunks.isEmpty()) {
            chunks.add("<run the app to see its log output>");
        }

        return chunks;
    }

    private class ReadLogTask extends AsyncTask<String, Void, List<String>> {
        @Override
        protected List<String> doInBackground(String... params) {
            String filter = params != null && params.length > 0 ? params[0] : "";
            String command = "logcat -d -v long " + filter;
            String raw = runCommand(command).replaceAll("-+ beginning of[^\\n]*\\n", "");
            return splitLogChunks(raw);
        }

        @Override
        protected void onPostExecute(List<String> lines) {
            adapter.clear();
            adapter.addAll(lines);
            adapter.notifyDataSetChanged();
        }
    }

    private class ClearLogTask extends AsyncTask<Void, Void, Boolean> {
        @Override
        protected Boolean doInBackground(Void... params) {
            runCommand("logcat -c");
            return true;
        }

        @Override
        protected void onPostExecute(Boolean success) {
            Toast.makeText(LogcatActivity.this, "Logcat cleared", Toast.LENGTH_SHORT).show();
            loadLogcat("All", "");
        }
    }
}
