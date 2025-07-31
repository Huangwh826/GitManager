// lib/widgets/branch_list_view.dart

import 'package:flutter/material.dart';
import '../models/git_models.dart';

/// 一个用于显示分支列表的无状态组件，匹配原型样式。
class BranchListView extends StatelessWidget {
  final List<GitBranch> branches;
  final Function(String) onBranchSelected;

  const BranchListView({
    super.key,
    required this.branches,
    required this.onBranchSelected,
  });

  @override
  Widget build(BuildContext context) {
    final localBranches = branches.where((b) => b.isLocal).toList();
    final remoteBranches = branches.where((b) => !b.isLocal).toList();

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        // 本地分支部分
        _buildSectionHeader(context, '分支'),
        ...localBranches.map((branch) => _buildBranchTile(context, branch)),

        // 远程分支部分
        if (remoteBranches.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(context, '远程'),
          ...remoteBranches.map((branch) => _buildRemoteBranchGroup(context, branch, remoteBranches)),
        ]
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBranchTile(BuildContext context, GitBranch branch) {
    return ListTile(
      leading: Icon(
        Icons.fork_right,
        color: branch.isCurrent ? Colors.blueAccent : Colors.grey,
        size: 18,
      ),
      title: Text(
        branch.displayName,
        style: TextStyle(
          fontWeight: branch.isCurrent ? FontWeight.bold : FontWeight.normal,
          color: branch.isCurrent ? Colors.white : Colors.grey[300],
        ),
        overflow: TextOverflow.ellipsis,
      ),
      dense: true,
      selected: branch.isCurrent,
      selectedTileColor: Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onTap: branch.isCurrent ? null : () => onBranchSelected(branch.name),
    );
  }

  // 辅助方法来对远程分支进行分组
  Widget _buildRemoteBranchGroup(BuildContext context, GitBranch branch, List<GitBranch> allRemotes) {
    // 这是一个简化的实现，实际应用中可能需要更复杂的逻辑来分组
    // 这里我们只显示一个示例
    final remoteName = branch.name.split('/')[1];
    final branchesForRemote = allRemotes.where((b) => b.name.contains('$remoteName/')).toList();

    // 为了避免重复渲染，我们只在第一个分支处渲染整个分组
    if (branch != branchesForRemote.first) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              Icon(Icons.cloud_queue, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(remoteName, style: TextStyle(color: Colors.grey[300])),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24.0),
          child: Column(
            children: branchesForRemote.map((b) => ListTile(
              leading: const Icon(Icons.fork_right, size: 16, color: Colors.grey),
              title: Text(b.displayName, style: TextStyle(color: Colors.grey[400])),
              dense: true,
              onTap: () { /* 远程分支点击逻辑待实现 */ },
            )).toList(),
          ),
        ),
      ],
    );
  }
}