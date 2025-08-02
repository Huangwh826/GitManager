// lib/widgets/window_title_bar.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// 一个自定义的窗口标题栏，集成了标签页、操作按钮和窗口控件。
class WindowTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? tabController;
  final List<String> repositoryPaths;
  final VoidCallback onAddRepository;
  final Function(int) onCloseRepository;

  const WindowTitleBar({
    super.key,
    required this.tabController,
    required this.repositoryPaths,
    required this.onAddRepository,
    required this.onCloseRepository,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor ?? const Color(0xFF111827),
      ),
      child: Row(
        children: [
          // 左侧的标签页区域
          Expanded(
            child: MoveWindow( // 允许通过拖动这部分来移动窗口
              child: Row(
                children: [
                  const SizedBox(width: 16), // 左侧留白
                  Expanded(
                    child: (repositoryPaths.isNotEmpty && tabController != null)
                        ? Align(
                      alignment: Alignment.bottomLeft,
                      child: TabBar(
                        controller: tabController,
                        isScrollable: true,
                        indicatorWeight: 2,
                        indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
                        indicatorColor: Colors.blueAccent,
                        tabs: repositoryPaths
                            .asMap()
                            .entries
                            .map((entry) => _buildTab(context, entry.key, entry.value))
                            .toList(),
                      ),
                    )
                        : Container(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: onAddRepository,
                    tooltip: '添加本地仓库',
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          // 右侧的窗口控制按钮
          const WindowButtons(),
        ],
      ),
    );
  }

  /// 构建自定义标签组件
  Widget _buildTab(BuildContext context, int index, String path) {
    final fileName = path.split(Platform.isWindows ? '\\' : '/').last;
    final isActive = tabController?.index == index;

    return Tooltip(
      message: path, // 显示完整路径作为悬停提示
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // 标签文本
            Text(
              fileName,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // 关闭按钮
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              onPressed: () => onCloseRepository(index),
              splashRadius: 14,
              padding: EdgeInsets.zero,
              tooltip: '关闭此仓库',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

/// 窗口控制按钮 (最小化, 最大化, 关闭)
class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: Colors.grey,
      mouseOver: const Color(0xFF4A5568),
      mouseDown: const Color(0xFF2D3748),
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFE53E3E),
      mouseDown: const Color(0xFFC53030),
      iconNormal: Colors.grey,
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}
