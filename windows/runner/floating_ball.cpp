#include "floating_ball.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>

namespace {

constexpr int kLogicalSize = 64;
constexpr int kDragThreshold = 4;
constexpr wchar_t kWindowClassName[] = L"ZhNoteFloatingBall";

double Clamp01(double value) {
  if (value < 0.0) {
    return 0.0;
  }
  if (value > 1.0) {
    return 1.0;
  }
  return value;
}

// 计算点到一条水平胶囊（圆角矩形线段）的覆盖度，用于抗锯齿。
double CapsuleCoverage(double px,
                       double py,
                       double left,
                       double right,
                       double center_y,
                       double radius) {
  double dx = 0.0;
  if (px < left) {
    dx = left - px;
  } else if (px > right) {
    dx = px - right;
  }
  const double dy = py - center_y;
  const double distance = std::sqrt(dx * dx + dy * dy);
  return Clamp01(radius - distance + 0.5);
}

std::wstring PositionFilePath() {
  wchar_t buffer[MAX_PATH];
  const DWORD length = GetEnvironmentVariableW(L"APPDATA", buffer, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return std::wstring();
  }
  std::wstring directory(buffer, length);
  directory += L"\\zhnote";
  CreateDirectoryW(directory.c_str(), nullptr);
  return directory + L"\\ball_position.txt";
}

int SystemDpi() {
  HDC screen_dc = GetDC(nullptr);
  const int dpi = GetDeviceCaps(screen_dc, LOGPIXELSX);
  ReleaseDC(nullptr, screen_dc);
  return dpi <= 0 ? 96 : dpi;
}

}  // namespace

FloatingBall& FloatingBall::Instance() {
  static FloatingBall instance;
  return instance;
}

void FloatingBall::Show(HWND main_window, ClickHandler on_click) {
  main_window_ = main_window;
  on_click_ = on_click;
  CreateWindowIfNeeded();
  if (!window_) {
    return;
  }
  ApplyBitmap();
  ShowWindow(window_, SW_SHOWNA);
  SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

void FloatingBall::Hide() {
  if (window_) {
    ShowWindow(window_, SW_HIDE);
  }
}

bool FloatingBall::IsVisible() const {
  return window_ != nullptr && IsWindowVisible(window_) != FALSE;
}

void FloatingBall::Destroy() {
  if (window_) {
    DestroyWindow(window_);
    window_ = nullptr;
  }
  if (bitmap_) {
    DeleteObject(bitmap_);
    bitmap_ = nullptr;
    pixels_ = nullptr;
  }
  dragging_ = false;
  main_window_ = nullptr;
}

void FloatingBall::CreateWindowIfNeeded() {
  if (window_) {
    return;
  }

  static bool class_registered = false;
  HINSTANCE instance = GetModuleHandleW(nullptr);
  if (!class_registered) {
    WNDCLASSEXW window_class = {};
    window_class.cbSize = sizeof(window_class);
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.lpfnWndProc = &FloatingBall::WindowProc;
    window_class.hInstance = instance;
    window_class.hCursor = LoadCursorW(nullptr, IDC_HAND);
    window_class.lpszClassName = kWindowClassName;
    if (!RegisterClassExW(&window_class)) {
      return;
    }
    class_registered = true;
  }

  const int dpi = SystemDpi();
  size_px_ = MulDiv(kLogicalSize, dpi, 96);
  if (size_px_ < 32) {
    size_px_ = 32;
  }

  int x = 0;
  int y = 0;
  LoadPosition(&x, &y);
  ClampToWorkArea(&x, &y);

  window_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_NOACTIVATE,
      kWindowClassName, L"", WS_POPUP, x, y, size_px_, size_px_, nullptr,
      nullptr, instance, this);
  if (!window_) {
    return;
  }

  CreateBitmap();
  Render();
}

void FloatingBall::CreateBitmap() {
  HDC screen_dc = GetDC(nullptr);
  BITMAPINFO bitmap_info = {};
  bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmap_info.bmiHeader.biWidth = size_px_;
  bitmap_info.bmiHeader.biHeight = -size_px_;
  bitmap_info.bmiHeader.biPlanes = 1;
  bitmap_info.bmiHeader.biBitCount = 32;
  bitmap_info.bmiHeader.biCompression = BI_RGB;

  void* bits = nullptr;
  bitmap_ = CreateDIBSection(screen_dc, &bitmap_info, DIB_RGB_COLORS, &bits,
                             nullptr, 0);
  ReleaseDC(nullptr, screen_dc);
  pixels_ = static_cast<uint32_t*>(bits);
}

void FloatingBall::Render() {
  if (pixels_ == nullptr || size_px_ <= 0) {
    return;
  }

  const int size = size_px_;
  const double center = size / 2.0;
  const double radius = center - 2.0;
  const double bar_half_width = size * 0.20;
  const double bar_radius = size * 0.040;
  const double bar_spacing = size * 0.14;

  for (int y = 0; y < size; ++y) {
    for (int x = 0; x < size; ++x) {
      const double px = x + 0.5;
      const double py = y + 0.5;
      const double dx = px - center;
      const double dy = py - center;
      const double distance = std::sqrt(dx * dx + dy * dy);
      const double alpha = Clamp01(radius - distance + 0.5);

      double red = 63.0;
      double green = 81.0;
      double blue = 181.0;

      if (alpha > 0.0) {
        // 左上角提亮的球体渐变。
        const double glow = Clamp01(1.0 - distance / radius);
        const double lighten = glow * glow * 0.35;
        red += (255.0 - red) * lighten;
        green += (255.0 - green) * lighten;
        blue += (255.0 - blue) * lighten;

        // 三条白色横线组成的“笔记”图形。
        double bar = 0.0;
        for (int index = -1; index <= 1; ++index) {
          const double bar_center_y = center + index * bar_spacing;
          bar = std::max(
              bar, CapsuleCoverage(px, py, center - bar_half_width,
                                   center + bar_half_width, bar_center_y,
                                   bar_radius));
        }
        red += (255.0 - red) * bar;
        green += (255.0 - green) * bar;
        blue += (255.0 - blue) * bar;
      }

      const uint32_t alpha_byte =
          static_cast<uint32_t>(std::lround(alpha * 255.0));
      const uint32_t red_byte =
          static_cast<uint32_t>(std::lround(alpha * red));
      const uint32_t green_byte =
          static_cast<uint32_t>(std::lround(alpha * green));
      const uint32_t blue_byte =
          static_cast<uint32_t>(std::lround(alpha * blue));

      // UpdateLayeredWindow 需要预乘 alpha 的 BGRA 数据。
      pixels_[y * size + x] =
          (alpha_byte << 24) | (red_byte << 16) | (green_byte << 8) | blue_byte;
    }
  }
}

void FloatingBall::ApplyBitmap() {
  if (!window_) {
    return;
  }
  RECT rect = {};
  GetWindowRect(window_, &rect);
  MoveTo(rect.left, rect.top);
}

void FloatingBall::MoveTo(int x, int y) {
  if (!window_ || !bitmap_) {
    return;
  }
  HDC screen_dc = GetDC(nullptr);
  HDC memory_dc = CreateCompatibleDC(screen_dc);
  HGDIOBJ previous = SelectObject(memory_dc, bitmap_);
  POINT source = {0, 0};
  SIZE size = {size_px_, size_px_};
  POINT destination = {x, y};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  UpdateLayeredWindow(window_, screen_dc, &destination, &size, memory_dc,
                      &source, 0, &blend, ULW_ALPHA);
  SelectObject(memory_dc, previous);
  DeleteDC(memory_dc);
  ReleaseDC(nullptr, screen_dc);
}

void FloatingBall::ClampToWorkArea(int* x, int* y) const {
  POINT probe = {*x + size_px_ / 2, *y + size_px_ / 2};
  HMONITOR monitor = MonitorFromPoint(probe, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info = {};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(monitor, &info)) {
    return;
  }
  const RECT& work = info.rcWork;
  const int maximum_x = work.right - size_px_;
  const int maximum_y = work.bottom - size_px_;
  if (*x < work.left) {
    *x = work.left;
  }
  if (*y < work.top) {
    *y = work.top;
  }
  if (*x > maximum_x) {
    *x = maximum_x;
  }
  if (*y > maximum_y) {
    *y = maximum_y;
  }
}

void FloatingBall::LoadPosition(int* x, int* y) const {
  bool loaded = false;
  const std::wstring path = PositionFilePath();
  if (!path.empty()) {
    FILE* file = nullptr;
    if (_wfopen_s(&file, path.c_str(), L"rb") == 0 && file != nullptr) {
      int saved_x = 0;
      int saved_y = 0;
      if (fscanf_s(file, "%d %d", &saved_x, &saved_y) == 2) {
        *x = saved_x;
        *y = saved_y;
        loaded = true;
      }
      fclose(file);
    }
  }

  if (loaded) {
    return;
  }

  HMONITOR monitor = MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO info = {};
  info.cbSize = sizeof(info);
  if (GetMonitorInfoW(monitor, &info)) {
    const RECT& work = info.rcWork;
    const int margin = MulDiv(16, SystemDpi(), 96);
    *x = work.right - size_px_ - margin;
    *y = work.top + (work.bottom - work.top - size_px_) / 2;
  }
}

void FloatingBall::SavePosition() const {
  if (!window_) {
    return;
  }
  const std::wstring path = PositionFilePath();
  if (path.empty()) {
    return;
  }
  RECT rect = {};
  if (!GetWindowRect(window_, &rect)) {
    return;
  }
  FILE* file = nullptr;
  if (_wfopen_s(&file, path.c_str(), L"wb") == 0 && file != nullptr) {
    std::fprintf(file, "%d %d", static_cast<int>(rect.left),
                 static_cast<int>(rect.top));
    fclose(file);
  }
}

void FloatingBall::ActivateMainWindow() {
  if (main_window_ == nullptr || IsWindow(main_window_) == FALSE) {
    return;
  }
  if (IsIconic(main_window_) != FALSE) {
    ShowWindow(main_window_, SW_RESTORE);
  } else {
    ShowWindow(main_window_, SW_SHOW);
  }
  SetForegroundWindow(main_window_);
}

void FloatingBall::OnLeftButtonDown() {
  dragging_ = true;
  moved_ = false;
  GetCursorPos(&drag_start_);
  RECT rect = {};
  if (GetWindowRect(window_, &rect)) {
    window_start_.x = rect.left;
    window_start_.y = rect.top;
  }
  SetCapture(window_);
}

void FloatingBall::OnMouseMove() {
  if (!dragging_ || !window_) {
    return;
  }
  POINT cursor = {};
  GetCursorPos(&cursor);
  const int dx = cursor.x - drag_start_.x;
  const int dy = cursor.y - drag_start_.y;
  if (std::abs(dx) > kDragThreshold || std::abs(dy) > kDragThreshold) {
    moved_ = true;
  }
  int x = window_start_.x + dx;
  int y = window_start_.y + dy;
  ClampToWorkArea(&x, &y);
  MoveTo(x, y);
}

void FloatingBall::OnLeftButtonUp() {
  if (!dragging_) {
    return;
  }
  dragging_ = false;
  ReleaseCapture();
  if (moved_) {
    SavePosition();
  } else if (on_click_) {
    on_click_();
  } else {
    ActivateMainWindow();
  }
}

LRESULT CALLBACK FloatingBall::WindowProc(HWND window,
                                          UINT message,
                                          WPARAM wparam,
                                          LPARAM lparam) {
  if (message == WM_NCCREATE) {
    CREATESTRUCTW* create_struct = reinterpret_cast<CREATESTRUCTW*>(lparam);
    SetWindowLongPtrW(window, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(create_struct->lpCreateParams));
  }

  FloatingBall* self = reinterpret_cast<FloatingBall*>(
      GetWindowLongPtrW(window, GWLP_USERDATA));
  if (self == nullptr) {
    return DefWindowProcW(window, message, wparam, lparam);
  }

  switch (message) {
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_LBUTTONDOWN:
      self->OnLeftButtonDown();
      return 0;
    case WM_MOUSEMOVE:
      self->OnMouseMove();
      return 0;
    case WM_LBUTTONUP:
      self->OnLeftButtonUp();
      return 0;
    case WM_DESTROY:
      return 0;
    default:
      break;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}
