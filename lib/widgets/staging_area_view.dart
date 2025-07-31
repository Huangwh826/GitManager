// lib/widgets/staging_area_view.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';
import 'commit_view.dart';
import 'file_status_list_item.dart';

/// 显示暂存区、变更区和提交模块的 Widget
/// (核心重构) 改为 StatefulWidget 以便测量 CommitView 的高度
class StagingAreaView extends StatefulWidget {
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
  State<StagingAreaView> createState() => _StagingAreaViewState();
}

class _StagingAreaViewState extends State<StagingAreaView> {
  final GlobalKey _commitViewKey = GlobalKey();
  double _commitViewHeight = 140.0; // 提供一个合理的初始默认值

  @override
  void initState() {
    super.initState();
    // 在第一帧渲染后获取 CommitView 的实际高度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final RenderBox? renderBox =
        _commitViewKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          setState(() {
            _commitViewHeight = renderBox.size.height;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stagedFiles = widget.allFiles.where((f) => f.isStaged).toList();
    final changedFiles = widget.allFiles.where((f) => !f.isStaged).toList();
    final bool isWorkspaceClean = stagedFiles.isEmpty && changedFiles.isEmpty;

    // --- 核心修正部分：使用 Stack 替代 Column+Expanded ---
    return Stack(
      children: [
        // 1. 滚动列表在底层
        Positioned.fill(
          child: isWorkspaceClean
              ? const Center(child: Text('工作区是干净的'))
              : Padding(
            // 为底部的 CommitView 预留出空间
            padding: EdgeInsets.only(bottom: _commitViewHeight),
            child: ListView(
              children: [
                ..._buildFileSectionChildren(context, '已暂存文件', stagedFiles, true),
                ..._buildFileSectionChildren(context, '变更', changedFiles, false),
              ],
            ),
          ),
        ),
        // 2. 提交视图在顶层，并固定在底部
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min, // 确保 Column 包裹内容
            children: [
              const Divider(height: 1, thickness: 1),
              // 使用 Key 来测量这个 Widget
              Container(
                key: _commitViewKey,
                color: Theme.of(context).scaffoldBackgroundColor, // 给一个背景色以避免透明
                child: CommitView(
                  hasStagedFiles: stagedFiles.isNotEmpty,
                  onCommit: widget.onCommit,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFileSectionChildren(
      BuildContext context,
      String title,
      List<GitFileStatus> files,
      bool isStagedSection,
      ) {
    if (files.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Text(
          '$title (${files.length})'.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[500]),
        ),
      ),
      ...files.map((file) {
        final isSelected = widget.selectedFile?.path == file.path &&
            widget.selectedFile?.isStaged == file.isStaged;
        return Material(
          color: isSelected ? Theme.of(context).highlightColor : Colors.transparent,
          child: FileStatusListItem(
            fileStatus: file,
            onAction: () =>
            isStagedSection ? widget.onUnstage(file.path) : widget.onStage(file.path),
            onItemTap: () => widget.onFileSelected(file),
          ),
        );
      }),
    ];
  }
}