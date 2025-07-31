// lib/widgets/commit_history_view.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';

/// 显示提交历史列表的 Widget
class CommitHistoryView extends StatelessWidget {
  final List<GitCommit> commits;
  /// (新增) 当用户点击一个提交项时的回调
  final Function(GitCommit) onCommitSelected;

  const CommitHistoryView({
    super.key,
    required this.commits,
    required this.onCommitSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text('提交历史'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        Expanded(
          child: commits.isEmpty
              ? const Center(child: Text('没有提交记录'))
              : ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: commits.length,
            itemBuilder: (context, index) {
              return CommitListItem(
                commit: commits[index],
                onTap: () => onCommitSelected(commits[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 列表中的单个提交项，包含提交图谱的绘制
class CommitListItem extends StatelessWidget {
  final GitCommit commit;
  final VoidCallback onTap;

  const CommitListItem({
    super.key,
    required this.commit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[850]!)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 50,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(width: 2, color: Colors.grey[700]),
                  Positioned(
                    top: 12,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(commit.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(commit.author, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(commit.date, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      const Spacer(),
                      Text(commit.shortHash, style: TextStyle(fontFamily: 'monospace', color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}