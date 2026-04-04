LOCAL_PATH := $(call my-dir)

# Build every module that declares its own Android.mk under app/src/main/jni/*.
include $(call all-subdir-makefiles)
