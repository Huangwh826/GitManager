// lib/widgets/commit_detail_view.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';
import '../services/git_service.dart';
import 'diff_view.dart';

/// 一个有状态的 Widget，用于显示单次提交的详细信息。
class CommitDetailView extends StatefulWidget {
  final GitCommit commit;
  final GitService gitService;
  final VoidCallback onClose;

  const CommitDetailView({
    super.key,
    required this.commit,
    required this.gitService,
    required this.onClose,
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
        if (_selectedFile == null && detail.files.isNotEmpty) {
          _selectedFile = detail.files.first;
        }

        return Column(
          children: [
            AppBar(
              title: const Text('提交详情'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: '返回工作区',
                onPressed: widget.onClose,
              ),
              backgroundColor: Colors.grey.withOpacity(0.1),
              elevation: 0,
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          flex: 1,
                          child: SingleChildScrollView(
                            child: _buildCommitMeta(context, detail),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 4.0),
                          child: Text('变更的文件 (${detail.files.length})', style: Theme.of(context).textTheme.titleSmall),
                        ),
                        Expanded(
                          flex: 2,
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
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: Colors.grey[800]),
                  Expanded(
                    flex: 3,
                    child: _selectedFile != null
                        ? DiffView(diffData: _selectedFile!.diffContent)
                        : const Center(child: Text('没有文件变更')),
                  ),
                ],
              ),
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
          // --- 核心修正部分 ---
          Row(
            children: [
              const CircleAvatar(radius: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 明确禁止换行并设置最大行数
                    Text(
                      detail.author,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                    ),
                    Text(
                      detail.date,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SelectableText(detail.shortHash, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
          // --- 修正结束 ---
        ],
      ),
    );
  }
}