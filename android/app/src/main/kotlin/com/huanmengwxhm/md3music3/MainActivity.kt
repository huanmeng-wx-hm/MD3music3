package com.huanmengwxhm.md3music3

import io.flutter.embedding.android.FlutterActivity

/// 空 FlutterActivity 就够：Rust 服务走 dart:ffi 直接 dlopen
/// libkugou_server.so（已放 jniLibs），不需要任何 MethodChannel 注册。
class MainActivity : FlutterActivity()
