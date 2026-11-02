#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "tray_icon.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void ShowMainWindow();
  void OpenMainPage();
  void OpenSettingsFromTray();
  void QuitApplication();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // 悬浮球控制通道（zhnote/floating_ball）。
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      floating_ball_channel_;

  // 原生到 Dart 的桌面动作通道（zhnote/desktop_actions）。
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      desktop_channel_;

  TrayIcon tray_icon_;

  // 标记用户是通过托盘“退出应用”关闭，避免再次隐藏窗口。
  bool quitting_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
