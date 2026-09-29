/// 应用自己维护的「桌面窗口是否处于全屏」。
///
/// 为什么需要它：
/// window_manager 的 isFullScreen() 是一次跨到引擎窗口管理器的方法通道调用。
/// Windows 上「鼠标侧键返回」这种高频路径每次都去查询它，会偶发让整个进程
/// 直接挂掉（不是抛异常，是 fail-fast / 访问冲突），WER 里表现为：
///   flutter_windows.dll + 0x2c4527  (c0000005 访问冲突)
///   coremessaging.dll  + 0x73326   (c0000602 fail-fast)
/// 而且崩溃点早于 Get.back()，所以应用日志里连一行路由关闭都看不到 ——
/// 这也是这个 bug 一直很难定位的原因。
///
/// 全屏只可能是本应用自己设置的，所以状态自己记就够了：
/// 只有真正调用 windowManager.setFullScreen() 的地方才更新这里，
/// 返回路径直接读这个变量，不再向引擎查询。
class AppWindowState {
  AppWindowState._();

  static bool _isFullScreen = false;

  /// 当前窗口是否处于应用设置的全屏状态。
  static bool get isFullScreen => _isFullScreen;

  /// 与 windowManager.setFullScreen() 同步调用，记录状态变更。
  static void markFullScreen(bool value) {
    _isFullScreen = value;
  }
}
