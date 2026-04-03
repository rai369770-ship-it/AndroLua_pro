layout={
  main={
    LinearLayout,
    layout_width="fill",
    layout_height="fill",
    orientation="vertical";
    {
      LuaEditor,
      id="editor",
      text= "",
      layout_width="fill",
      layout_height="fill",
      layout_weight=1 ,
      --gravity="top"
    },
    {
      HorizontalScrollView;
      horizontalScrollBarEnabled=false,
      {
        LinearLayout;
        id="ps_bar";
        layout_width="fill";
      };
      layout_width="fill";
    };
  },

  build={
    ScrollView ,
    layout_width="fill",
    {
      LinearLayout,
      orientation=1,
      layout_width="fill",
      paddingLeft=20,
      {
        TextView,
        text="Script path"
      },
      {
        androidx.appcompat.widget.AppCompatEditText,
        id="luaPath",
        layout_width="fill",
        singleLine=true,
      },
      {
        TextView,
        text="Package name"
      },
      {
        androidx.appcompat.widget.AppCompatEditText,
        id="packageName",
        layout_width="fill",
        singleLine=true,
      },
      {
        TextView,
        text="App name"
      },
      {
        androidx.appcompat.widget.AppCompatEditText,
        id="appName",
        layout_width="fill",
        singleLine=true,
      },
      {
        TextView,
        text="App version"
      },
      {
        androidx.appcompat.widget.AppCompatEditText,
        id="appVer",
        layout_width="fill",
        singleLine=true,
      },
      {
        TextView,
        text="APK path"
      },
      {
        androidx.appcompat.widget.AppCompatEditText,
        id="apkPath",
        layout_width="fill",
        singleLine=true,
      },
      {
        TextView,
        text="Debug signing for package build",
        id="status"
      },
    }
  },

  project={
    ScrollView ,
    layout_width="fill",
    {
      LinearLayout,
      orientation=1,
      layout_width="fill",
      padding="10dp",
      {
        TextView,
        text="App name"
      },
      {
        androidx.appcompat.widget.AppCompatEditText,
        id="project_appName",
        text="demo",
        layout_width="fill",
        singleLine=true,
      },
      {
        TextView,
        text="Package name"
      },
      {
        androidx.appcompat.widget.AppCompatEditText,
        id="project_packageName",
        text="com.androlua.demo",
        layout_width="fill",
        singleLine=true,
      },
    }
  },
  open2={
    LinearLayout;
    orientation="vertical";
    {
      androidx.appcompat.widget.AppCompatEditText;
      layout_width="fill";
      id="open_edit";
    };
    {
      ListView;
      layout_width="fill";
      id="listview2";
    };
  };


}
