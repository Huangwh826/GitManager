// lib/widgets/branch_list_view.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';

/// 一个用于显示分支列表的无状态组件，匹配原型样式。
class BranchListView extends StatelessWidget {
  final List<GitBranch> branches;
  final Function(String) onBranchSelected;
  final Function(String) onCreateBranch;

  const BranchListView({
    super.key,
    required this.branches,
    required this.onBranchSelected,
    required this.onCreateBranch,
  });

  void _showCreateBranchDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建新分支'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '分支名称',
              hintText: '例如: feature/new-design',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: const Text('创建'),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onCreateBranch(controller.text);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localBranches = branches.where((b) => b.isLocal).toList();
    final remoteBranches = branches.where((b) => !b.isLocal).toList();

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        _buildSectionHeader(
          context,
          '本地分支',
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: '创建新分支',
            onPressed: () => _showCreateBranchDialog(context),
          ),
        ),
        ...localBranches.map((branch) => _buildBranchTile(context, branch)),
        if (remoteBranches.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(context, '远程'),
          Column(children: _buildRemoteBranchGroups(context, remoteBranches)),
        ]
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, [Widget? trailing]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 12),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildBranchTile(BuildContext context, GitBranch branch) {
    // 构建领先/落后提交信息的小部件
    Widget buildCommitStatus() {
      if (branch.aheadCommits == 0 && branch.behindCommits == 0) {
        return const SizedBox.shrink();
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (branch.aheadCommits > 0)
            Text(
              '↑${branch.aheadCommits}',
              style: const TextStyle(color: Colors.green, fontSize: 11),
            ),
          if (branch.aheadCommits > 0 && branch.behindCommits > 0)
            const SizedBox(width: 4),
          if (branch.behindCommits > 0)
            Text(
              '↓${branch.behindCommits}',
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
        ],
      );
    }
    // --- 核心修改：使用 GestureDetector 包裹 ListTile ---
    return GestureDetector(
      onDoubleTap: branch.isCurrent ? null : () => onBranchSelected(branch.name),
      child: ListTile(
        leading: Icon(
          Icons.fork_right,
          color: branch.isCurrent ? Colors.blueAccent : Colors.grey,
          size: 18,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                branch.displayName,
                style: TextStyle(
                  fontWeight: branch.isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: branch.isCurrent ? Colors.white : Colors.grey[300],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            buildCommitStatus(),
          ],
        ),
        subtitle: branch.upstreamInfo != null
            ? Text(branch.upstreamInfo!, style: TextStyle(color: Colors.grey[600], fontSize: 11), overflow: TextOverflow.ellipsis)
            : null,
        dense: true,
        selected: branch.isCurrent,
        selectedTileColor: Colors.blue.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        // onTap 留空或用于单击高亮等其他交互
        onTap: () {},
      ),
    );
    // --- 修改结束 ---
  }

  List<Widget> _buildRemoteBranchGroups(BuildContext context, List<GitBranch> remoteBranches) {
    final groups = <String, List<GitBranch>>{};
    for (var branch in remoteBranches) {
      final parts = branch.name.split('/');
      if (parts.length > 2) {
        final remoteName = parts[1];
        (groups[remoteName] ??= []).add(branch);
      }
    }
    return groups.entries.map((entry) {
      final remoteName = entry.key;
      final branchesForRemote = entry.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Icon(Icons.cloud_queue, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(remoteName, style: TextStyle(color: Colors.grey[300]), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Column(
              children: branchesForRemote.map((b) => ListTile(
                leading: const Icon(Icons.fork_right, size: 16, color: Colors.grey),
                title: Text(b.displayName, style: TextStyle(color: Colors.grey[400]), overflow: TextOverflow.ellipsis),
                dense: true,
                onTap: () {},
              )).toList(),
            ),
          ),
        ],
      );
    }).toList();
  }
}