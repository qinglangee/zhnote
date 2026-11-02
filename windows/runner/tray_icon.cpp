#include "tray_icon.h"

#include <utility>

#include "resource.h"

namespace {

constexpr UINT kMenuOpenMain = 1;
constexpr UINT kMenuOpenSettings = 2;
constexpr UINT kMenuExit = 3;

}  // namespace

void TrayIcon::Create(HWND owner,
                      Action open_main,
                      Action open_settings,
                      Action exit_app) {
  if (created_) {
    return;
  }

  owner_ = owner;
  open_main_ = std::move(open_main);
  open_settings_ = std::move(open_settings);
  exit_app_ = std::move(exit_app);

  data_ = {};
  data_.cbSize = sizeof(NOTIFYICONDATAW);
  data_.hWnd = owner_;
  data_.uID = 1;
  data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  data_.uCallbackMessage = kCallbackMessage;

  const int icon_size = GetSystemMetrics(SM_CXSMICON);
  HICON icon = static_cast<HICON>(LoadImageW(
      GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
      icon_size, icon_size, LR_DEFAULTCOLOR));
  if (icon == nullptr) {
    icon = LoadIconW(nullptr, IDI_APPLICATION);
  } else {
    owned_icon_ = icon;
  }
  data_.hIcon = icon;
  lstrcpynW(data_.szTip, L"zhnote", ARRAYSIZE(data_.szTip));

  created_ = Shell_NotifyIconW(NIM_ADD, &data_) != FALSE;
}

void TrayIcon::Destroy() {
  if (created_) {
    Shell_NotifyIconW(NIM_DELETE, &data_);
    created_ = false;
  }
  if (owned_icon_ != nullptr) {
    DestroyIcon(owned_icon_);
    owned_icon_ = nullptr;
    data_.hIcon = nullptr;
  }
  owner_ = nullptr;
  open_main_ = nullptr;
  open_settings_ = nullptr;
  exit_app_ = nullptr;
}

void TrayIcon::HandleCallbackMessage(WPARAM wparam, LPARAM lparam) {
  if (!created_) {
    return;
  }
  switch (LOWORD(lparam)) {
    case WM_LBUTTONUP:
    case WM_LBUTTONDBLCLK:
      if (open_main_) {
        open_main_();
      }
      break;
    case WM_RBUTTONUP:
    case WM_CONTEXTMENU:
      ShowMenu();
      break;
    default:
      break;
  }
}

void TrayIcon::ShowMenu() {
  if (owner_ == nullptr) {
    return;
  }

  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }
  AppendMenuW(menu, MF_STRING, kMenuOpenMain, L"打开主页面");
  AppendMenuW(menu, MF_STRING, kMenuOpenSettings, L"设置页面");
  AppendMenuW(menu, MF_SEPARATOR, 0u, nullptr);
  AppendMenuW(menu, MF_STRING, kMenuExit, L"退出应用");

  // 先激活 owner，保证点击菜单外部时菜单能正常关闭。
  SetForegroundWindow(owner_);
  POINT cursor = {};
  GetCursorPos(&cursor);
  const UINT command = static_cast<UINT>(
      TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_NONOTIFY,
                     cursor.x, cursor.y, 0, owner_, nullptr));
  DestroyMenu(menu);
  PostMessageW(owner_, WM_NULL, 0, 0);

  if (command == kMenuOpenMain && open_main_) {
    open_main_();
  } else if (command == kMenuOpenSettings && open_settings_) {
    open_settings_();
  } else if (command == kMenuExit && exit_app_) {
    exit_app_();
  }
}
