import 'package:flutter/material.dart';
import '../services/notion_service.dart';

class NotePage extends StatefulWidget {
  final String token;
  
  const NotePage({super.key, required this.token});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();
  late NotionService _notionService;
  
  List<NotionPage> _pages = [];
  List<NotionPage> _filteredPages = [];
  NotionPage? _selectedPage;
  NotionPage? _parentPageForCreate; // 用于创建新页面时的父页面
  bool _isLoading = false;
  bool _isSyncing = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _notionService = NotionService(widget.token);
    _loadPages();
  }

  Future<void> _loadPages() async {
    setState(() => _isLoading = true);
    try {
      final pages = await _notionService.getPages();
      setState(() {
        _pages = pages;
        _filteredPages = pages;
        // 默认使用第一个页面作为创建新页面的父级（如果需要）
        if (pages.isNotEmpty) {
          _parentPageForCreate = pages.first;
        }
      });
      if (pages.isEmpty) {
        setState(() => _status = '没有找到任何页面。请先在 Notion 中创建至少一个页面，并确保已将该 Integration 添加到页面中。');
      }
    } catch (e) {
      setState(() => _status = '加载页面失败: $e');
    }
    setState(() => _isLoading = false);
  }

  void _filterPages(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPages = _pages;
      } else {
        _filteredPages = _pages.where((p) => 
          p.title.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  Future<void> _loadPageContent(NotionPage page) async {
    setState(() {
      _selectedPage = page;
      _isLoading = true;
      _status = '';
    });
    try {
      final content = await _notionService.getPageContent(page.id);
      _contentController.text = content;
    } catch (e) {
      setState(() => _status = '加载内容失败: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _createNewPage() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法创建页面：没有找到可用的父页面。请先确保 Notion 中已有页面，且已将 Integration 连接到这些页面。')),
      );
      return;
    }

    final controller = TextEditingController();
    
    // 选择父页面
    NotionPage? selectedParent = _parentPageForCreate ?? _pages.first;
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新页面'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '页面标题',
                hintText: '输入新页面标题',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NotionPage>(
              value: selectedParent,
              decoration: const InputDecoration(
                labelText: '父页面（新页面将创建在此页面下）',
              ),
              items: _pages.map((page) => DropdownMenuItem(
                value: page,
                child: Text(page.title),
              )).toList(),
              onChanged: (value) {
                if (value != null) selectedParent = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'title': controller.text,
              'parentId': selectedParent?.id ?? '',
            }),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result['title']!.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final newPage = await _notionService.createPage(
          result['title']!,
          parentPageId: result['parentId'],
        );
        setState(() {
          _pages.add(newPage);
          _filteredPages = _pages;
          _selectedPage = newPage;
          _contentController.clear();
          _status = '页面创建成功！';
        });
      } catch (e) {
        setState(() => _status = '创建页面失败: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncToNotion() async {
    if (_selectedPage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个页面')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _status = '同步中...';
    });

    try {
      final content = _contentController.text;
      await _notionService.updatePageContent(_selectedPage!.id, content);
      setState(() => _status = '同步成功！');
    } catch (e) {
      setState(() => _status = '同步失败: $e');
    }

    setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notion 笔记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPages,
            tooltip: '刷新页面列表',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '退出登录',
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 300,
            color: Colors.grey[100],
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _createNewPage,
                    icon: const Icon(Icons.add),
                    label: const Text('新建页面'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '搜索页面...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _filterPages,
                  ),
                ),
                const Divider(),
                if (_pages.isEmpty && !_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      '没有可用页面。\n\n请确保：\n1. Integration Token 正确\n2. 已将 Integration 连接到 Notion 页面\n3. Notion 中已有页面',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: _isLoading && _pages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _filteredPages.length,
                          itemBuilder: (context, index) {
                            final page = _filteredPages[index];
                            return ListTile(
                              title: Text(page.title),
                              subtitle: Text(
                                page.id,
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: _selectedPage?.id == page.id,
                              onTap: () => _loadPageContent(page),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedPage != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '编辑: ${_selectedPage!.title}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 20),
                          onPressed: () {
                            // 可以在浏览器中打开页面
                          },
                          tooltip: '在 Notion 中打开',
                        ),
                      ],
                    )
                  else
                    const Text(
                      '请从左侧选择一个页面或创建新页面',
                      style: TextStyle(color: Colors.grey),
                    ),
                  if (_status.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _status.contains('成功') ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _status.contains('成功') ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        _status,
                        style: TextStyle(
                          color: _status.contains('成功') ? Colors.green[800] : Colors.red[800],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '在这里输入笔记内容...\n\n注意：同步时会追加新内容到 Notion，不会覆盖已有内容。',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncToNotion,
                    icon: _isSyncing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                    label: Text(_isSyncing ? '同步中...' : '同步到 Notion'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
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

  @override
  void dispose() {
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
