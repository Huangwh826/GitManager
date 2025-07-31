// macos/Runner/MainFlutterWindow.swift

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // --- 核心修改: 设置并居中窗口 ---
    // 1. 定义一个标准的 16:9 窗口尺寸
    let windowSize = NSSize(width: 1440, height: 1200)
    
    // 2. 获取主屏幕的尺寸
    if let mainScreen = NSScreen.main {
        let screenFrame = mainScreen.frame
        // 3. 计算窗口的起始点，使其在屏幕上居中
        let windowOrigin = NSPoint(x: (screenFrame.width - windowSize.width) / 2,
                                   y: (screenFrame.height - windowSize.height) / 2)
        // 4. 创建新的窗口 frame
        let windowFrame = NSRect(origin: windowOrigin, size: windowSize)
        self.setFrame(windowFrame, display: true)
    } else {
        // 如果无法获取屏幕信息，则使用一个默认尺寸
        self.setFrame(NSRect(x: 0, y: 0, width: 1440, height: 1200), display: true)
    }
    // --- 修改结束 ---

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}