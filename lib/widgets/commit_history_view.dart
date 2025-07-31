// lib/widgets/commit_history_view.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';

/// 显示提交历史列表的 Widget
class CommitHistoryView extends StatelessWidget {
  final List<GitCommit> commits;
  final Function(GitCommit) onCommitSelected;
  final GitCommit? selectedCommit;

  const CommitHistoryView({
    super.key,
    required this.commits,
    required this.onCommitSelected,
    this.selectedCommit,
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
              final commit = commits[index];
              return CommitListItem(
                commit: commit,
                isSelected: selectedCommit?.hash == commit.hash,
                onTap: () => onCommitSelected(commit),
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
  final bool isSelected;

  const CommitListItem({
    super.key,
    required this.commit,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).highlightColor : Colors.transparent,
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
                  Text(
                    commit.message,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // --- 核心修正部分 ---
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${commit.author} • ${commit.date}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 为哈希值设置一个最小宽度，但允许它被压缩
                      Flexible(
                        child: Text(
                          commit.shortHash,
                          style: TextStyle(fontFamily: 'monospace', color: Colors.grey[600], fontSize: 12),
                          overflow: TextOverflow.clip, // 空间不够时直接裁剪
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                  // --- 修正结束 ---
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}