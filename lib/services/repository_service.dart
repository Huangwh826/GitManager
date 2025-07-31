// lib/services/repository_service.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

// 使用 ChangeNotifier 来通知 UI 刷新
class RepositoryService extends ChangeNotifier {
  final List<String> _repositoryPaths = [];
  String? _selectedRepositoryPath;

  List<String> get repositoryPaths => _repositoryPaths;
  String? get selectedRepositoryPath => _selectedRepositoryPath;

  RepositoryService();

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
      } else {
        // 如果仓库已存在，则直接切换到该仓库
        selectRepository(selectedDirectory);
      }
    }
  }

  // --- 新增方法 ---
  /// 移除一个仓库（关闭标签页）
  void removeRepository(String path) {
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
    }
  }
}