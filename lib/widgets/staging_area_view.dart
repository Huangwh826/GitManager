// lib/widgets/staging_area_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // 导入 BoxHitTestResult
import '../models/git_models.dart';
import 'commit_view.dart';
import 'file_status_list_item.dart';
import 'package:provider/provider.dart';
import '../services/repository_service.dart';
import '../services/git_service.dart';

/// 显示暂存区、变更区和提交模块的 Widget
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
  double _commitViewHeight = 140.0; // 初始默认高度
  final Set<String> _selectedFilePaths = {}; // 跟踪选中的文件路径
  bool _isSelectionMode = false; // 是否处于选择模式
  bool _isProcessing = false; // 用于防止重复提交

  // 切换文件选择状态
  void _toggleFileSelection(String filePath) {
    setState(() {
      if (_selectedFilePaths.contains(filePath)) {
        _selectedFilePaths.remove(filePath);
      } else {
        _selectedFilePaths.add(filePath);
        _isSelectionMode = true;
      }

      // 如果没有选中的文件，退出选择模式
      if (_selectedFilePaths.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  // 清空选择
  void _clearSelection() {
    setState(() {
      _selectedFilePaths.clear();
      _isSelectionMode = false;
    });
  }

  // 批量操作处理函数
  Future<void> _batchOperation(Future<void> Function(List<String>) operation) async {
    if (_selectedFilePaths.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await operation(_selectedFilePaths.toList());
      _clearSelection();
      // 触发刷新文件状态
      Provider.of<RepositoryService>(context, listen: false).refreshRepositoryState();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // 批量暂存选中的文件
  Future<void> _batchStage() async {
    final repoService = Provider.of<RepositoryService>(context, listen: false);
    final gitService = GitService(repoPath: repoService.selectedRepositoryPath!);
    await _batchOperation(gitService.stageFiles);
  }

  // 批量取消暂存选中的文件
  Future<void> _batchUnstage() async {
    final repoService = Provider.of<RepositoryService>(context, listen: false);
    final gitService = GitService(repoPath: repoService.selectedRepositoryPath!);
    await _batchOperation(gitService.unstageFiles);
  }

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

    // 当前显示的文件中被选中的数量
    final displayedFiles = [...stagedFiles, ...changedFiles];
    final selectedCount = displayedFiles
        .where((file) => _selectedFilePaths.contains(file.path))
        .length;
    final isAllSelected = selectedCount == displayedFiles.length && displayedFiles.isNotEmpty;

    return Stack(
      children: [
        // 1. 滚动列表在底层
        Positioned.fill(
          child: isWorkspaceClean
              ? const Center(child: Text('工作区是干净的'))
              : Padding(
            // 为底部的 CommitView 和顶部的操作栏预留出空间
            padding: EdgeInsets.only(
              top: _isSelectionMode ? 56.0 : 0.0,  // 操作栏高度
              bottom: _commitViewHeight,
            ),
            child: GestureDetector(
              onTapDown: (event) {
                // 检测是否点击了空白区域
                final hitTestResult = BoxHitTestResult();
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox != null &&
                    !renderBox.hitTest(hitTestResult, position: event.localPosition)) {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedFilePaths.clear();
                  });
                }
              },
              child: ListView(
                children: [
                  ..._buildFileSection(context, '已暂存文件', stagedFiles, true),
                  ..._buildFileSection(context, '变更', changedFiles, false),
                ],
              ),
            ),
          ),
        ),
        // 2. 提交视图在顶层，并固定在底部
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1, thickness: 1),
              Container(
                key: _commitViewKey,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: CommitView(
                  hasStagedFiles: stagedFiles.isNotEmpty,
                  onCommit: widget.onCommit,
                ),
              ),
            ],
          ),
        ),
        // 3. 批量操作栏
        if (_isSelectionMode) Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            color: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: isAllSelected,
                        onChanged: (value) {
                          if (value == true) {
                            // 全选
                            setState(() {
                              _selectedFilePaths.addAll(displayedFiles.map((file) => file.path));
                            });
                          } else {
                            // 取消全选
                            _clearSelection();
                          }
                        },
                        checkColor: Colors.white,
                        activeColor: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '已选择 $selectedCount 个文件',
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('取消选择', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: selectedCount > 0 && !_isProcessing ? _batchStage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedCount > 0 && !_isProcessing ? Colors.green : Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: _isProcessing ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('暂存所选'),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: selectedCount > 0 && !_isProcessing ? _batchUnstage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedCount > 0 && !_isProcessing ? Colors.orange : Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: _isProcessing ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('取消暂存所选'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 构建文件区域的子组件
  List<Widget> _buildFileSection(
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
      ...files.map((file) => _buildFileItem(context, file, isStagedSection)),
    ];
  }

  // 构建单个文件项
  Widget _buildFileItem(
      BuildContext context,
      GitFileStatus file,
      bool isStagedSection,
      ) {
    final isSelectedByUser = _selectedFilePaths.contains(file.path);
    final isSelected = widget.selectedFile?.path == file.path &&
        widget.selectedFile?.isStaged == file.isStaged;

    return Material(
      color: isSelected ? Theme.of(context).highlightColor : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleFileSelection(file.path);
          } else {
            widget.onFileSelected(file);
          }
        },
        onLongPress: () => _toggleFileSelection(file.path),
        child: Container(
          padding: _isSelectionMode ? const EdgeInsets.only(left: 36) : EdgeInsets.zero,
          child: Stack(
            children: [
              FileStatusListItem(
                fileStatus: file,
                onAction: () =>
                isStagedSection ? widget.onUnstage(file.path) : widget.onStage(file.path),
                onItemTap: () => widget.onFileSelected(file),
              ),
              // 选择复选框
              if (_isSelectionMode) Positioned(
                left: 8, top: 8,
                child: Checkbox(
                  value: isSelectedByUser,
                  onChanged: (value) => _toggleFileSelection(file.path),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              // 选中标记 (非选择模式下的简洁标记)
              if (isSelectedByUser && !_isSelectionMode) Positioned(
                left: 8, top: 8,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}