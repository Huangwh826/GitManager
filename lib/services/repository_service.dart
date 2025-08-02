// lib/services/repository_service.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 使用 ChangeNotifier 来通知 UI 刷新
class RepositoryService extends ChangeNotifier {
  final List<String> _repositoryPaths = [];
  String? _selectedRepositoryPath;
  static const String _kRepositoriesKey = 'recent_repositories';

  List<String> get repositoryPaths => _repositoryPaths;
  String? get selectedRepositoryPath => _selectedRepositoryPath;

  RepositoryService() {
    // 初始化时从本地存储加载仓库路径
    _loadRepositories();
  }

  /// 从本地存储加载仓库路径
  Future<void> _loadRepositories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPaths = prefs.getStringList(_kRepositoriesKey) ?? [];
    if (savedPaths.isNotEmpty) {
      _repositoryPaths.addAll(savedPaths);
      _selectedRepositoryPath = savedPaths.first;
      notifyListeners();
    }
  }

  /// 保存仓库路径到本地存储
  Future<void> _saveRepositories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRepositoriesKey, _repositoryPaths);
  }

  /// 切换当前选中的仓库
  void selectRepository(String path) {
    if (_repositoryPaths.contains(path) && _selectedRepositoryPath != path) {
      _selectedRepositoryPath = path;
      notifyListeners();
    }
  }

  /// 添加一个新的仓库
  Future<void> addRepository() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      if (!_repositoryPaths.contains(selectedDirectory)) {
        _repositoryPaths.add(selectedDirectory);
        _selectedRepositoryPath = selectedDirectory; // 总是切换到新添加的仓库
        notifyListeners();
        await _saveRepositories(); // 保存到本地存储
      } else {
        // 如果仓库已存在，则直接切换到该仓库
        selectRepository(selectedDirectory);
      }
    }
  }

  // --- 新增方法 ---
  /// 移除一个仓库（关闭标签页）
  Future<void> removeRepository(String path) async {
    if (_repositoryPaths.contains(path)) {
      final index = _repositoryPaths.indexOf(path);
      _repositoryPaths.remove(path);

      // 如果关闭的是当前选中的标签页
      if (_selectedRepositoryPath == path) {
        if (_repositoryPaths.isEmpty) {
          _selectedRepositoryPath = null;
        } else {
          // 自动选中前一个或第一个标签页
          final newIndex = (index > 0) ? index - 1 : 0;
          _selectedRepositoryPath = _repositoryPaths[newIndex];
        }
      }
      notifyListeners();
      await _saveRepositories(); // 保存到本地存储
    }
  }

  /// 刷新仓库状态，通知UI更新
  void refreshRepositoryState() {
    notifyListeners();
  }
}