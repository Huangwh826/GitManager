// lib/widgets/commit_view.dart

import 'package:flutter/material.dart';

/// 这是一个有状态组件，负责提交相关的UI和逻辑。
class CommitView extends StatefulWidget {
  /// 是否有文件被暂存，用于控制提交按钮的可用状态。
  final bool hasStagedFiles;
  /// 点击提交按钮时的回调，参数为提交信息。
  final Future<void> Function(String message) onCommit;

  const CommitView({
    super.key,
    required this.hasStagedFiles,
    required this.onCommit,
  });

  @override
  State<CommitView> createState() => _CommitViewState();
}

class _CommitViewState extends State<CommitView> {
  final _commitMessageController = TextEditingController();
  bool _isCommitting = false;

  /// 处理提交逻辑
  Future<void> _handleCommit() async {
    if (_isCommitting || _commitMessageController.text.trim().isEmpty) return;

    setState(() {
      _isCommitting = true;
    });

    await widget.onCommit(_commitMessageController.text);

    // 成功后清空输入框
    _commitMessageController.clear();
    if (mounted) {
      setState(() {
        _isCommitting = false;
      });
    }
  }

  @override
  void dispose() {
    _commitMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canCommit = widget.hasStagedFiles && _commitMessageController.text.trim().isNotEmpty && !_isCommitting;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          TextField(
            controller: _commitMessageController,
            decoration: const InputDecoration(
              hintText: '提交信息',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (text) => setState(() {}), // 文本变化时刷新UI以更新按钮状态
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canCommit ? _handleCommit : null,
              child: _isCommitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('提交'),
            ),
          ),
        ],
      ),
    );
  }
}