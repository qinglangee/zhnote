#ifndef RUNNER_FLOATING_BALL_H_
#define RUNNER_FLOATING_BALL_H_

#include <windows.h>

#include <cstdint>
#include <functional>

// Windows 平台上的悬浮球：置顶、无边框、可拖动、点击回到主窗口。
class FloatingBall {
 public:
  using ClickHandler = std::function<void()>;

  static FloatingBall& Instance();

  // 显示悬浮球；main_window 用于点击后恢复主窗口，on_click 为点击回调。
  void Show(HWND main_window, ClickHandler on_click);

  // 隐藏悬浮球（保留窗口资源以便再次显示）。
  void Hide();

  bool IsVisible() const;

  // 设置悬浮球整体不透明度（0.0 - 1.0），立即生效。
  void SetOpacity(double opacity);

  // 应用退出时释放窗口与位图资源。
  void Destroy();

 private:
  FloatingBall() = default;
  ~FloatingBall() = default;
  FloatingBall(const FloatingBall&) = delete;
  FloatingBall& operator=(const FloatingBall&) = delete;

  static LRESULT CALLBACK WindowProc(HWND window,
                                     UINT message,
                                     WPARAM wparam,
                                     LPARAM lparam);

  void CreateWindowIfNeeded();
  void CreateBitmap();
  void Render();
  void ApplyBitmap();
  void MoveTo(int x, int y);
  void ClampToWorkArea(int* x, int* y) const;
  void LoadPosition(int* x, int* y) const;
  void SavePosition() const;
  void ActivateMainWindow();

  void OnLeftButtonDown();
  void OnMouseMove();
  void OnLeftButtonUp();

  HWND window_ = nullptr;
  HWND main_window_ = nullptr;
  ClickHandler on_click_;
  int size_px_ = 0;
  double opacity_ = 1.0;
  HBITMAP bitmap_ = nullptr;
  uint32_t* pixels_ = nullptr;

  bool dragging_ = false;
  bool moved_ = false;
  POINT drag_start_{0, 0};
  POINT window_start_{0, 0};
};

#endif  // RUNNER_FLOATING_BALL_H_
