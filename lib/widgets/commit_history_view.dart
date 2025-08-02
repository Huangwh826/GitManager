// lib/widgets/commit_history_view.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';

/// 显示提交历史列表的 Widget
class CommitHistoryView extends StatelessWidget {
  final List<GitCommit> commits;
  final Function(GitCommit) onCommitSelected;
  // --- 新增回调 ---
  final Function(GitCommit) onCherryPick;
  final GitCommit? selectedCommit;

  const CommitHistoryView({
    super.key,
    required this.commits,
    required this.onCommitSelected,
    required this.onCherryPick, // --- 新增回调 ---
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
                // --- 传递回调 ---
                onCherryPick: () => onCherryPick(commit),
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
  // --- 新增回调 ---
  final VoidCallback onCherryPick;
  final bool isSelected;

  const CommitListItem({
    super.key,
    required this.commit,
    required this.onTap,
    required this.onCherryPick, // --- 新增回调 ---
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
                      Flexible(
                        child: Text(
                          commit.shortHash,
                          style: TextStyle(fontFamily: 'monospace', color: Colors.grey[600], fontSize: 12),
                          overflow: TextOverflow.clip,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // --- 核心修改：添加PopupMenuButton ---
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cherry-pick') {
                  onCherryPick();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'cherry-pick',
                  child: Text('Cherry-pick 此提交'),
                ),
              ],
              icon: const Icon(Icons.more_vert, size: 18),
              tooltip: '更多操作',
            ),
            // --- 修改结束 ---
          ],
        ),
      ),
    );
  }
}