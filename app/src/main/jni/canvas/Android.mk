LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_C_INCLUDES += $(LOCAL_PATH)/../lua
LOCAL_MODULE     := canvas
LOCAL_SRC_FILES  := canvas.c
LOCAL_SHARED_LIBRARIES := luajava

include $(BUILD_SHARED_LIBRARY)
