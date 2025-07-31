// lib/widgets/diff_view.dart

import 'package:flutter/material.dart';

/// 一个用于显示 git diff 输出的无状态组件。
class DiffView extends StatelessWidget {
  /// 从 `git diff` 命令获取的原始文本数据。
  final String diffData;

  const DiffView({super.key, required this.diffData});

  /// 根据 diff 文本的每一行返回一个带样式的 TextSpan。
  List<TextSpan> _buildDiffSpans() {
    final List<TextSpan> spans = [];
    final lines = diffData.split('\n');

    for (var line in lines) {
      Color? backgroundColor;
      Color? textColor = Colors.grey[400];
      String prefix = '';

      if (line.startsWith('+')) {
        backgroundColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green[200];
        prefix = '+ ';
      } else if (line.startsWith('-')) {
        backgroundColor = Colors.red.withOpacity(0.2);
        textColor = Colors.red[200];
        prefix = '- ';
      } else if (line.startsWith('@@')) {
        textColor = Colors.cyan;
      }

      spans.add(
        TextSpan(
          text: '$prefix$line\n',
          style: TextStyle(
            backgroundColor: backgroundColor,
            color: textColor,
          ),
        ),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.3),
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        child: SelectableText.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            children: _buildDiffSpans(),
          ),
        ),
      ),
    );
  }
}