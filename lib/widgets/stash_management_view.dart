import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/git_service.dart';
import '../services/repository_service.dart';
import '../models/git_models.dart';

class StashManagementView extends StatefulWidget {
  const StashManagementView({super.key});

  @override
  State<StashManagementView> createState() => _StashManagementViewState();
}

class _StashManagementViewState extends State<StashManagementView> {
  late GitService _gitService;
  Future<List<GitStash>>? _stashesFuture;
  final TextEditingController _stashMessageController = TextEditingController();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repoService = Provider.of<RepositoryService>(context);
    final selectedRepoPath = repoService.selectedRepositoryPath;
    if (selectedRepoPath != null) {
      _gitService = GitService(repoPath: selectedRepoPath);
      _fetchStashes();
    }
  }

  void _fetchStashes() {
    setState(() {
      _stashesFuture = _gitService.getStashes();
    });
  }

  void _handleError(dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('操作失败: $error'), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
    _fetchStashes();
  }

  Future<void> _createStash() async {
    final message = _stashMessageController.text.trim();

    setState(() => _isLoading = true);
    try {
      // 确保始终传递消息参数
      await _gitService.stash(message.isEmpty ? '未命名的stash' : message);
      _showSuccess('已创建新的stash');
      _stashMessageController.clear();
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applyStash(String name) async {
    setState(() => _isLoading = true);
    try {
      await _gitService.applyStash(name);
      _showSuccess('已应用stash: $name');
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _dropStash(String name) async {
    setState(() => _isLoading = true);
    try {
      await _gitService.dropStash(name);
      _showSuccess('已删除stash: $name');
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stash管理'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _stashMessageController,
                  decoration: const InputDecoration(
                    labelText: 'Stash描述信息 (可选)',
                    hintText: '例如: 修复登录bug',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createStash,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('创建Stash'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<GitStash>>(
              future: _stashesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(child: Text('加载stash失败: ${snapshot.error}'));
                }

                final stashes = snapshot.data!;
                if (stashes.isEmpty) {
                  return const Center(child: Text('没有stash'));
                }

                return ListView.builder(
                  itemCount: stashes.length,
                  itemBuilder: (context, index) {
                    final stash = stashes[index];
                    return ListTile(
                      title: Text(stash.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('作者: ${stash.author}'),
                          Text('日期: ${stash.date}'),
                          Text('描述: ${stash.message}'),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Text('应用'),
                            onTap: () => _applyStash(stash.name),
                          ),
                          PopupMenuItem(
                            child: const Text('删除'),
                            onTap: () => _dropStash(stash.name),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}