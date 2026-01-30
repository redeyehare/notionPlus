import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  late final WebViewController _controller;
  String _currentUrl = 'https://chat.openai.com';
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = true;
  String _selectedAI = 'ChatGPT';

  final Map<String, String> _aiUrls = {
    'ChatGPT': 'https://chat.openai.com',
    'Claude': 'https://claude.ai',
    'Gemini': 'https://gemini.google.com',
    'Copilot': 'https://copilot.microsoft.com',
    'Perplexity': 'https://www.perplexity.ai',
    '自定义': '',
  };

  @override
  void initState() {
    super.initState();
    _urlController.text = _currentUrl;
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
              _urlController.text = url;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  void _loadUrl(String url) {
    if (url.isNotEmpty) {
      setState(() {
        _currentUrl = url;
        _isLoading = true;
      });
      _controller.loadRequest(Uri.parse(url));
    }
  }

  Future<void> _sendNoteToAI() async {
    if (widget.noteContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记内容为空')),
      );
      return;
    }

    // 尝试自动注入到输入框
    String script = '''
      (function() {
        const inputs = document.querySelectorAll('textarea, input[type="text"], [contenteditable="true"]');
        for (let input of inputs) {
          if (input.offsetParent !== null && 
              (input.placeholder?.toLowerCase().includes('message') ||
               input.placeholder?.toLowerCase().includes('ask') ||
               input.getAttribute('aria-label')?.toLowerCase().includes('message'))) {
            input.focus();
            input.value = `基于以下笔记内容，请帮我分析和解答：\\n\\n${widget.noteContent.replaceAll("'", "\\'").replaceAll("\\n", "\\n")}`;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          }
        }
        return false;
      })();
    ''';

    _controller.runJavaScript(script).catchError((e) {
      debugPrint('自动注入失败: $e');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已尝试自动填充到 AI 输入框'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSendOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '发送笔记到 AI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: const Text('自动发送'),
              subtitle: const Text('尝试自动填充到 AI 输入框'),
              onTap: () {
                Navigator.pop(context);
                _sendNoteToAI();
              },
            ),
          ],
        ),
      ),
    );
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
                    widget.isExpanded ? Icons.chevron_right : Icons.chevron_left,
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
                    icon: const Icon(Icons.send),
                    onPressed: _showSendOptions,
                    tooltip: '发送笔记到 AI',
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
                      height: 48,
                      color: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          // AI 选择下拉菜单
                          DropdownButton<String>(
                            value: _selectedAI,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            items: _aiUrls.keys.map((String ai) {
                              return DropdownMenuItem<String>(
                                value: ai,
                                child: Text(ai, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedAI = newValue;
                                });
                                if (newValue != '自定义') {
                                  _loadUrl(_aiUrls[newValue]!);
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          // 刷新按钮
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: () => _loadUrl(_currentUrl),
                            tooltip: '刷新',
                          ),
                        ],
                      ),
                    ),
                    // URL 输入框（自定义时使用）
                    if (_selectedAI == '自定义')
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                decoration: const InputDecoration(
                                  hintText: '输入 AI 网址',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                onSubmitted: _loadUrl,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              onPressed: () => _loadUrl(_urlController.text),
                            ),
                          ],
                        ),
                      ),
                    // WebView
                    Expanded(
                      child: Stack(
                        children: [
                          WebViewWidget(controller: _controller),
                          if (_isLoading)
                            Container(
                              color: Colors.white,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // 底部提示
                    Container(
                      height: 32,
                      color: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '当前: $_selectedAI | 点击发送按钮携带笔记',
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
