#include <windows.h>
#include <appmodel.h>
#include <shlobj.h>
#include <shobjidl_core.h>
#include <shlwapi.h>
#include <strsafe.h>
#include <stdio.h>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "user32.lib")

namespace
{
    const CLSID CLSID_OpenZideTerminalHere =
        { 0x4c5d89a5, 0x4e56, 0x48e0, { 0xae, 0x5a, 0x8f, 0x4a, 0x5c, 0x6d, 0x19, 0x72 } };
    const wchar_t* SHELL_LOG_NAME = L"Zide\\shell-extension.log";
    const wchar_t* ZIDE_TERMINAL_AUMID = L"LaurenceGuws.Zide_1gfq4x6kk79tm!ZideTerminal";

    HMODULE g_module = nullptr;
    long g_serverLocks = 0;

    void AppendShellLog(const wchar_t* format, ...)
    {
        wchar_t localAppData[MAX_PATH];
        const auto envLength = GetEnvironmentVariableW(L"LOCALAPPDATA", localAppData, ARRAYSIZE(localAppData));
        if (envLength == 0 || envLength >= ARRAYSIZE(localAppData))
        {
            return;
        }

        wchar_t zideDir[MAX_PATH];
        if (FAILED(StringCchPrintfW(zideDir, ARRAYSIZE(zideDir), L"%s\\Zide", localAppData)))
        {
            return;
        }
        CreateDirectoryW(zideDir, nullptr);

        wchar_t logPath[MAX_PATH];
        if (FAILED(StringCchPrintfW(logPath, ARRAYSIZE(logPath), L"%s\\%s", localAppData, SHELL_LOG_NAME)))
        {
            return;
        }

        HANDLE file = CreateFileW(
            logPath,
            FILE_APPEND_DATA,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            nullptr,
            OPEN_ALWAYS,
            FILE_ATTRIBUTE_NORMAL,
            nullptr);
        if (file == INVALID_HANDLE_VALUE)
        {
            return;
        }

        SYSTEMTIME now;
        GetLocalTime(&now);

        wchar_t message[1024];
        va_list args;
        va_start(args, format);
        const auto bodyHr = StringCchVPrintfW(message, ARRAYSIZE(message), format, args);
        va_end(args);
        if (FAILED(bodyHr))
        {
            CloseHandle(file);
            return;
        }

        wchar_t line[1200];
        const auto lineHr = StringCchPrintfW(
            line,
            ARRAYSIZE(line),
            L"%04u-%02u-%02u %02u:%02u:%02u.%03u pid=%lu tid=%lu %s\r\n",
            now.wYear,
            now.wMonth,
            now.wDay,
            now.wHour,
            now.wMinute,
            now.wSecond,
            now.wMilliseconds,
            GetCurrentProcessId(),
            GetCurrentThreadId(),
            message);
        if (SUCCEEDED(lineHr))
        {
            DWORD bytesWritten = 0;
            WriteFile(file, line, static_cast<DWORD>(wcslen(line) * sizeof(wchar_t)), &bytesWritten, nullptr);
        }

        CloseHandle(file);
    }

    void AddServerLock()
    {
        InterlockedIncrement(&g_serverLocks);
    }

    void ReleaseServerLock()
    {
        InterlockedDecrement(&g_serverLocks);
    }

    HRESULT DuplicateString(const wchar_t* value, LPWSTR* output)
    {
        if (!output)
        {
            return E_POINTER;
        }
        *output = nullptr;
        return SHStrDupW(value, output);
    }

    HRESULT GetModuleDirectory(wchar_t* buffer, size_t bufferCount)
    {
        if (!buffer || bufferCount == 0)
        {
            return E_INVALIDARG;
        }

        const auto length = GetModuleFileNameW(g_module, buffer, static_cast<DWORD>(bufferCount));
        if (length == 0 || length >= bufferCount)
        {
            return HRESULT_FROM_WIN32(GetLastError());
        }

        if (!PathRemoveFileSpecW(buffer))
        {
            return E_FAIL;
        }

        return S_OK;
    }

    HRESULT GetDirectoryFromItem(IShellItem* item, PWSTR* directory)
    {
        if (!item || !directory)
        {
            return E_POINTER;
        }

        *directory = nullptr;
        return item->GetDisplayName(SIGDN_FILESYSPATH, directory);
    }

    HRESULT LaunchPackagedTerminal(const wchar_t* directory)
    {
        wchar_t arguments[2048];
        auto hr = StringCchPrintfW(arguments, ARRAYSIZE(arguments), L"--cwd \"%s\"", directory);
        if (FAILED(hr))
        {
            return hr;
        }

        IApplicationActivationManager* activationManager = nullptr;
        hr = CoCreateInstance(CLSID_ApplicationActivationManager, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&activationManager));
        if (FAILED(hr))
        {
            return hr;
        }

        DWORD processId = 0;
        hr = activationManager->ActivateApplication(ZIDE_TERMINAL_AUMID, arguments, AO_NONE, &processId);
        activationManager->Release();
        AppendShellLog(L"LaunchPackagedTerminal aumid=%s hr=0x%08X pid=%lu", ZIDE_TERMINAL_AUMID, hr, processId);
        return hr;
    }

    HRESULT LaunchTerminalProcess(const wchar_t* directory)
    {
        const auto packagedHr = LaunchPackagedTerminal(directory);
        if (SUCCEEDED(packagedHr))
        {
            return S_OK;
        }
        AppendShellLog(L"LaunchTerminalProcess packaged launch failed hr=0x%08X, falling back to exe launch", packagedHr);

        wchar_t exePath[MAX_PATH];
        auto hr = GetModuleDirectory(exePath, ARRAYSIZE(exePath));
        if (FAILED(hr))
        {
            return hr;
        }

        hr = StringCchCatW(exePath, ARRAYSIZE(exePath), L"\\zide-terminal.exe");
        if (FAILED(hr))
        {
            return hr;
        }

        wchar_t commandLine[2048];
        hr = StringCchPrintfW(commandLine, ARRAYSIZE(commandLine), L"\"%s\" --cwd \"%s\"", exePath, directory);
        if (FAILED(hr))
        {
            return hr;
        }

        STARTUPINFOW startupInfo{};
        startupInfo.cb = sizeof(startupInfo);
        startupInfo.dwFlags = STARTF_USESHOWWINDOW;
        startupInfo.wShowWindow = SW_SHOWNORMAL;

        PROCESS_INFORMATION processInfo{};
        const BOOL created = CreateProcessW(
            exePath,
            commandLine,
            nullptr,
            nullptr,
            FALSE,
            CREATE_UNICODE_ENVIRONMENT,
            nullptr,
            directory,
            &startupInfo,
            &processInfo);
        if (!created)
        {
            AppendShellLog(L"LaunchTerminalProcess CreateProcessW failed err=0x%08X", GetLastError());
            return HRESULT_FROM_WIN32(GetLastError());
        }

        CloseHandle(processInfo.hThread);
        CloseHandle(processInfo.hProcess);
        AppendShellLog(L"LaunchTerminalProcess CreateProcessW ok");
        return S_OK;
    }

    class OpenZideTerminalHere final : public IExplorerCommand, public IObjectWithSite
    {
    public:
        OpenZideTerminalHere() :
            _refCount(1),
            _site(nullptr)
        {
            AddServerLock();
        }

        ~OpenZideTerminalHere()
        {
            if (_site)
            {
                _site->Release();
            }
            ReleaseServerLock();
        }

        IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override
        {
            if (!ppv)
            {
                return E_POINTER;
            }
            *ppv = nullptr;

            if (riid == IID_IUnknown || riid == IID_IExplorerCommand)
            {
                *ppv = static_cast<IExplorerCommand*>(this);
            }
            else if (riid == IID_IObjectWithSite)
            {
                *ppv = static_cast<IObjectWithSite*>(this);
            }
            else
            {
                return E_NOINTERFACE;
            }

            AddRef();
            return S_OK;
        }

        IFACEMETHODIMP_(ULONG) AddRef() override
        {
            return static_cast<ULONG>(InterlockedIncrement(&_refCount));
        }

        IFACEMETHODIMP_(ULONG) Release() override
        {
            const auto remaining = InterlockedDecrement(&_refCount);
            if (remaining == 0)
            {
                delete this;
            }
            return static_cast<ULONG>(remaining);
        }

        IFACEMETHODIMP GetTitle(IShellItemArray*, LPWSTR* name) override
        {
            AppendShellLog(L"GetTitle");
            return DuplicateString(L"Open Zide Terminal here", name);
        }

        IFACEMETHODIMP GetIcon(IShellItemArray*, LPWSTR* icon) override
        {
            wchar_t iconPath[MAX_PATH];
            auto hr = GetModuleDirectory(iconPath, ARRAYSIZE(iconPath));
            if (FAILED(hr))
            {
                return hr;
            }
            hr = StringCchCatW(iconPath, ARRAYSIZE(iconPath), L"\\icons\\zide-terminal.ico");
            if (FAILED(hr))
            {
                return hr;
            }
            return DuplicateString(iconPath, icon);
        }

        IFACEMETHODIMP GetToolTip(IShellItemArray*, LPWSTR* tip) override
        {
            if (tip)
            {
                *tip = nullptr;
            }
            return E_NOTIMPL;
        }

        IFACEMETHODIMP GetCanonicalName(GUID* guidCommandName) override
        {
            if (!guidCommandName)
            {
                return E_POINTER;
            }
            *guidCommandName = CLSID_OpenZideTerminalHere;
            return S_OK;
        }

        IFACEMETHODIMP GetState(IShellItemArray* items, BOOL, EXPCMDSTATE* cmdState) override
        {
            if (!cmdState)
            {
                return E_POINTER;
            }

            IShellItem* item = nullptr;
            const auto hr = GetBestLocation(items, &item);
            if (FAILED(hr) || !item)
            {
                AppendShellLog(L"GetState hidden hr=0x%08X item=%p", hr, item);
                *cmdState = ECS_HIDDEN;
                if (item)
                {
                    item->Release();
                }
                return S_OK;
            }

            SFGAOF attributes = 0;
            const auto attrHr = item->GetAttributes(SFGAO_FILESYSTEM, &attributes);
            item->Release();

            *cmdState = SUCCEEDED(attrHr) && (attributes & SFGAO_FILESYSTEM) ? ECS_ENABLED : ECS_HIDDEN;
            AppendShellLog(L"GetState state=%d attrHr=0x%08X attrs=0x%08X", *cmdState, attrHr, attributes);
            return S_OK;
        }

        IFACEMETHODIMP Invoke(IShellItemArray* items, IBindCtx*) override
        {
            IShellItem* item = nullptr;
            auto hr = GetBestLocation(items, &item);
            if (FAILED(hr) || !item)
            {
                AppendShellLog(L"Invoke failed to resolve location hr=0x%08X item=%p", hr, item);
                if (item)
                {
                    item->Release();
                }
                return hr;
            }

            PWSTR directory = nullptr;
            hr = GetDirectoryFromItem(item, &directory);
            item->Release();
            if (FAILED(hr))
            {
                AppendShellLog(L"Invoke failed to resolve directory hr=0x%08X", hr);
                return hr;
            }

            AppendShellLog(L"Invoke directory=%s", directory);
            hr = LaunchTerminalProcess(directory);
            CoTaskMemFree(directory);
            if (FAILED(hr))
            {
                AppendShellLog(L"Invoke launch failed hr=0x%08X", hr);
                return hr;
            }

            AppendShellLog(L"Invoke launched ok");
            return S_OK;
        }

        IFACEMETHODIMP GetFlags(EXPCMDFLAGS* flags) override
        {
            if (!flags)
            {
                return E_POINTER;
            }
            *flags = ECF_DEFAULT;
            return S_OK;
        }

        IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** commands) override
        {
            if (commands)
            {
                *commands = nullptr;
            }
            return E_NOTIMPL;
        }

        IFACEMETHODIMP SetSite(IUnknown* site) override
        {
            AppendShellLog(L"SetSite site=%p", site);
            if (_site)
            {
                _site->Release();
                _site = nullptr;
            }
            if (site)
            {
                site->AddRef();
                _site = site;
            }
            return S_OK;
        }

        IFACEMETHODIMP GetSite(REFIID riid, void** site) override
        {
            if (!site)
            {
                return E_POINTER;
            }
            *site = nullptr;
            if (!_site)
            {
                return E_FAIL;
            }
            return _site->QueryInterface(riid, site);
        }

    private:
        HRESULT GetLocationFromSite(IShellItem** location) const
        {
            if (!location)
            {
                return E_POINTER;
            }
            *location = nullptr;

            if (!_site)
            {
                AppendShellLog(L"GetLocationFromSite no site");
                return S_FALSE;
            }

            IServiceProvider* serviceProvider = nullptr;
            auto hr = _site->QueryInterface(IID_PPV_ARGS(&serviceProvider));
            if (FAILED(hr))
            {
                AppendShellLog(L"GetLocationFromSite QI IServiceProvider failed hr=0x%08X", hr);
                return hr;
            }

            IFolderView* folderView = nullptr;
            hr = serviceProvider->QueryService(SID_SFolderView, IID_PPV_ARGS(&folderView));
            serviceProvider->Release();
            if (FAILED(hr))
            {
                AppendShellLog(L"GetLocationFromSite QueryService SID_SFolderView failed hr=0x%08X", hr);
                return hr;
            }

            hr = folderView->GetFolder(IID_PPV_ARGS(location));
            folderView->Release();
            AppendShellLog(L"GetLocationFromSite GetFolder hr=0x%08X location=%p", hr, location ? *location : nullptr);
            return hr;
        }

        HRESULT GetBestLocation(IShellItemArray* items, IShellItem** location) const
        {
            if (!location)
            {
                return E_POINTER;
            }
            *location = nullptr;

            if (items)
            {
                DWORD count = 0;
                if (SUCCEEDED(items->GetCount(&count)) && count > 0)
                {
                    AppendShellLog(L"GetBestLocation using selection count=%lu", count);
                    return items->GetItemAt(0, location);
                }
                AppendShellLog(L"GetBestLocation empty selection count=%lu", count);
            }

            AppendShellLog(L"GetBestLocation falling back to site");
            return GetLocationFromSite(location);
        }

        long _refCount;
        IUnknown* _site;
    };

    class OpenZideTerminalHereClassFactory final : public IClassFactory
    {
    public:
        OpenZideTerminalHereClassFactory() : _refCount(1)
        {
            AddServerLock();
        }

        ~OpenZideTerminalHereClassFactory()
        {
            ReleaseServerLock();
        }

        IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override
        {
            if (!ppv)
            {
                return E_POINTER;
            }
            *ppv = nullptr;

            if (riid == IID_IUnknown || riid == IID_IClassFactory)
            {
                *ppv = static_cast<IClassFactory*>(this);
                AddRef();
                return S_OK;
            }

            return E_NOINTERFACE;
        }

        IFACEMETHODIMP_(ULONG) AddRef() override
        {
            return static_cast<ULONG>(InterlockedIncrement(&_refCount));
        }

        IFACEMETHODIMP_(ULONG) Release() override
        {
            const auto remaining = InterlockedDecrement(&_refCount);
            if (remaining == 0)
            {
                delete this;
            }
            return static_cast<ULONG>(remaining);
        }

        IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** ppv) override
        {
            if (outer)
            {
                return CLASS_E_NOAGGREGATION;
            }

            auto* command = new OpenZideTerminalHere();
            if (!command)
            {
                return E_OUTOFMEMORY;
            }

            const auto hr = command->QueryInterface(riid, ppv);
            command->Release();
            return hr;
        }

        IFACEMETHODIMP LockServer(BOOL lock) override
        {
            if (lock)
            {
                AddServerLock();
            }
            else
            {
                ReleaseServerLock();
            }
            return S_OK;
        }

    private:
        long _refCount;
    };
}

extern "C" __declspec(dllexport) HRESULT __stdcall DllCanUnloadNow(void)
{
    return g_serverLocks == 0 ? S_OK : S_FALSE;
}

extern "C" __declspec(dllexport) HRESULT __stdcall DllGetClassObject(REFCLSID rclsid, REFIID riid, void** ppv)
{
    AppendShellLog(
        L"DllGetClassObject clsid=%08lX-%04X-%04X riid=%08lX-%04X-%04X",
        rclsid.Data1,
        rclsid.Data2,
        rclsid.Data3,
        riid.Data1,
        riid.Data2,
        riid.Data3);
    if (rclsid != CLSID_OpenZideTerminalHere)
    {
        return CLASS_E_CLASSNOTAVAILABLE;
    }

    auto* factory = new OpenZideTerminalHereClassFactory();
    if (!factory)
    {
        return E_OUTOFMEMORY;
    }

    const auto hr = factory->QueryInterface(riid, ppv);
    factory->Release();
    return hr;
}

extern "C" BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        g_module = instance;
        DisableThreadLibraryCalls(instance);
        AppendShellLog(L"DllMain process_attach");
    }
    return TRUE;
}
