import 'package:flutter/material.dart';

// 非 Web 平台的占位实现
class AIPanelWeb extends StatelessWidget {
  final String noteContent;
  final bool isExpanded;
  final VoidCallback onToggle;

  const AIPanelWeb({
    super.key,
    required this.noteContent,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isExpanded ? 400 : 48,
      child: Row(
        children: [
          Container(
            width: 48,
            color: Colors.grey[200],
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.chevron_right : Icons.chevron_left,
                  ),
                  onPressed: onToggle,
                ),
                const Icon(Icons.smart_toy),
              ],
            ),
          ),
          if (isExpanded)
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
}
