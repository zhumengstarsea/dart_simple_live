# Windows 直播间返回闪退：2026-09-30 诊断

## 结论和适用范围

本次三份 Windows 崩溃转储均在 Flutter 视频纹理绘制路径中读取空指针。
日志已经记录关闭直播间路由，但尚未记录控制器的“播放器关闭”。结合符号化
调用栈和 Flutter #190774，故障符合 Impeller 在路由快照中使用空 Skia 上下文
解析视频纹理的引擎缺陷。

这份结论针对 2026-09-30 21:38、21:47 的三次崩溃。当天更早出现的
`coremessaging.dll`、`permission_handler_windows_plugin.dll` 故障不能据此归为同一原因。

## 证据

- 程序：`D:\simple_live\simple_live_app.exe`，版本 `1.11.7+11107`。
- 系统：Windows 10 22H2，Build 19045。
- 最新软件日志：应用支持目录下的 `log/2026-09-30 21-47-42.log`。
- 21:47:45：进入虎牙直播间，读取到视频和音频参数，开始播放。
- 21:47:47：`CLOSE TO ROUTE /room/detail?roomId=321123`。
- 此后没有控制器销毁或“播放器关闭”记录，仍有音频线程消息。
- Windows 事件 1000：21:38:39、21:47:30、21:47:48 均为
  `flutter_windows.dll + 0x2c4527`，异常 `0xc0000005`。
- 对应转储：`simple_live_app.exe.36748.dmp`、`.31140.dmp`、`.31064.dmp`。
- 使用 Flutter 3.47.1 官方 Windows release PDB，经 DbgHelp 加载，与已安装引擎匹配。
- 三份转储的异常参数都是读取地址 `0x0`，x64 `RCX = 0`。

三份转储均得到以下调用栈前缀：

```text
flutter_windows.dll + 0x2c4527  GrDirectContext::flush + 0x1b
flutter_windows.dll + 0x0eabb1  flutter::EmbedderExternalTextureGL::ResolveTextureSkia + 0x5f
flutter_windows.dll + 0x0ea5ec  flutter::EmbedderExternalTextureGL::ResolveTexture + 0x36
flutter_windows.dll + 0x0ea49b  flutter::EmbedderExternalTextureGL::Paint + 0x85
flutter_windows.dll + 0x546a10  flutter::TextureLayer::Paint + 0xcc
flutter_windows.dll + 0x53e8ee  flutter::ContainerLayer::PaintChildren + 0x62
```

日志中也出现 `Failed to create EGL surface`，但仅凭该消息无法证明它是本次闪退
的直接原因。直接证据是上面的异常位置、空指针和视频纹理绘制调用栈。

未把原始日志或转储加入仓库；其中可能包含设备标识、带签名的播放地址和进程内存。

## 修改

在 `simple_live_app/windows/runner/main.cpp` 创建 `DartProject` 后加入：

```cpp
project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
```

通过 Flutter 3.47.1 的原生 embedding API 选择 Skia，避免 Impeller 路由快照
故障路径。这是 Windows 渲染后端的规避措施，不改变 media_kit 的视频硬解设置。
Release 构建不会读取 `FLUTTER_ENGINE_SWITCH_*` 环境变量，因此不能仅靠启动脚本
给当前 release EXE 设置环境变量来实现同样的效果。

## 验证状态和后续构建

- 已读取新日志并符号化三份独立转储，三次崩溃签名一致。
- 已核对 Flutter 3.47.1 官方头文件，确认 setter 和 `Disabled` 枚举可用。
- `git diff --check` 通过。
- 本机未找到 Flutter/FVM SDK 或 Windows C++ 构建工具链；尚未编译验证本次改动。
- **`D:\simple_live` 中的可执行文件尚未替换，当前安装仍会走旧的渲染路径。**

在配置好仓库固定工具链的 Windows 构建环境中执行：

```powershell
cd simple_live_app
fvm flutter pub get
fvm flutter build windows --release
```

退出软件，备份现有安装，再替换生成的完整 Windows release 包。首次验证保持
日志开启，反复进入正在播放的虎牙直播间并点击左上角返回，也覆盖快速返回、
加载中返回、全屏和小窗恢复。确认无新的事件 1000，并且返回后能记录到
“播放器关闭”和控制器销毁。运行验证完成前不能宣称已彻底修复。

## 上游来源

- [Flutter #190774：Impeller 快照解析 GPU 视频纹理时空上下文崩溃](https://github.com/flutter/flutter/issues/190774)
- [Flutter #191017：向 LayerTree::Flatten 传递 Impeller 上下文的修复](https://github.com/flutter/flutter/pull/191017)
- [Flutter 3.47.1 DartProject API](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/shell/platform/windows/client_wrapper/include/flutter/dart_project.h)
- [Flutter 3.47.1 环境变量开关仅用于 debug/profile](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/shell/platform/common/engine_switches.cc)
