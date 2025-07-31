// lib/widgets/window_title_bar.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// 一个自定义的窗口标题栏，集成了标签页、操作按钮和窗口控件。
class WindowTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? tabController;
  final List<String> repositoryPaths;
  final VoidCallback onAddRepository;

  const WindowTitleBar({
    super.key,
    required this.tabController,
    required this.repositoryPaths,
    required this.onAddRepository,
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
                            .map((path) => Tab(text: path.split(Platform.isWindows ? '\\' : '/').last))
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
