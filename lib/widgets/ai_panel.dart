import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// 只在 Web 端导入 dart:html
import 'ai_panel_web.dart' if (dart.library.io) 'ai_panel_stub.dart';

class AIPanel extends StatefulWidget {
  final String noteContent;
  final bool isExpanded;
  final VoidCallback onToggle;

  const AIPanel({
    super.key,
    required this.noteContent,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<AIPanel> createState() => _AIPanelState();
}

class _AIPanelState extends State<AIPanel> {
  @override
  Widget build(BuildContext context) {
    // 如果不是 Web 平台，显示提示
    if (!kIsWeb) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: widget.isExpanded ? 400 : 48,
        child: Row(
          children: [
            Container(
              width: 48,
              color: Colors.grey[200],
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      widget.isExpanded
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                    ),
                    onPressed: widget.onToggle,
                  ),
                  const Icon(Icons.smart_toy),
                ],
              ),
            ),
            if (widget.isExpanded)
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: const Center(
                    child: Text('AI 面板仅在 Web 端可用'),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Web 端使用实际实现
    return AIPanelWeb(
      noteContent: widget.noteContent,
      isExpanded: widget.isExpanded,
      onToggle: widget.onToggle,
    );
  }
}
