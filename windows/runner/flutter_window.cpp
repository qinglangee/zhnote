#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>

#include "floating_ball.h"
#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  floating_ball_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "zhnote/floating_ball",
          &flutter::StandardMethodCodec::GetInstance());
  floating_ball_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        if (method == "show") {
          FloatingBall::Instance().Show(GetHandle());
          result->Success();
        } else if (method == "hide") {
          FloatingBall::Instance().Hide();
          result->Success();
        } else if (method == "isVisible") {
          result->Success(
              flutter::EncodableValue(FloatingBall::Instance().IsVisible()));
        } else {
          result->NotImplemented();
        }
      });

  desktop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "zhnote/desktop_actions",
          &flutter::StandardMethodCodec::GetInstance());

  tray_icon_.Create(
      GetHandle(), [this]() { ShowMainWindow(); },
      [this]() { OpenSettingsFromTray(); }, [this]() { QuitApplication(); });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  tray_icon_.Destroy();
  floating_ball_channel_ = nullptr;
  desktop_channel_ = nullptr;
  FloatingBall::Instance().Destroy();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::ShowMainWindow() {
  HWND window = GetHandle();
  if (window == nullptr) {
    return;
  }
  if (IsIconic(window) != FALSE) {
    ShowWindow(window, SW_RESTORE);
  }
  ShowWindow(window, SW_SHOW);
  SetForegroundWindow(window);
}

void FlutterWindow::OpenSettingsFromTray() {
  ShowMainWindow();
  if (desktop_channel_) {
    desktop_channel_->InvokeMethod("openSettings", nullptr);
  }
}

void FlutterWindow::QuitApplication() {
  if (quitting_) {
    return;
  }
  quitting_ = true;
  tray_icon_.Destroy();
  FloatingBall::Instance().Destroy();

  HWND window = GetHandle();
  if (window != nullptr) {
    PostMessageW(window, WM_CLOSE, 0, 0);
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      // 关闭主窗口时只隐藏，保留悬浮球与托盘图标。
      if (quitting_) {
        break;
      }
      ShowWindow(hwnd, SW_HIDE);
      return 0;
    case TrayIcon::kCallbackMessage:
      tray_icon_.HandleCallbackMessage(wparam, lparam);
      return 0;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
