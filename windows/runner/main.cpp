#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr const wchar_t kMutexName[] = L"Local\\LightSend_SingleInstance";
constexpr const wchar_t kWindowTitle[] = L"LightSend";
constexpr const wchar_t kWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // ─── Single-instance check ──────────────────────────────────────────────
  HANDLE hMutex = CreateMutexW(nullptr, TRUE, kMutexName);
  if (hMutex == nullptr) {
    return EXIT_FAILURE;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND hExisting = FindWindowW(kWindowClass, kWindowTitle);
    if (hExisting != nullptr) {
      // Parse command-line args (skip exe path)
      int argc = 0;
      LPWSTR* argv = CommandLineToArgvW(command_line, &argc);
      if (argv != nullptr && argc > 1) {
        std::wstring args;
        for (int i = 1; i < argc; i++) {
          if (i > 1) args += L'\n';
          args += argv[i];
        }
        LocalFree(argv);

        COPYDATASTRUCT cds = {};
        cds.dwData = 1;
        cds.cbData =
            static_cast<DWORD>((args.length() + 1) * sizeof(wchar_t));
        cds.lpData = const_cast<wchar_t*>(args.c_str());
        SendMessageW(hExisting, WM_COPYDATA, 0,
                     reinterpret_cast<LPARAM>(&cds));
      }

      // Bring existing window to foreground
      if (IsIconic(hExisting)) ShowWindow(hExisting, SW_RESTORE);
      SetForegroundWindow(hExisting);
    }

    CloseHandle(hMutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    CloseHandle(hMutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  CloseHandle(hMutex);
  return EXIT_SUCCESS;
}
