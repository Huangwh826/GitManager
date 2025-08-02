// lib/widgets/commit_detail_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/git_models.dart';
import '../services/git_service.dart';
import 'package:file_icon/file_icon.dart';
import 'package:intl/intl.dart';
// 移除了不再需要的 diff_view.dart 导入

/// 一个有状态的 Widget，用于显示单次提交的详细信息。
class CommitDetailView extends StatefulWidget {
  final GitCommit commit;
  final GitService gitService;
  final VoidCallback onClose;
  // --- 核心修改：新增这两个参数来接收父组件的状态和回调 ---
  final GitFileDiff? selectedFile;
  final Function(GitFileDiff) onFileSelected;

  const CommitDetailView({
    super.key,
    required this.commit,
    required this.gitService,
    required this.onClose,
    required this.selectedFile,
    required this.onFileSelected,
  });

  @override
  State<CommitDetailView> createState() => _CommitDetailViewState();
}

class _CommitDetailViewState extends State<CommitDetailView> {
  Future<GitCommitDetail>? _detailFuture;
  // --- 核心修改：移除内部状态，让组件受父组件控制 ---
  // GitFileDiff? _selectedFile; // <--- 移除此行

  @override
  void initState() {
    super.initState();
    _loadCommitDetails();
  }

  @override
  void didUpdateWidget(CommitDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当外部传入的 commit 对象发生变化时，重新获取提交详情
    if (widget.commit.hash != oldWidget.commit.hash) {
      _loadCommitDetails();
      // 不再需要管理 _selectedFile 状态
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
        // --- 核心修改：使用父组件传入的 selectedFile ---
        final currentSelectedFile = widget.selectedFile;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AppBar 部分保持不变...
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // 提交元信息，优先一次性展示完，不使用滚动条
          IntrinsicHeight(
            child: _buildCommitMeta(context, detail),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('变更的文件 (${detail.files.length})', style: Theme.of(context).textTheme.titleSmall),
                IconButton(
                  icon: const Icon(Icons.search, size: 18),
                  onPressed: () { /* 搜索功能待实现 */ },
                  tooltip: '搜索文件',
                ),
              ],
            ),
          ),
          // 文件列表
          Expanded(
            child: ListView.builder(
              itemCount: detail.files.length,
              itemBuilder: (context, index) {
                final file = detail.files[index];
                return _buildFileListItem(file, currentSelectedFile?.path == file.path);
              },
            ),
          ),
        ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建文件列表项
  Widget _buildFileListItem(GitFileDiff file, bool isSelected) {
    // 从路径获取文件名和扩展名
    final pathParts = file.path.split('/');
    final fileName = pathParts.last;
    final extension = fileName.contains('.') ? fileName.split('.').last : '';

    // 根据文件状态确定显示的图标和颜色
    Color? iconColor;
    IconData statusIcon;

    if (file.status == 'added') {
      statusIcon = Icons.add_circle_outline;
      iconColor = Colors.green;
    } else if (file.status == 'modified') {
      statusIcon = Icons.edit_outlined;
      iconColor = Colors.blue;
    } else if (file.status == 'deleted') {
      statusIcon = Icons.delete_outline;
      iconColor = Colors.red;
    } else if (file.status == 'renamed') {
      statusIcon = Icons.drive_file_rename_outline;
      iconColor = Colors.orange;
    } else {
      statusIcon = Icons.file_open;
      iconColor = null;
    }

    // 计算变更大小
    final changeSize = file.additions + file.deletions;

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 文件类型图标
          FileIcon(
            extension.isNotEmpty ? extension : 'file',
            size: 18,
          ),
          const SizedBox(width: 8),
          // 变更类型图标
          Icon(
            statusIcon,
            size: 16,
            color: iconColor,
          ),
        ],
      ),
      title: Text(
        file.path,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      trailing: changeSize > 0
          ? Text(
              '+${file.additions}/-${file.deletions}',
              style: TextStyle(
                fontSize: 12,
                color: file.additions > 0 && file.deletions == 0
                    ? Colors.green
                    : file.deletions > 0 && file.additions == 0
                        ? Colors.red
                        : Colors.orange,
              ),
            )
          : null,
      dense: true,
      selected: isSelected,
      // --- 核心修改：调用父组件的回调函数 ---
      onTap: () => widget.onFileSelected(file),
      tileColor: isSelected ? Theme.of(context).highlightColor.withOpacity(0.2) : null,
      selectedTileColor: Theme.of(context).highlightColor.withOpacity(0.3),
    );
  }

  Widget _buildCommitMeta(BuildContext context, GitCommitDetail detail) {
    // 格式化日期
    final gitDateFormat = DateFormat('EEE MMM d HH:mm:ss yyyy Z', 'en_US');
    final dateTime = gitDateFormat.parse(detail.date, true);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedDate = dateFormat.format(dateTime);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 提交消息
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                detail.message.split('\n').first,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 提交者信息
          _buildInfoRow(Icons.person, '提交者', '${detail.author} <${detail.authorEmail}>'),

          // 日期信息
          _buildInfoRow(Icons.calendar_today, '日期', formattedDate),

          // 哈希信息，点击哈希值时自动复制
          _buildInfoRowWithCopy(Icons.commit, '哈希', detail.hash.substring(0, 8), detail.hash),
        ],
      ),
    );
  }

  /// 构建信息行，包含图标、标签和值
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
        [
          Icon(icon, size: 18, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建带复制功能的信息行
  Widget _buildInfoRowWithCopy(IconData icon, String label, String shortValue, String fullValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: fullValue));
                    // 通过SnackBar通知用户
                    final snackBar = SnackBar(content: Text('已复制 $shortValue 到剪贴板'));
                    // 使用ScaffoldMessenger显示SnackBar
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  },
                  child: Text(
                    shortValue,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}