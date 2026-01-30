import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

class AIPanelWeb extends StatefulWidget {
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
  State<AIPanelWeb> createState() => _AIPanelWebState();
}

class _AIPanelWebState extends State<AIPanelWeb> {
  static const String _viewType = 'ai-web-view';
  html.IFrameElement? _iframeElement;
  String _currentUrl = 'https://chat.openai.com';

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
  }

  void _registerViewFactory() {
    // 避免重复注册
    try {
      ui.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) {
          _iframeElement = html.IFrameElement()
            ..src = _currentUrl
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
          return _iframeElement!;
        },
      );
    } catch (e) {
      // 已经注册过了，忽略错误
    }
  }

  @override
  void didUpdateWidget(covariant AIPanelWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当笔记内容变化时，通过 postMessage 发送给 iframe
    if (widget.noteContent != oldWidget.noteContent && _iframeElement != null) {
      _sendNoteToAI();
    }
  }

  void _sendNoteToAI() {
    if (_iframeElement != null && widget.noteContent.isNotEmpty) {
      // 通过 postMessage 与 iframe 通信
      _iframeElement!.contentWindow?.postMessage(
        {
          'type': 'notion_note',
          'content': widget.noteContent,
          'timestamp': DateTime.now().toIso8601String(),
        },
        '*', // 目标域名，生产环境应该指定具体域名
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: widget.isExpanded ? 400 : 48,
      child: Row(
        children: [
          // 展开/收起按钮
          Container(
            width: 48,
            color: Colors.grey[200],
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    widget.isExpanded ? Icons.chevron_right : Icons.chevron_left,
                  ),
                  onPressed: widget.onToggle,
                  tooltip: widget.isExpanded ? '收起面板' : '展开面板',
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
                    icon: const Icon(Icons.send),
                    onPressed: _sendNoteToAI,
                    tooltip: '发送笔记给AI',
                  ),
                ],
              ],
            ),
          ),
          // WebView 内容区域
          if (widget.isExpanded)
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    // 顶部工具栏
                    Container(
                      height: 40,
                      color: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Text(
                            'AI 助手',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          // AI 服务切换下拉菜单
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (value) {
                              // 切换 AI 服务
                              _switchAIService(value);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'chatgpt',
                                child: Text('ChatGPT'),
                              ),
                              const PopupMenuItem(
                                value: 'claude',
                                child: Text('Claude'),
                              ),
                              const PopupMenuItem(
                                value: 'gemini',
                                child: Text('Gemini'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // WebView
                    Expanded(
                      child: HtmlElementView(
                        viewType: _viewType,
                      ),
                    ),
                    // 底部提示
                    Container(
                      height: 30,
                      color: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 14),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '点击发送按钮可将笔记内容传给AI',
                              style: TextStyle(fontSize: 11),
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

  void _switchAIService(String service) {
    String url;
    switch (service) {
      case 'chatgpt':
        url = 'https://chat.openai.com';
        break;
      case 'claude':
        url = 'https://claude.ai';
        break;
      case 'gemini':
        url = 'https://gemini.google.com';
        break;
      default:
        url = 'https://chat.openai.com';
    }

    if (_iframeElement != null) {
      setState(() {
        _currentUrl = url;
        _iframeElement!.src = url;
      });
    }
  }
}
