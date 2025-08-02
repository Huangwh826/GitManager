// lib/widgets/file_status_list_item.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';

/// 这是一个无状态组件，用于显示单个文件的状态。
class FileStatusListItem extends StatelessWidget {
  /// 文件状态对象
  final GitFileStatus fileStatus;
  /// 点击暂存/取消暂存按钮时的回调函数
  final VoidCallback onAction;
  /// (新增) 点击整个列表项时的回调函数，用于显示差异
  final VoidCallback? onItemTap;

  /// 构造函数，添加了可选的 onItemTap 参数
  const FileStatusListItem({
    super.key,
    required this.fileStatus,
    required this.onAction,
    this.onItemTap, // 新增参数
  });

  /// 根据文件状态返回对应的图标和颜色
  Widget _getStatusIcon() {
    Color color;
    String char;
    switch (fileStatus.type) {
      case GitFileStatusType.modified:
        color = Colors.blue;
        char = 'M';
        break;
      case GitFileStatusType.added:
      case GitFileStatusType.untracked:
        color = Colors.green;
        char = 'A';
        break;
      case GitFileStatusType.deleted:
        color = Colors.red;
        char = 'D';
        break;
      case GitFileStatusType.renamed:
        color = Colors.orange;
        char = 'R';
        break;
      // --- 核心修改：为 'unknown' 状态和默认情况提供处理逻辑 ---
      case GitFileStatusType.unknown:
      default:
        color = Colors.grey;
        char = '?';
        break;
    }
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          char,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _getStatusIcon(),
      title: Text(
        fileStatus.path,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      dense: true,
      trailing: IconButton(
        icon: Icon(
          fileStatus.isStaged ? Icons.remove_circle_outline : Icons.add_circle_outline,
          size: 18,
          color: fileStatus.isStaged ? Colors.orange : Colors.green,
        ),
        tooltip: fileStatus.isStaged ? '取消暂存' : '暂存',
        onPressed: onAction,
      ),
      onTap: onItemTap,
    );
  }
}