package com.androlua;

import com.luajava.LuaException;
import com.luajava.LuaState;
import com.luajava.LuaStateFactory;

import java.io.File;
import java.io.FileOutputStream;

public class LuaExecutionBridge {

    public static String checkSyntax(String source, boolean wrapAsReturn) {
        LuaState state = LuaStateFactory.newLuaState();
        try {
            String code = source == null ? "" : source;
            if (wrapAsReturn) {
                code = "return " + code;
            }

            int error = state.LloadBuffer(code.getBytes(), "editor");
            if (error == 0) {
                return null;
            }
            return state.toString(-1);
        } finally {
            state.close();
        }
    }

    public static String compileFile(String sourcePath) throws Exception {
        if (sourcePath == null) {
            throw new LuaException("sourcePath is null");
        }

        LuaState state = LuaStateFactory.newLuaState();
        try {
            int loadStatus = state.LloadFile(sourcePath);
            if (loadStatus != 0) {
                throw new LuaException(state.toString(-1));
            }

            byte[] dumped = state.dump(-1);
            String outputPath = sourcePath + "c";
            File outputFile = new File(outputPath);
            FileOutputStream fos = new FileOutputStream(outputFile);
            try {
                fos.write(dumped);
            } finally {
                fos.close();
            }
            return outputPath;
        } finally {
            state.close();
        }
    }
}
