import 'dart:convert';
import 'package:http/http.dart' as http;

class NotionService {
  final String token;

  // 使用本地代理服务器
  final String baseUrl = 'http://localhost:3001/notion';

  NotionService(this.token);

  Future<List<NotionPage>> getPages() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/search'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': '',
          'filter': {'value': 'page', 'property': 'object'}
        }),
      );

      if (response.statusCode == 403 || response.statusCode == 429) {
        throw Exception('代理限流或拒绝访问，请尝试 --disable-web-security 启动');
      }

      if (response.statusCode != 200) {
        throw Exception('API 错误: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      // 某些代理返回格式不同（如 allorigins 包裹在 contents 中）
      final resultsData =
          data['contents'] != null ? jsonDecode(data['contents']) : data;

      final results = resultsData['results'] as List;

      return results
          .where((item) => item['object'] == 'page')
          .map((item) => NotionPage.fromJson(item))
          .toList();
    } catch (e) {
      print('错误详情: $e');
      if (e.toString().contains('Failed to fetch') ||
          e.toString().contains('CORS')) {
        throw Exception(
            '代理失败，请使用命令: flutter run -d chrome --web-browser-flag "--disable-web-security"');
      }
      rethrow;
    }
  }

  Future<NotionPage> createPage(String title, {String? parentPageId}) async {
    if (parentPageId == null) {
      throw Exception('需要提供父页面 ID');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/pages'),
      headers: {
        'Authorization': 'Bearer $token',
        'Notion-Version': '2022-06-28',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'parent': {'page_id': parentPageId},
        'properties': {
          'title': {
            'title': [
              {
                'text': {'content': title}
              }
            ]
          }
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('创建失败: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final actualData =
        data['contents'] != null ? jsonDecode(data['contents']) : data;
    return NotionPage.fromJson(actualData);
  }

  Future<String> getPageContent(String pageId) async {
    final blocks = await _getBlockChildren(pageId);

    final content = <String>[];
    for (final block in blocks) {
      final text = await _extractBlockTextRecursive(block);
      if (text.isNotEmpty) {
        content.add(text);
      }
    }

    return content.join('\n');
  }

  Future<List<Map<String, dynamic>>> _getBlockChildren(String blockId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/blocks/$blockId/children'),
      headers: {
        'Authorization': 'Bearer $token',
        'Notion-Version': '2022-06-28',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('获取子块失败: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final actualData =
        data['contents'] != null ? jsonDecode(data['contents']) : data;
    return (actualData['results'] as List).cast<Map<String, dynamic>>();
  }

  Future<String> _extractBlockTextRecursive(Map<String, dynamic> block) async {
    final type = block['type'] as String?;
    if (type == null) return '';

    final blockData = block[type];
    if (blockData == null) return '';

    // 处理表格类型 - 需要递归获取子块
    if (type == 'table') {
      return await _extractTableFull(block);
    }

    // 处理有子块的类型（如 toggle、column_list 等）
    if (block['has_children'] == true && type != 'table_row') {
      final children = await _getBlockChildren(block['id']);
      final childTexts = <String>[];
      for (final child in children) {
        final childText = await _extractBlockTextRecursive(child);
        if (childText.isNotEmpty) {
          childTexts.add(childText);
        }
      }
      return childTexts.join('\n');
    }

    List<dynamic> richText = [];

    switch (type) {
      case 'paragraph':
      case 'heading_1':
      case 'heading_2':
      case 'heading_3':
      case 'quote':
      case 'callout':
      case 'bulleted_list_item':
      case 'numbered_list_item':
      case 'to_do':
        richText = blockData['rich_text'] ?? [];
        break;
      case 'code':
        richText = blockData['rich_text'] ?? [];
        final language = blockData['language'] ?? '';
        final codeText =
            richText.map((t) => t['text']['content'] ?? '').join('');
        return language.isNotEmpty
            ? '```$language\n$codeText\n```'
            : '```\n$codeText\n```';
      case 'table_row':
        // 表格行在 _extractTableFull 中处理
        return '';
      case 'divider':
        return '---';
      case 'image':
        final caption = blockData['caption'] ?? [];
        final captionText =
            caption.map((t) => t['text']['content'] ?? '').join('');
        return captionText.isNotEmpty ? '🖼️ [$captionText]' : '🖼️ [图片]';
      default:
        return '';
    }

    final text = richText.map((t) {
      final content = t['text']?['content'] ?? '';
      final annotations = t['annotations'];
      if (annotations != null) {
        final isBold = annotations['bold'] == true;
        final isItalic = annotations['italic'] == true;
        final isCode = annotations['code'] == true;
        final isStrikethrough = annotations['strikethrough'] == true;
        final isUnderline = annotations['underline'] == true;

        String result = content;
        if (isCode) result = '`$result`';
        if (isStrikethrough) result = '~~$result~~';
        if (isUnderline) result = '<u>$result</u>';
        if (isBold) result = '**$result**';
        if (isItalic) result = '*$result*';
        return result;
      }
      return content;
    }).join('');

    switch (type) {
      case 'heading_1':
        return '# $text';
      case 'heading_2':
        return '## $text';
      case 'heading_3':
        return '### $text';
      case 'bulleted_list_item':
        return '• $text';
      case 'numbered_list_item':
        return '1. $text';
      case 'quote':
        return '> $text';
      case 'callout':
        final icon = blockData['icon']?['emoji'] ?? '💡';
        return '$icon $text';
      case 'to_do':
        final checked = blockData['checked'] == true;
        return checked ? '☑ $text' : '☐ $text';
      default:
        return text;
    }
  }

  Future<String> _extractTableFull(Map<String, dynamic> block) async {
    final tableData = block['table'];
    if (tableData == null) return '';

    final tableWidth = tableData['table_width'] as int? ?? 0;
    final hasColumnHeader = tableData['has_column_header'] as bool? ?? false;

    // 获取表格的所有行
    final rows = await _getBlockChildren(block['id']);

    if (rows.isEmpty) return '📊 [空表格]';

    final tableLines = <String>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowData = row['table_row'];
      if (rowData == null) continue;

      final cells = rowData['cells'] as List? ?? [];
      final cellTexts = cells.map((cell) {
        if (cell is List && cell.isNotEmpty) {
          return cell.map((t) => t['text']['content'] ?? '').join('');
        }
        return '';
      }).toList();

      // 补齐空单元格
      while (cellTexts.length < tableWidth) {
        cellTexts.add('');
      }

      // 使用 | 分隔单元格
      tableLines.add('| ${cellTexts.join(' | ')} |');

      // 在第一行后添加分隔线（Markdown 表格格式）
      if (i == 0 && hasColumnHeader) {
        final separator = List.filled(tableWidth, '---').join(' | ');
        tableLines.add('| $separator |');
      }
    }

    return tableLines.join('\n');
  }

  Future<void> updatePageContent(String pageId, String content) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/blocks/$pageId/children'),
      headers: {
        'Authorization': 'Bearer $token',
        'Notion-Version': '2022-06-28',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'children': [
          {
            'object': 'block',
            'type': 'paragraph',
            'paragraph': {
              'rich_text': [
                {
                  'type': 'text',
                  'text': {'content': content}
                }
              ]
            }
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('同步失败: ${response.statusCode}');
    }
  }
}

class NotionPage {
  final String id;
  final String title;

  NotionPage({required this.id, required this.title});

  factory NotionPage.fromJson(Map<String, dynamic> json) {
    String title = '无标题';

    if (json['properties'] != null && json['properties']['title'] != null) {
      final titleList = json['properties']['title']['title'] as List?;
      if (titleList != null && titleList.isNotEmpty) {
        title = titleList[0]['text']['content'] ?? '无标题';
      }
    }

    return NotionPage(
      id: json['id'],
      title: title,
    );
  }
}
