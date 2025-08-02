import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/git_models.dart';
import '../services/git_service.dart';
import 'diff_view.dart';
import 'file_status_list_item.dart';

class FileDiffView extends StatefulWidget {
  final GitService gitService;
  final List<GitFileStatus> allFiles;
  final GitFileStatus initialFile;
  final VoidCallback onClose;
  final ValueChanged<GitFileStatus> onFileChanged;

  const FileDiffView({
    super.key,
    required this.gitService,
    required this.allFiles,
    required this.initialFile,
    required this.onClose,
    required this.onFileChanged,
  });

  @override
  State<FileDiffView> createState() => _FileDiffViewState();
}

class _FileDiffViewState extends State<FileDiffView> {
  GitFileStatus? _currentFile;
  late Future<GitFileDiff> _fileDiffFuture;

  @override
  void initState() {
    super.initState();
    _updateCurrentFile();
    _loadFileDiff();
  }

  @override
  void didUpdateWidget(FileDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFile != widget.initialFile || oldWidget.allFiles != widget.allFiles) {
      _updateCurrentFile();
      _loadFileDiff();
    }
  }

  void _updateCurrentFile() {
    if (widget.allFiles.isEmpty) {
      _currentFile = null;
    } else if (widget.initialFile != null) {
      // 尝试找到与initialFile路径相同的文件
      final matchingFile = widget.allFiles.firstWhere(
        (file) => file.path == widget.initialFile.path,
        orElse: () => widget.allFiles.first,
      );
      _currentFile = matchingFile;
    } else if (_currentFile == null || !widget.allFiles.any((file) => file.path == _currentFile?.path)) {
      _currentFile = widget.allFiles.first;
    }
  }

  void _loadFileDiff() {
    if (_currentFile == null) {
      _fileDiffFuture = Future.value(GitFileDiff(
        path: '',
        type: GitFileStatusType.added,
        diffContent: '',
        additions: 0,
        deletions: 0,
      ));
      return;
    }

    // 保存当前文件引用，避免在异步操作中发生变化
    final currentFile = _currentFile;
    _fileDiffFuture = widget.gitService.getDiff(currentFile!.path).then((diffContent) {
      return GitFileDiff(
        path: currentFile.path,
        type: currentFile.type,
        diffContent: diffContent,
        additions: 0,
        deletions: 0,
      );
    });
  }

  void _changeFile(GitFileStatus file) {
    setState(() {
      _currentFile = file;
      _loadFileDiff();
    });
    widget.onFileChanged(file);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: Row(
            children: [
              Expanded(
                child: widget.allFiles.isEmpty
                  ? const Text('没有可比较的文件')
                  : DropdownButton<GitFileStatus>(
                      key: ValueKey(_currentFile?.path),
                      value: _currentFile,
                      items: widget.allFiles
                          .map(
                            (file) => DropdownMenuItem(
                              value: file,
                              child: Text(
                                file.path,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _changeFile(value);
                        }
                      },
                      isExpanded: true,
                      underline: Container(),
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '关闭差异视图',
                onPressed: widget.onClose,
              ),
            ],
          ),
          elevation: 0,
          backgroundColor: const Color(0xFF1F2937),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<GitFileDiff>(
            future: _fileDiffFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('加载差异失败: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: Text('没有差异数据'));
              }

              final fileDiff = snapshot.data!;
              // 确保_currentFile不为null
              final currentFile = _currentFile;
              if (currentFile == null) {
                return const Center(child: Text('文件未选择'));
              }
              final extension = currentFile.path.split('.').last;

              return DiffView(
                diffData: fileDiff.diffContent,
                fileExtension: extension,
              );
            },
          ),
        ),
      ],
    );
  }
}