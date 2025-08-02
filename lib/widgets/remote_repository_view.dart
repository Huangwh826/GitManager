import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/git_service.dart';
import '../services/repository_service.dart';
import '../models/git_models.dart';

class RemoteRepositoryView extends StatefulWidget {
  const RemoteRepositoryView({super.key});

  @override
  State<RemoteRepositoryView> createState() => _RemoteRepositoryViewState();
}

class _RemoteRepositoryViewState extends State<RemoteRepositoryView> {
  late GitService _gitService;
  Future<List<RemoteRepository>>? _remotesFuture;
  final TextEditingController _remoteNameController = TextEditingController();
  final TextEditingController _remoteUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repoService = Provider.of<RepositoryService>(context);
    final selectedRepoPath = repoService.selectedRepositoryPath;
    if (selectedRepoPath != null) {
      _gitService = GitService(repoPath: selectedRepoPath);
      _fetchRemotes();
    }
  }

  void _fetchRemotes() {
    setState(() {
      _remotesFuture = _gitService.getRemotes();
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
    _fetchRemotes();
  }

  Future<void> _addRemote() async {
    final name = _remoteNameController.text.trim();
    final url = _remoteUrlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      _handleError('远程仓库名称和URL不能为空');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _gitService.addRemote(name, url);
      _showSuccess('已添加远程仓库: $name');
      _remoteNameController.clear();
      _remoteUrlController.clear();
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeRemote(String name) async {
    setState(() => _isLoading = true);
    try {
      await _gitService.removeRemote(name);
      _showSuccess('已移除远程仓库: $name');
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRemoteUrl(String name, String newUrl) async {
    setState(() => _isLoading = true);
    try {
      await _gitService.setRemoteUrl(name, newUrl);
      _showSuccess('已更新远程仓库URL: $name');
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
        title: const Text('远程仓库管理'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _remoteNameController,
                  decoration: const InputDecoration(
                    labelText: '远程仓库名称',
                    hintText: '例如: origin',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _remoteUrlController,
                  decoration: const InputDecoration(
                    labelText: '远程仓库URL',
                    hintText: '例如: https://github.com/username/repo.git',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addRemote,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('添加远程仓库'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<RemoteRepository>>(
              future: _remotesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(child: Text('加载远程仓库失败: ${snapshot.error}'));
                }

                final remotes = snapshot.data!;
                if (remotes.isEmpty) {
                  return const Center(child: Text('没有配置远程仓库'));
                }

                return ListView.builder(
                  itemCount: remotes.length,
                  itemBuilder: (context, index) {
                    final remote = remotes[index];
                    return ListTile(
                      title: Text(remote.name),
                      subtitle: Text(remote.url),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Text('编辑URL'),
                            onTap: () {
                              _remoteNameController.text = remote.name;
                              _remoteUrlController.text = remote.url;
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('更新远程仓库URL'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: _remoteNameController,
                                        enabled: false,
                                        decoration: const InputDecoration(labelText: '远程仓库名称'),
                                      ),
                                      TextField(
                                        controller: _remoteUrlController,
                                        decoration: const InputDecoration(labelText: '新URL'),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('取消'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        _updateRemoteUrl(remote.name, _remoteUrlController.text.trim());
                                        Navigator.pop(context);
                                      },
                                      child: const Text('更新'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          PopupMenuItem(
                            child: const Text('删除'),
                            onTap: () => _removeRemote(remote.name),
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

// 已在git_models.dart中定义RemoteRepository类