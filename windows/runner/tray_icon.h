#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <windows.h>
#include <shellapi.h>

#include <functional>

// Windows 任务栏托盘图标与右键菜单。
class TrayIcon {
 public:
  // 托盘图标回调消息，由主窗口过程转发给 HandleCallbackMessage。
  static constexpr UINT kCallbackMessage = WM_APP + 1;

  using Action = std::function<void()>;

  TrayIcon() = default;
  ~TrayIcon() = default;
  TrayIcon(const TrayIcon&) = delete;
  TrayIcon& operator=(const TrayIcon&) = delete;

  // 创建托盘图标；owner 用于接收回调消息。
  void Create(HWND owner, Action open_main, Action open_settings, Action exit_app);

  // 移除托盘图标并释放图标资源。
  void Destroy();

  // 处理托盘的鼠标回调消息。
  void HandleCallbackMessage(WPARAM wparam, LPARAM lparam);

 private:
  void ShowMenu();

  HWND owner_ = nullptr;
  NOTIFYICONDATAW data_ = {};
  HICON owned_icon_ = nullptr;
  bool created_ = false;
  Action open_main_;
  Action open_settings_;
  Action exit_app_;
};

#endif  // RUNNER_TRAY_ICON_H_
