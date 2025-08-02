import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/git_service.dart';
import '../services/repository_service.dart';
import '../models/git_models.dart';

class ConflictResolverView extends StatefulWidget {
  const ConflictResolverView({super.key});

  @override
  State<ConflictResolverView> createState() => _ConflictResolverViewState();
}

class _ConflictResolverViewState extends State<ConflictResolverView> {
  late GitService _gitService;
  Future<List<String>>? _conflictFilesFuture;
  String? _selectedFile;
  Future<String?>? _fileContentFuture;
  final TextEditingController _resolvedContentController = TextEditingController();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repoService = Provider.of<RepositoryService>(context);
    final selectedRepoPath = repoService.selectedRepositoryPath;
    if (selectedRepoPath != null) {
      _gitService = GitService(repoPath: selectedRepoPath);
      _fetchConflictFiles();
    }
  }

  void _fetchConflictFiles() {
    setState(() {
      _conflictFilesFuture = _gitService.getConflictFiles();
    });
  }

  void _loadFileContent(String filePath) {
    setState(() {
      _selectedFile = filePath;
      _fileContentFuture = _gitService.getFileWithConflicts(filePath);
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
    _fetchConflictFiles();
  }

  Future<void> _resolveConflict() async {
    if (_selectedFile == null) {
      _handleError('请先选择一个冲突文件');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _gitService.resolveConflict(_selectedFile!, _resolvedContentController.text);
      _showSuccess('已解决文件冲突: $_selectedFile');
      setState(() {
        _selectedFile = null;
        _resolvedContentController.clear();
      });
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
        title: const Text('冲突解决'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _conflictFilesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(child: Text('加载冲突文件失败: ${snapshot.error}'));
                }

                final conflictFiles = snapshot.data!;
                if (conflictFiles.isEmpty) {
                  return const Center(child: Text('没有冲突文件'));
                }

                return ListView.builder(
                  itemCount: conflictFiles.length,
                  itemBuilder: (context, index) {
                    final file = conflictFiles[index];
                    return ListTile(
                      title: Text(file),
                      onTap: () => _loadFileContent(file),
                      selected: _selectedFile == file,
                      selectedTileColor: Colors.blue.withOpacity(0.1),
                    );
                  },
                );
              },
            ),
          ),

          if (_selectedFile != null)
            Expanded(
              child: FutureBuilder<String?>(
                future: _fileContentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(child: Text('加载文件内容失败: ${snapshot.error}'));
                  }

                  final content = snapshot.data!;
                  _resolvedContentController.text = content;

                  return Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            controller: _resolvedContentController,
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: '编辑解决后的内容',
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _resolveConflict,
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('标记为已解决'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}