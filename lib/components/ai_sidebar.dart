import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'ai_sidebar_web.dart' if (dart.library.io) 'ai_sidebar_mobile.dart';
import 'ai_sidebar_windows.dart';

class AISidebar extends StatefulWidget {
  final String noteContent;
  final bool isExpanded;
  final VoidCallback onToggle;
  final double width;
  final bool hideWebView;

  const AISidebar({
    super.key,
    required this.noteContent,
    required this.isExpanded,
    required this.onToggle,
    this.width = 400,
    this.hideWebView = false,
  });

  @override
  State<AISidebar> createState() => AISidebarState();
}

class AISidebarState extends State<AISidebar> {
  final GlobalKey<AISidebarWindowsState> _windowsKey = GlobalKey<AISidebarWindowsState>();

  // 发送消息到 AI
  Future<void> sendMessageToAI(String message) async {
    if (!kIsWeb && Platform.isWindows) {
      await _windowsKey.currentState?.sendMessageToAI(message);
    }
  }

  // 获取 AI 的最新回复
  Future<String?> getLatestResponse() async {
    if (!kIsWeb && Platform.isWindows) {
      return await _windowsKey.currentState?.getLatestResponse();
    }
    return null;
  }

  // 学习模式：让 AI 学习笔记内容
  Future<void> learnMode(String noteContent) async {
    if (!kIsWeb && Platform.isWindows) {
      await _windowsKey.currentState?.learnMode(noteContent);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Windows 桌面端使用 webview_windows
    if (!kIsWeb && Platform.isWindows) {
      return AISidebarWindows(
        key: _windowsKey,
        noteContent: widget.noteContent,
        isExpanded: widget.isExpanded,
        onToggle: widget.onToggle,
        width: widget.width,
        hideWebView: widget.hideWebView,
      );
    }
    
    // Web 端和其他移动端使用条件导入
    return AISidebarImpl(
      noteContent: widget.noteContent,
      isExpanded: widget.isExpanded,
      onToggle: widget.onToggle,
      width: widget.width,
    );
  }
}
