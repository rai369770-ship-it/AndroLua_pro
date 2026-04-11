package com.androlua;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class MoreOptions {

    public static final class Option {
        public final String title;
        public final Class<?> activityClass;

        public Option(String title, Class<?> activityClass) {
            this.title = title;
            this.activityClass = activityClass;
        }
    }

    private MoreOptions() {
    }

    public static List<Option> create() {
        List<Option> options = new ArrayList<>();
        options.add(new Option("More", MoreActivity.class));
        options.add(new Option("Open", OpenActivity.class));
        options.add(new Option("About", AboutActivity.class));
        options.add(new Option("Recent", RecentActivity.class));
        options.add(new Option("Save", SaveActivity.class));
        options.add(new Option("Files", FileActivity.class));
        options.add(new Option("New", NewActivity.class));
        options.add(new Option("Run", RunActivity.class));
        options.add(new Option("Compile", CompileActivity.class));
        options.add(new Option("Check Errors", CheckErrorsActivity.class));
        options.add(new Option("Project", ProjectActivity.class));
        options.add(new Option("Build", BuildActivity.class));
        options.add(new Option("Dialogs", DialogsActivity.class));
        options.add(new Option("Share", ShareActivity.class));
        options.add(new Option("Layout", LayoutActivity.class));
        options.add(new Option("UI", UiActivity.class));
        options.add(new Option("Java Browser", JavaBrowserActivity.class));
        options.add(new Option("LogCat", LogcatActivity.class));
        return Collections.unmodifiableList(options);
    }
}
