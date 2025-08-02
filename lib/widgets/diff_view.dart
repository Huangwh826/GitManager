// lib/widgets/diff_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:flutter_highlight/themes/github.dart' as highlight_styles;


/// 差异视图组件，用于显示代码差异并提供语法高亮和行号功能
class DiffView extends StatefulWidget {
  /// 从 `git diff` 命令获取的原始文本数据
  final String diffData;
  /// 文件扩展名，用于确定使用哪种语法高亮
  final String fileExtension;

  const DiffView({
    super.key,
    required this.diffData,
    this.fileExtension = 'dart',
  });

  @override
  State<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> {
  // 折叠状态管理
  final Map<int, bool> _collapsedSections = {};
  // 存储解析后的差异行
  late List<DiffLine> _diffLines;
  // 存储文件类型对应的语法高亮器
  final Map<String, dynamic Function()> _languageMap = {
    'dart': () => dart,
    'js': () => javascript,
    'ts': () => typescript,
    'java': () => java,
    'py': () => python,
  };

  @override
  void initState() {
    super.initState();
    // 解析差异数据
    _diffLines = _parseDiffData(widget.diffData);
  }

  @override
  void didUpdateWidget(DiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diffData != widget.diffData ||
        oldWidget.fileExtension != widget.fileExtension) {
      // 数据更新时重新解析
      _diffLines = _parseDiffData(widget.diffData);
      // 重置折叠状态
      _collapsedSections.clear();
    }
  }

  /// 解析差异数据为结构化的差异行列表
  List<DiffLine> _parseDiffData(String diffData) {
    final List<DiffLine> lines = [];
    final diffLines = diffData.split('\n');
    int lineNumber = 1;
    int sectionId = 0;
    bool inSection = false;

    for (var line in diffLines) {
      if (line.isEmpty) continue;

      DiffLineType type;
      Color backgroundColor;
      Color textColor;

      if (line.startsWith('diff --git')) {
        type = DiffLineType.meta;
        backgroundColor = Colors.grey[900]!;
        textColor = Colors.grey[300]!;
        inSection = false;
      } else if (line.startsWith('index')) {
        type = DiffLineType.meta;
        backgroundColor = Colors.grey[900]!;
        textColor = Colors.grey[300]!;
      } else if (line.startsWith('---') || line.startsWith('+++')) {
        type = DiffLineType.meta;
        backgroundColor = Colors.grey[900]!;
        textColor = Colors.grey[300]!;
      } else if (line.startsWith('@@')) {
        type = DiffLineType.sectionHeader;
        backgroundColor = Colors.blue[900]!;
        textColor = Colors.blue[200]!;
        sectionId++;
        inSection = true;
      } else if (line.startsWith('+')) {
        type = DiffLineType.addition;
        backgroundColor = Colors.green[900]!.withOpacity(0.3);
        textColor = Colors.green[300]!;
      } else if (line.startsWith('-')) {
        type = DiffLineType.deletion;
        backgroundColor = Colors.red[900]!.withOpacity(0.3);
        textColor = Colors.red[300]!;
      } else {
        type = DiffLineType.context;
        backgroundColor = Colors.transparent;
        textColor = Colors.grey[300]!;
      }

      lines.add(DiffLine(
        text: line,
        type: type,
        lineNumber: inSection ? lineNumber++ : null,
        sectionId: inSection ? sectionId : null,
        backgroundColor: backgroundColor,
        textColor: textColor,
      ));
    }

    return lines;
  }

  /// 切换区块的折叠状态
  void _toggleSection(int sectionId) {
    setState(() {
      _collapsedSections[sectionId] = !(_collapsedSections[sectionId] ?? false);
    });
  }

  /// 复制代码到剪贴板
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('代码已复制到剪贴板')),
    );
  }

  /// 构建语法高亮的文本Span
  List<TextSpan> _buildHighlightedSpans(String code, String fileExtension) {
    try {
      // 根据文件扩展名选择语言
      final language = _languageMap[fileExtension]?.call() ?? dart;
      final result = highlight.parse(code, language: language);
      final nodes = result.nodes ?? [];
      return _convertNodesToSpans(nodes);
    } catch (e) {
      // 如果高亮失败，返回普通文本
      return [TextSpan(text: code)];
    }
  }

  /// 将高亮节点转换为TextSpan
    List<TextSpan> _convertNodesToSpans(List<Node> nodes) {
      final spans = <TextSpan>[];
      final styleMap = highlight_styles.githubTheme;

      for (final node in nodes) {
      if (node.value != null) {
        spans.add(TextSpan(
          text: node.value,
          style: node.className != null
              ? styleMap[node.className!]
              : null,
        ));
      } else if (node.children != null) {
        spans.addAll(_convertNodesToSpans(node.children!));
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
            ),
            child: Row(
              children: [
                Text(
                  '差异视图 (${widget.fileExtension})',
                  style: TextStyle(color: Colors.grey[300]),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.copy, size: 16, color: Colors.grey[400]),
                  onPressed: () => _copyToClipboard(widget.diffData),
                  tooltip: '复制所有差异',
                ),
              ],
            ),
          ),

          // 差异内容
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: SizedBox(width: 40)), // 行号列
                    DataColumn(label: SizedBox(width: 20)), // 变更类型列
                    DataColumn(label: Text('代码')),        // 代码列
                  ],
                  rows: _diffLines
                      .where((line) =>
                          !_collapsedSections.containsKey(line.sectionId) ||
                          !_collapsedSections[line.sectionId]! ||
                          line.type == DiffLineType.sectionHeader)
                      .map((line) {
                    return DataRow(
                      color: MaterialStateColor.resolveWith(
                          (states) => line.backgroundColor),
                      cells: [
                        // 行号列
                        DataCell(
                          line.lineNumber != null
                              ? Text(
                                  '${line.lineNumber}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                )
                              : const SizedBox(),
                        ),

                        // 变更类型列
                        DataCell(
                          line.type == DiffLineType.addition
                              ? Icon(Icons.add, size: 16, color: Colors.green)
                              : line.type == DiffLineType.deletion
                                  ? Icon(Icons.remove, size: 16, color: Colors.red)
                                  : line.type == DiffLineType.sectionHeader
                                      ? IconButton(
                                          icon: Icon(
                                            _collapsedSections[line.sectionId] ?? false
                                                ? Icons.expand_more
                                                : Icons.expand_less,
                                            size: 16,
                                            color: Colors.blue[300],
                                          ),
                                          onPressed: () =>
                                              _toggleSection(line.sectionId!),
                                          padding: EdgeInsets.zero,
                                        )
                                      : const SizedBox(),
                        ),

                        // 代码列
                        DataCell(
                          SelectableText.rich(
                            TextSpan(
                              style: TextStyle(
                                color: line.textColor,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              children: line.type == DiffLineType.sectionHeader ||
                                      line.type == DiffLineType.meta
                                  ? [TextSpan(text: line.text)]
                                  : _buildHighlightedSpans(
                                      line.text,
                                      widget.fileExtension,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 差异行类型枚举
enum DiffLineType {
  addition,
  deletion,
  context,
  sectionHeader,
  meta,
}

/// 差异行数据类
class DiffLine {
  final String text;
  final DiffLineType type;
  final int? lineNumber;
  final int? sectionId;
  final Color backgroundColor;
  final Color textColor;

  DiffLine({
    required this.text,
    required this.type,
    this.lineNumber,
    this.sectionId,
    required this.backgroundColor,
    required this.textColor,
  });
}