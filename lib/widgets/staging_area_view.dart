// lib/widgets/staging_area_view.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';
import 'commit_view.dart';
import 'file_status_list_item.dart';

/// 显示暂存区、变更区和提交模块的 Widget
class StagingAreaView extends StatelessWidget {
  final List<GitFileStatus> allFiles;
  final Function(String) onStage;
  final Function(String) onUnstage;
  final Function(GitFileStatus) onFileSelected;
  final Future<void> Function(String) onCommit;
  final GitFileStatus? selectedFile;

  const StagingAreaView({
    super.key,
    required this.allFiles,
    required this.onStage,
    required this.onUnstage,
    required this.onFileSelected,
    required this.onCommit,
    this.selectedFile,
  });

  @override
  Widget build(BuildContext context) {
    final stagedFiles = allFiles.where((f) => f.isStaged).toList();
    final changedFiles = allFiles.where((f) => !f.isStaged).toList();

    return Column(
      children: [
        Expanded(
          child: (stagedFiles.isEmpty && changedFiles.isEmpty)
              ? const Center(child: Text('工作区是干净的'))
              : ListView(
            children: [
              _buildFileSection(context, '已暂存文件', stagedFiles, true),
              _buildFileSection(context, '变更', changedFiles, false),
            ],
          ),
        ),
        const Divider(height: 1),
        CommitView(
          hasStagedFiles: stagedFiles.isNotEmpty,
          onCommit: onCommit,
        ),
      ],
    );
  }

  Widget _buildFileSection(BuildContext context, String title, List<GitFileStatus> files, bool isStagedSection) {
    if (files.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text('$title (${files.length})'.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[500])),
        ),
        ...files.map((file) {
          final isSelected = selectedFile?.path == file.path && selectedFile?.isStaged == file.isStaged;
          return Material(
            color: isSelected ? Theme.of(context).highlightColor : Colors.transparent,
            child: FileStatusListItem(
              fileStatus: file,
              onAction: () => isStagedSection ? onUnstage(file.path) : onStage(file.path),
              onItemTap: () => onFileSelected(file),
            ),
          );
        }),
      ],
    );
  }
}