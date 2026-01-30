import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:js' as js;

class AISidebarImpl extends StatefulWidget {
  final String noteContent;
  final bool isExpanded;
  final VoidCallback onToggle;
  final double width;

  const AISidebarImpl({
    super.key,
    required this.noteContent,
    required this.isExpanded,
    required this.onToggle,
    required this.width,
  });

  @override
  State<AISidebarImpl> createState() => _AISidebarImplState();
}

class _AISidebarImplState extends State<AISidebarImpl> {
  String _selectedAI = 'ChatGPT';

  final Map<String, String> _aiUrls = {
    'ChatGPT': 'https://chat.openai.com',
    'Claude': 'https://claude.ai',
    'Gemini': 'https://gemini.google.com',
    'Copilot': 'https://copilot.microsoft.com',
    'Perplexity': 'https://www.perplexity.ai',
  };

  Future<void> _copyToClipboard(String text) async {
    final clipboard = js.context['navigator']['clipboard'];
    if (clipboard != null) {
      clipboard.callMethod('writeText', [text]);
    } else {
      final textarea =
          html.document.createElement('textarea') as html.TextAreaElement;
      textarea.value = text;
      textarea.style.position = 'absolute';
      textarea.style.left = '-9999px';
      html.document.body?.append(textarea);
      textarea.select();
      html.document.execCommand('copy');
      textarea.remove();
    }
  }

  void _openAIWithNote() async {
    if (widget.noteContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记内容为空')),
      );
      return;
    }

    // 构建带笔记内容的消息
    final message = '''基于以下笔记内容，请帮我分析和解答：

${widget.noteContent}

我的问题是：''';

    // 复制到剪贴板
    await _copyToClipboard(message);

    // 获取 AI 网址
    final url = _aiUrls[_selectedAI] ?? 'https://chat.openai.com';

    // 在新标签页打开 AI 网站
    html.window.open(url, '_blank');

    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制笔记内容并打开 $_selectedAI'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '知道了',
          onPressed: () {},
        ),
      ),
    );
  }

  void _openAIOnly() {
    final url = _aiUrls[_selectedAI] ?? 'https://chat.openai.com';
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: widget.isExpanded ? widget.width : 48,
      child: Row(
        children: [
          // 侧边栏控制按钮
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
                  tooltip: widget.isExpanded ? '收起' : '展开 AI 助手',
                ),
                const Divider(height: 1),
                IconButton(
                  icon: const Icon(Icons.smart_toy),
                  onPressed: widget.onToggle,
                  tooltip: 'AI 助手',
                ),
                if (widget.isExpanded) ...[
                  const Divider(height: 1),
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: _openAIWithNote,
                    tooltip: '携带笔记打开 AI',
                  ),
                ],
              ],
            ),
          ),
          // 内容区域
          if (widget.isExpanded)
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    // 顶部工具栏
                    Container(
                      height: 48,
                      color: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Text(
                            'AI 助手',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          // AI 选择下拉菜单
                          DropdownButton<String>(
                            value: _selectedAI,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            items: _aiUrls.keys.map((String ai) {
                              return DropdownMenuItem<String>(
                                value: ai,
                                child: Text(ai,
                                    style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedAI = newValue;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    // 主要内容区域
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.smart_toy,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedAI,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '点击按钮在新标签页打开 AI',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 打开 AI 按钮
                            ElevatedButton.icon(
                              onPressed: _openAIWithNote,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('携带笔记打开 AI'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 仅打开 AI 按钮
                            TextButton.icon(
                              onPressed: _openAIOnly,
                              icon: const Icon(Icons.launch),
                              label: const Text('仅打开 AI'),
                            ),
                            const SizedBox(height: 24),
                            // 说明文字
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '使用说明',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '1. 点击"携带笔记打开 AI"按钮\n'
                                    '2. 笔记内容会自动复制到剪贴板\n'
                                    '3. 在新标签页粘贴即可提问',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 底部状态栏
                    Container(
                      height: 32,
                      color: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 14, color: Colors.green[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '当前选择: $_selectedAI',
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
