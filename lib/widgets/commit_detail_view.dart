// lib/widgets/commit_detail_view.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';
import '../services/git_service.dart';
import 'diff_view.dart';

/// 一个有状态的 Widget，用于显示单次提交的详细信息。
class CommitDetailView extends StatefulWidget {
  final GitCommit commit;
  final GitService gitService;

  const CommitDetailView({
    super.key,
    required this.commit,
    required this.gitService,
  });

  @override
  State<CommitDetailView> createState() => _CommitDetailViewState();
}

class _CommitDetailViewState extends State<CommitDetailView> {
  Future<GitCommitDetail>? _detailFuture;
  GitFileDiff? _selectedFile;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.gitService.getCommitDetails(widget.commit.hash);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GitCommitDetail>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('加载提交详情失败: ${snapshot.error}'));
        }

        final detail = snapshot.data!;
        // 默认选中第一个文件
        if (_selectedFile == null && detail.files.isNotEmpty) {
          _selectedFile = detail.files.first;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：提交信息和文件列表
            Container(
              width: 350,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey[800]!)),
              ),
              // --- 核心修改部分 ---
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 将提交元数据包裹在 Flexible 和 SingleChildScrollView 中
                  Flexible(
                    flex: 1, // 分配一个灵活的比例
                    child: SingleChildScrollView(
                      child: _buildCommitMeta(context, detail),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 4.0),
                    child: Text('变更的文件 (${detail.files.length})', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  // 文件列表将占据剩余的所有空间
                  Expanded(
                    flex: 2, // 分配一个更大的比例
                    child: ListView.builder(
                      itemCount: detail.files.length,
                      itemBuilder: (context, index) {
                        final file = detail.files[index];
                        return ListTile(
                          title: Text(file.path, overflow: TextOverflow.ellipsis),
                          dense: true,
                          selected: _selectedFile?.path == file.path,
                          onTap: () => setState(() => _selectedFile = file),
                        );
                      },
                    ),
                  ),
                ],
              ),
              // --- 修改结束 ---
            ),
            // 右侧：差异视图
            Expanded(
              child: _selectedFile != null
                  ? DiffView(diffData: _selectedFile!.diffContent)
                  : const Center(child: Text('没有文件变更')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommitMeta(BuildContext context, GitCommitDetail detail) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(detail.message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(radius: 16), // Placeholder for author avatar
              const SizedBox(width: 8),
              // 使用 Expanded 来防止长文本溢出
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.author, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    Text(detail.date, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SelectableText(detail.shortHash, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }
}