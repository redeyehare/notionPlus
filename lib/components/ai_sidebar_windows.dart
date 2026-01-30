import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:io';

class AISidebarWindows extends StatefulWidget {
  final String noteContent;
  final bool isExpanded;
  final VoidCallback onToggle;
  final double width;
  final bool hideWebView;

  const AISidebarWindows({
    super.key,
    required this.noteContent,
    required this.isExpanded,
    required this.onToggle,
    this.width = 450,
    this.hideWebView = false,
  });

  @override
  State<AISidebarWindows> createState() => AISidebarWindowsState();
}

class AISidebarWindowsState extends State<AISidebarWindows> {
  final WebviewController _controller = WebviewController();
  String _currentUrl = 'https://chat.openai.com';
  String _selectedAI = 'ChatGPT';
  bool _isLoading = true;
  bool _isControllerInitialized = false;
  bool _autoAttachMode = false; // 自动跟随模式

  final Map<String, String> _aiUrls = {
    'ChatGPT': 'https://chat.openai.com',
    'Claude': 'https://claude.ai',
    'Gemini': 'https://gemini.google.com',
    'Kimi': 'https://chat.z.ai',
    'Copilot': 'https://copilot.microsoft.com',
    'Perplexity': 'https://www.perplexity.ai',
  };

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    await _controller.initialize();
    _controller.loadingState.listen((state) {
      setState(() {
        _isLoading = state == LoadingState.loading;
      });

      // 页面加载完成后，如果自动跟随模式开启，注入脚本
      if (state == LoadingState.navigationCompleted && _autoAttachMode) {
        _injectAutoAttachScript();
      }
    });

    await _controller.setBackgroundColor(Colors.transparent);
    await _controller.loadUrl(_currentUrl);

    setState(() {
      _isControllerInitialized = true;
    });
  }

  Future<void> _loadUrl(String url) async {
    if (url.isNotEmpty) {
      setState(() {
        _currentUrl = url;
        _isLoading = true;
      });
      await _controller.loadUrl(url);
    }
  }

  Future<void> _toggleAutoAttachMode() async {
    setState(() {
      _autoAttachMode = !_autoAttachMode;
    });

    if (_autoAttachMode) {
      // 启用自动跟随模式，注入监听脚本
      await _injectAutoAttachScript();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('自动跟随模式已开启，点击 Gemini 发送按钮时会自动带上笔记内容'),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('自动跟随模式已关闭'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _injectAutoAttachScript() async {
    if (!_autoAttachMode || widget.noteContent.isEmpty) return;

    final script = '''
      (function() {
        // 如果已经注入过，不要重复注入
        if (window._notionNotesAutoAttach) return 'already injected';
        window._notionNotesAutoAttach = true;
        
        // 笔记内容
        const noteContent = `${widget.noteContent.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
        
        // 监听所有按钮点击
        document.addEventListener('click', function(e) {
          const target = e.target;
          
          // 检查是否点击了发送按钮
          const isSendButton = target.tagName === 'BUTTON' && (
            target.getAttribute('aria-label')?.includes('发送') ||
            target.getAttribute('aria-label')?.includes('Send') ||
            target.classList.contains('send-button') ||
            target.closest('button[aria-label*="发送"]') ||
            target.closest('button[aria-label*="Send"]')
          );
          
          if (isSendButton) {
            console.log('Send button clicked, auto-attaching note content...');
            
            // 查找输入框
            const input = document.querySelector('.ql-editor') ||
                         document.querySelector('[contenteditable="true"]');
            
            if (input && input.textContent.trim().length === 0) {
              // 输入框为空，自动填充笔记内容
              input.textContent = '';
              const lines = noteContent.split('\\n');
              for (let i = 0; i < lines.length; i++) {
                const p = document.createElement('p');
                p.textContent = lines[i];
                input.appendChild(p);
              }
              
              // 触发事件
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.focus();
              
              console.log('Note content auto-attached!');
            }
          }
        }, true);
        
        return 'injected';
      })();
    ''';

    try {
      final result = await _controller.executeScript(script);
      print('Auto-attach script result: $result');
    } catch (e) {
      print('Failed to inject auto-attach script: $e');
    }
  }

  Future<void> _copyToClipboard(String text) async {
    // 使用 WebView 执行 JavaScript 复制到剪贴板
    final script = '''
      (function() {
        const textarea = document.createElement('textarea');
        textarea.value = `${text.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
        textarea.style.position = 'fixed';
        textarea.style.left = '-9999px';
        document.body.appendChild(textarea);
        textarea.select();
        const result = document.execCommand('copy');
        document.body.removeChild(textarea);
        return result ? 'copied' : 'failed';
      })();
    ''';
    try {
      final result = await _controller.executeScript(script);
      print('Copy result: $result');
    } catch (e) {
      print('Copy failed: $e');
    }
  }

  Future<void> _sendNoteToAI() async {
    print('=== _sendNoteToAI called ===');
    print('noteContent length: ${widget.noteContent.length}');
    print(
        'noteContent preview: ${widget.noteContent.substring(0, widget.noteContent.length > 50 ? 50 : widget.noteContent.length)}...');

    if (widget.noteContent.isEmpty) {
      print('ERROR: noteContent is empty!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记内容为空')),
      );
      return;
    }

    // 构建带笔记内容的消息
    final message = '''基于以下笔记内容，请帮我分析和解答：

${widget.noteContent}

我的问题是：''';

    print(
        'Message to inject: ${message.substring(0, message.length > 100 ? 100 : message.length)}...');

    // 针对不同 AI 网站的注入脚本
    String script = '';

    switch (_selectedAI) {
      case 'ChatGPT':
        script = '''
          (function() {
            // 先尝试找到所有可能的输入框
            const allTextareas = document.querySelectorAll('textarea');
            const allContentEditables = document.querySelectorAll('[contenteditable="true"]');
            
            console.log('Found textareas:', allTextareas.length);
            console.log('Found contenteditables:', allContentEditables.length);
            
            // 尝试多种选择器找到 ChatGPT 输入框
            const selectors = [
              '#prompt-textarea',
              'textarea[data-id]',
              'textarea[placeholder*="Message"]',
              'textarea[placeholder*="Send a message"]',
              'div[contenteditable="true"]',
              'textarea'
            ];
            
            for (let selector of selectors) {
              const input = document.querySelector(selector);
              console.log('Trying selector:', selector, 'Found:', input ? 'yes' : 'no');
              
              if (input && input.offsetParent !== null) {
                const text = `${message.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
                
                // 尝试多种方式填充
                try {
                  if (input.tagName === 'TEXTAREA' || input.tagName === 'INPUT') {
                    input.value = text;
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                    input.dispatchEvent(new Event('change', { bubbles: true }));
                  } else if (input.contentEditable === 'true') {
                    input.innerHTML = text.replaceAll('\\n', '<br>');
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                  }
                  
                  input.focus();
                  console.log('Successfully filled input');
                  return 'success';
                } catch(e) {
                  console.error('Error filling input:', e);
                }
              }
            }
            
            // 如果没找到，尝试通过 data-testid 或其他属性
            const editorDiv = document.querySelector('[data-testid="text-input"]') ||
                              document.querySelector('.ProseMirror') ||
                              document.querySelector('[role="textbox"]');
            if (editorDiv) {
              const text = `${message.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
              editorDiv.innerHTML = '<p>' + text.replaceAll('\\n', '</p><p>') + '</p>';
              editorDiv.dispatchEvent(new Event('input', { bubbles: true }));
              editorDiv.focus();
              return 'success-editor';
            }
            
            return 'not found';
          })();
        ''';
        break;

      case 'Gemini':
        script = '''
          (function() {
            let debugInfo = [];
            debugInfo.push('=== Gemini Inject Debug ===');
            debugInfo.push('readyState: ' + document.readyState);
            debugInfo.push('body exists: ' + !!document.body);
            debugInfo.push('URL: ' + document.URL);
            
            // 等待页面加载完成
            if (document.readyState !== 'complete' && document.readyState !== 'interactive') {
              return 'page not ready: ' + document.readyState;
            }
            
            // 先检查是否能找到任何元素
            const allDivs = document.querySelectorAll('div');
            const allTextareas = document.querySelectorAll('textarea');
            const allRichTextareas = document.querySelectorAll('rich-textarea');
            debugInfo.push('divs: ' + allDivs.length);
            debugInfo.push('textareas: ' + allTextareas.length);
            debugInfo.push('rich-textareas: ' + allRichTextareas.length);
            
            // 打印 body 的前几个子元素
            if (document.body && document.body.children.length > 0) {
              debugInfo.push('body first child: ' + document.body.children[0].tagName);
              debugInfo.push('body children: ' + document.body.children.length);
            } else {
              debugInfo.push('no body children');
            }
            
            // 尝试直接通过 tag name 找 rich-textarea
            const richTextareaByTag = document.getElementsByTagName('rich-textarea');
            debugInfo.push('rich-textarea by tag: ' + richTextareaByTag.length);
            
            // 根据用户提供的 HTML 结构，优先尝试这些选择器
            const selectors = [
              'rich-textarea',
              'rich-textarea .ql-editor',
              '.ql-editor.text-area.new-input-ui',
              '.ql-editor[contenteditable="true"]',
              '[role="textbox"][contenteditable="true"]',
              '.ql-editor',
              'div[contenteditable="true"]'
            ];
            
            for (let selector of selectors) {
              let input = document.querySelector(selector);
              debugInfo.push(selector + ': ' + (input ? 'found' : 'not found') + ' tag=' + (input ? input.tagName : 'none'));
              
              // 如果是 rich-textarea，找里面的 .ql-editor
              if (input && input.tagName.toLowerCase() === 'rich-textarea') {
                debugInfo.push('found rich-textarea');
                const editor = input.querySelector('.ql-editor');
                if (editor) {
                  input = editor;
                  debugInfo.push('found .ql-editor inside');
                } else {
                  debugInfo.push('no .ql-editor inside');
                }
              }
              
              if (input && input.offsetParent !== null) {
                debugInfo.push('input visible, editable=' + input.contentEditable + ' class=' + input.classList.toString());
                
                const text = `${message.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
                
                try {
                  // Gemini 使用 contenteditable div
                  if (input.contentEditable === 'true' || input.classList.contains('ql-editor')) {
                    // 清空现有内容
                    input.textContent = '';
                    
                    // 使用 createElement 创建段落（绕过 TrustedHTML 限制）
                    const lines = text.split('\\n');
                    for (let i = 0; i < lines.length; i++) {
                      const p = document.createElement('p');
                      p.textContent = lines[i];
                      input.appendChild(p);
                    }
                    
                    // 触发多种事件确保 Gemini 识别到输入
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                    input.dispatchEvent(new Event('change', { bubbles: true }));
                    input.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true }));
                    input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
                    
                    // 设置光标到末尾
                    const range = document.createRange();
                    const sel = window.getSelection();
                    range.selectNodeContents(input);
                    range.collapse(false);
                    sel.removeAllRanges();
                    sel.addRange(range);
                    
                    input.focus();
                    
                    debugInfo.push('SUCCESS with ' + selector);
                    return debugInfo.join(' | ');
                  }
                  
                  input.focus();
                } catch(e) {
                  debugInfo.push('Error: ' + e.message);
                }
              }
            }
            
            debugInfo.push('FAILED: not found');
            return debugInfo.join(' | ');
          })();
        ''';
        break;

      case 'Claude':
        script = '''
          (function() {
            const input = document.querySelector('div[contenteditable="true"]') || 
                         document.querySelector('textarea');
            if (input) {
              const text = `${message.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
              if (input.contentEditable === 'true') {
                input.innerHTML = text.replaceAll('\\n', '<br>');
              } else {
                input.value = text;
              }
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.focus();
              return 'success';
            }
            return 'not found';
          })();
        ''';
        break;

      default:
        script = '''
          (function() {
            const inputs = document.querySelectorAll('textarea, input[type="text"], [contenteditable="true"]');
            for (let input of inputs) {
              if (input.offsetParent !== null) {
                const text = `${message.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
                if (input.tagName === 'TEXTAREA' || input.tagName === 'INPUT') {
                  input.value = text;
                  input.dispatchEvent(new Event('input', { bubbles: true }));
                } else {
                  input.innerHTML = text.replaceAll('\\n', '<br>');
                  input.dispatchEvent(new Event('input', { bubbles: true }));
                }
                input.focus();
                return 'success';
              }
            }
            return 'not found';
          })();
        ''';
    }

    try {
      final result = await _controller.executeScript(script);
      print('注入结果: $result');

      // 检查结果是否包含 SUCCESS，且不包含 FAILED
      if (result != null &&
          result.toString().contains('SUCCESS') &&
          !result.toString().contains('FAILED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('笔记内容已自动填充到 $_selectedAI'),
            duration: const Duration(seconds: 2),
          ),
        );
        // 填充成功后，延迟一下再发送，确保内容渲染完成
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        // 自动填充失败，复制到剪贴板
        await _copyToClipboard(message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已复制笔记内容到剪贴板，请手动粘贴'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '知道了',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      print('注入失败: $e');
      // 出错时也复制到剪贴板
      await _copyToClipboard(message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('自动填充失败，已复制到剪贴板'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _learnMode() async {
    if (widget.noteContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记内容为空')),
      );
      return;
    }

    // 构建学习模式的消息
    final learnMessage = '''请学习以下笔记内容，不需要回答。后续对话请基于这些内容展开：

${widget.noteContent}

[系统提示：已进入学习模式，请记忆以上内容]''';

    // 针对不同 AI 网站的注入脚本
    String script = '';

    switch (_selectedAI) {
      case 'Gemini':
        script = '''
          (function() {
            const learnMessage = `${learnMessage.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
            
            // 查找输入框
            const input = document.querySelector('.ql-editor') ||
                         document.querySelector('[contenteditable="true"]');
            
            if (input && input.offsetParent !== null) {
              // 清空并填充学习消息
              input.textContent = '';
              const lines = learnMessage.split('\\n');
              for (let i = 0; i < lines.length; i++) {
                const p = document.createElement('p');
                p.textContent = lines[i];
                input.appendChild(p);
              }
              
              // 触发输入事件
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.dispatchEvent(new Event('change', { bubbles: true }));
              input.focus();
              
              // 发送
              const sendButton = document.querySelector('button[aria-label*="发送"]') ||
                                 document.querySelector('button[aria-label*="Send"]') ||
                                 document.querySelector('rich-textarea + button');
              
              if (sendButton && !sendButton.disabled) {
                sendButton.click();
                return 'learn mode sent';
              }
            }
            
            return 'learn mode failed';
          })();
        ''';
        break;

      default:
        script = '''
          (function() {
            const learnMessage = `${learnMessage.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
            
            const input = document.querySelector('textarea, [contenteditable="true"]');
            if (input && input.offsetParent !== null) {
              if (input.tagName === 'TEXTAREA') {
                input.value = learnMessage;
              } else {
                input.textContent = '';
                const lines = learnMessage.split('\\n');
                for (let i = 0; i < lines.length; i++) {
                  const p = document.createElement('p');
                  p.textContent = lines[i];
                  input.appendChild(p);
                }
              }
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.focus();
              
              // 尝试发送
              const buttons = document.querySelectorAll('button');
              for (let btn of buttons) {
                if (btn.innerText.toLowerCase().includes('send') ||
                    btn.getAttribute('aria-label')?.toLowerCase().includes('send')) {
                  btn.click();
                  return 'learn mode sent';
                }
              }
            }
            
            return 'learn mode failed';
          })();
        ''';
    }

    try {
      final result = await _controller.executeScript(script);
      print('学习模式结果: $result');

      if (result != null && result.toString().contains('sent')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已进入学习模式，AI 正在学习笔记内容'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // 失败时复制到剪贴板
        await _copyToClipboard(learnMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('自动填充失败，已复制学习提示到剪贴板'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('学习模式失败: $e');
      await _copyToClipboard(learnMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('学习模式失败，已复制到剪贴板'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // 发送消息到 AI（从对话面板调用）
  Future<void> sendMessageToAI(String message) async {
    print('=== sendMessageToAI called ===');
    print('Message: $message');
    print('Selected AI: $_selectedAI');

    if (!_isControllerInitialized) {
      print('ERROR: Controller not initialized');
      return;
    }

    String script = '';

    switch (_selectedAI) {
      case 'Gemini':
        script = '''
          (function() {
            const message = `${message.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
            
            // 查找输入框
            const input = document.querySelector('.ql-editor') ||
                         document.querySelector('[contenteditable="true"]');
            
            if (input && input.offsetParent !== null) {
              // 填充消息
              input.textContent = '';
              const lines = message.split('\\n');
              for (let i = 0; i < lines.length; i++) {
                const p = document.createElement('p');
                p.textContent = lines[i];
                input.appendChild(p);
              }
              
              // 触发输入事件
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.dispatchEvent(new Event('change', { bubbles: true }));
              input.focus();
              
              // 发送
              setTimeout(() => {
                const sendButton = document.querySelector('button[aria-label*="发送"]') ||
                                   document.querySelector('button[aria-label*="Send"]') ||
                                   document.querySelector('rich-textarea + button');
                
                if (sendButton && !sendButton.disabled) {
                  sendButton.click();
                }
              }, 300);
              
              return 'message sent';
            }
            
            return 'input not found';
          })();
        ''';
        break;

      default:
        script = '''
          (function() {
            const message = `${message.replaceAll('`', '\\`').replaceAll('\n', '\\n')}`;
            
            const input = document.querySelector('textarea, [contenteditable="true"]');
            if (input && input.offsetParent !== null) {
              if (input.tagName === 'TEXTAREA') {
                input.value = message;
              } else {
                input.textContent = '';
                const lines = message.split('\\n');
                for (let i = 0; i < lines.length; i++) {
                  const p = document.createElement('p');
                  p.textContent = lines[i];
                  input.appendChild(p);
                }
              }
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.focus();
              
              // 尝试发送
              setTimeout(() => {
                const buttons = document.querySelectorAll('button');
                for (let btn of buttons) {
                  if (btn.innerText.toLowerCase().includes('send') ||
                      btn.getAttribute('aria-label')?.toLowerCase().includes('send')) {
                    btn.click();
                    break;
                  }
                }
              }, 300);
              
              return 'message sent';
            }
            
            return 'input not found';
          })();
        ''';
    }

    try {
      final result = await _controller.executeScript(script);
      print('Send message result: $result');
    } catch (e) {
      print('Send message failed: $e');
    }
  }

  // 获取 AI 的最新回复
  Future<String?> getLatestResponse() async {
    if (!_isControllerInitialized) return null;

    String script = '';

    switch (_selectedAI) {
      case 'Gemini':
        script = '''
          (function() {
            let debug = [];
            
            // 根据用户提供的截图，回复在 structured-content-container 里
            const containers = document.querySelectorAll('.structured-content-container');
            debug.push('structured-content-container count: ' + containers.length);
            
            if (containers.length > 0) {
              // 获取最后一个回复
              const lastContainer = containers[containers.length - 1];
              debug.push('found container, text length: ' + (lastContainer.textContent || '').length);
              
              // 提取所有文本内容
              const paragraphs = lastContainer.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li');
              debug.push('paragraphs count: ' + paragraphs.length);
              
              if (paragraphs.length > 0) {
                let text = '';
                paragraphs.forEach(p => {
                  if (p.textContent.trim()) {
                    text += p.textContent + '\\n';
                  }
                });
                debug.push('extracted text length: ' + text.length);
                return text.trim();
              }
              
              // 如果找不到段落，直接返回容器文本
              return lastContainer.textContent || lastContainer.innerText || '';
            }
            
            // 备选方案：查找所有 ql-editor（排除输入框）
            const editors = document.querySelectorAll('.ql-editor');
            debug.push('ql-editor count: ' + editors.length);
            
            for (let editor of editors) {
              const isInputArea = editor.getAttribute('contenteditable') === 'true' ||
                                  editor.classList.contains('new-input-ui');
              
              if (!isInputArea) {
                debug.push('found non-input ql-editor');
                return editor.textContent || editor.innerText || '';
              }
            }
            
            // 如果都没找到，返回调试信息
            return 'DEBUG: ' + debug.join(' | ');
          })();
        ''';
        break;

      default:
        script = '''
          (function() {
            // 通用方案：查找回复内容
            const responses = document.querySelectorAll('.message, .response, .reply, [class*="message"]');
            if (responses.length > 0) {
              const lastResponse = responses[responses.length - 1];
              return lastResponse.textContent || '';
            }
            return null;
          })();
        ''';
    }

    try {
      final result = await _controller.executeScript(script);
      print('Get response result: $result');
      return result?.toString();
    } catch (e) {
      print('Get response failed: $e');
      return null;
    }
  }

  // 公共方法：学习模式（从对话面板调用）
  Future<void> learnMode(String noteContent) async {
    if (noteContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记内容为空')),
      );
      return;
    }

    // 构建学习模式的消息
    final learnMessage = '''请学习以下笔记内容，不需要回答。后续对话请基于这些内容展开：

$noteContent

[系统提示：已进入学习模式，请记忆以上内容]''';
    // 使用 sendMessageToAI 发送学习消息
    await sendMessageToAI(learnMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                IconButton(
                  icon: Icon(
                    _autoAttachMode ? Icons.link : Icons.link_off,
                    color: _autoAttachMode ? Colors.blue : null,
                  ),
                  onPressed: _toggleAutoAttachMode,
                  tooltip: _autoAttachMode ? '自动跟随已开启' : '开启自动跟随',
                ),
                if (widget.isExpanded) ...[
                  const Divider(height: 1),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendNoteToAI,
                    tooltip: '填充笔记到 AI',
                  ),
                  IconButton(
                    icon: const Icon(Icons.school),
                    onPressed: _learnMode,
                    tooltip: '学习模式 - 让AI学习当前笔记',
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
                                _loadUrl(_aiUrls[newValue]!);
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
                    // WebView
                    Expanded(
                      child: Stack(
                        children: [
                          if (_isControllerInitialized && !widget.hideWebView)
                            Webview(_controller)
                          else if (widget.hideWebView)
                            Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.drag_handle,
                                        size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('调整宽度中...',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            )
                          else
                            const Center(
                              child: CircularProgressIndicator(),
                            ),
                          if (_isLoading && !widget.hideWebView)
                            Container(
                              color: Colors.white.withOpacity(0.8),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
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
                              '当前: $_selectedAI | 点击按钮自动填充笔记',
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
