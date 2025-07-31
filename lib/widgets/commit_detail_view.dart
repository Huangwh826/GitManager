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
    _loadCommitDetails();
  }

  // --- 核心修正：实现 didUpdateWidget ---
  @override
  void didUpdateWidget(CommitDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当外部传入的 commit 对象发生变化时（通过比较 hash），重新获取提交详情
    if (widget.commit.hash != oldWidget.commit.hash) {
      setState(() {
        _loadCommitDetails();
        // 重置选中的文件，因为新的提交有不同的文件列表
        _selectedFile = null;
      });
    }
  }

  /// 封装加载逻辑，方便复用
  void _loadCommitDetails() {
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
        // 确保在构建时，如果 _selectedFile 为空，则默认选中第一个
        final currentSelectedFile = _selectedFile ?? detail.files.firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 自定义 AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 48,
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '提交详情: ${detail.shortHash}',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '返回工作区',
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 主内容区域
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 提交元信息，允许滚动
                        Expanded(
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
                        // 文件列表
                        Expanded(
                          flex: 2,
                          child: ListView.builder(
                            itemCount: detail.files.length,
                            itemBuilder: (context, index) {
                              final file = detail.files[index];
                              return ListTile(
                                title: Text(file.path, overflow: TextOverflow.ellipsis),
                                dense: true,
                                selected: currentSelectedFile?.path == file.path,
                                onTap: () => setState(() => _selectedFile = file),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 3,
                    child: currentSelectedFile != null
                        ? DiffView(diffData: currentSelectedFile.diffContent)
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
          Row(
            children: [
              const CircleAvatar(radius: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
        ],
      ),
    );
  }
}
