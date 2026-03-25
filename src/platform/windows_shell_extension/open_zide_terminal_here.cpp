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
    enum class CommandTargetKind
    {
        File,
        Directory,
    };

    enum class CommandLaunchArgs
    {
        None,
        PositionalPath,
        FolderFlag,
        TerminalCwd,
    };

    struct CommandSpec
    {
        const CLSID* clsid;
        const wchar_t* title;
        const wchar_t* icon_relative_path;
        CommandTargetKind target_kind;
        bool allow_background;
        const wchar_t* packaged_aumid;
        const wchar_t* fallback_exe_name;
        CommandLaunchArgs launch_args;
        const CommandSpec* const* subcommands;
        size_t subcommand_count;
    };

    const CLSID CLSID_ZideFileMenu =
        { 0x7a4a9f94, 0x7a56, 0x4b72, { 0x9d, 0x3a, 0x0e, 0x4f, 0x1a, 0x0e, 0x6e, 0x11 } };
    const CLSID CLSID_ZideFolderMenu =
        { 0x7d8e995a, 0x2d37, 0x48d8, { 0xab, 0x12, 0x4f, 0x03, 0xc6, 0x36, 0x2d, 0x85 } };
    const CLSID CLSID_OpenZideTerminalHere =
        { 0x4c5d89a5, 0x4e56, 0x48e0, { 0xae, 0x5a, 0x8f, 0x4a, 0x5c, 0x6d, 0x19, 0x72 } };
    const CLSID CLSID_OpenInZideFile =
        { 0xf8d79d0d, 0x7d4f, 0x4b53, { 0xbb, 0x41, 0x38, 0xc8, 0xd2, 0xd4, 0xca, 0x73 } };
    const CLSID CLSID_OpenInZideEditorFile =
        { 0x3485602e, 0x6607, 0x4c10, { 0x8d, 0x0a, 0x41, 0x28, 0x7d, 0x13, 0xe1, 0x38 } };
    const CLSID CLSID_OpenInZideFolder =
        { 0x99e1c4a2, 0x71b0, 0x4bce, { 0x98, 0x3b, 0x5b, 0x9c, 0x87, 0x9d, 0x69, 0xfe } };

    const wchar_t* SHELL_LOG_NAME = L"Zide\\shell-extension.log";
    const wchar_t* ZIDE_AUMID = L"LaurenceGuws.Zide_1gfq4x6kk79tm!Zide";
    const wchar_t* ZIDE_EDITOR_AUMID = L"LaurenceGuws.Zide_1gfq4x6kk79tm!ZideEditor";
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

    bool IsLeafCommand(const CommandSpec& spec)
    {
        return spec.subcommand_count == 0;
    }

    HRESULT GetPathFromItem(IShellItem* item, PWSTR* path)
    {
        if (!item || !path)
        {
            return E_POINTER;
        }

        *path = nullptr;
        return item->GetDisplayName(SIGDN_FILESYSPATH, path);
    }

    HRESULT GetWorkingDirectory(const wchar_t* targetPath, CommandTargetKind targetKind, wchar_t* buffer, size_t bufferCount)
    {
        if (!targetPath || !buffer || bufferCount == 0)
        {
            return E_INVALIDARG;
        }

        auto hr = StringCchCopyW(buffer, bufferCount, targetPath);
        if (FAILED(hr))
        {
            return hr;
        }

        if (targetKind == CommandTargetKind::Directory)
        {
            return S_OK;
        }

        if (!PathRemoveFileSpecW(buffer))
        {
            return E_FAIL;
        }

        return S_OK;
    }

    HRESULT BuildLaunchArguments(const CommandSpec& spec, const wchar_t* targetPath, wchar_t* buffer, size_t bufferCount)
    {
        if (!targetPath || !buffer || bufferCount == 0)
        {
            return E_INVALIDARG;
        }

        switch (spec.launch_args)
        {
        case CommandLaunchArgs::PositionalPath:
            return StringCchPrintfW(buffer, bufferCount, L"\"%s\"", targetPath);
        case CommandLaunchArgs::FolderFlag:
            return StringCchPrintfW(buffer, bufferCount, L"--folder \"%s\"", targetPath);
        case CommandLaunchArgs::TerminalCwd:
            return StringCchPrintfW(buffer, bufferCount, L"--cwd \"%s\"", targetPath);
        case CommandLaunchArgs::None:
        default:
            return E_FAIL;
        }
    }

    HRESULT LaunchPackagedApplication(const CommandSpec& spec, const wchar_t* targetPath)
    {
        wchar_t arguments[2048];
        auto hr = BuildLaunchArguments(spec, targetPath, arguments, ARRAYSIZE(arguments));
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
        hr = activationManager->ActivateApplication(spec.packaged_aumid, arguments, AO_NONE, &processId);
        activationManager->Release();
        AppendShellLog(L"LaunchPackagedApplication title=%s aumid=%s hr=0x%08X pid=%lu", spec.title, spec.packaged_aumid, hr, processId);
        return hr;
    }

    HRESULT LaunchFallbackProcess(const CommandSpec& spec, const wchar_t* targetPath)
    {
        const auto packagedHr = LaunchPackagedApplication(spec, targetPath);
        if (SUCCEEDED(packagedHr))
        {
            return S_OK;
        }
        AppendShellLog(L"LaunchFallbackProcess title=%s packaged launch failed hr=0x%08X", spec.title, packagedHr);

        wchar_t exePath[MAX_PATH];
        auto hr = GetModuleDirectory(exePath, ARRAYSIZE(exePath));
        if (FAILED(hr))
        {
            return hr;
        }

        hr = StringCchCatW(exePath, ARRAYSIZE(exePath), L"\\");
        if (FAILED(hr))
        {
            return hr;
        }

        hr = StringCchCatW(exePath, ARRAYSIZE(exePath), spec.fallback_exe_name);
        if (FAILED(hr))
        {
            return hr;
        }

        wchar_t launchArgs[2048];
        hr = BuildLaunchArguments(spec, targetPath, launchArgs, ARRAYSIZE(launchArgs));
        if (FAILED(hr))
        {
            return hr;
        }

        wchar_t commandLine[2304];
        hr = StringCchPrintfW(commandLine, ARRAYSIZE(commandLine), L"\"%s\" %s", exePath, launchArgs);
        if (FAILED(hr))
        {
            return hr;
        }

        wchar_t workingDirectory[MAX_PATH];
        hr = GetWorkingDirectory(targetPath, spec.target_kind, workingDirectory, ARRAYSIZE(workingDirectory));
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
            workingDirectory,
            &startupInfo,
            &processInfo);
        if (!created)
        {
            AppendShellLog(L"LaunchFallbackProcess title=%s CreateProcessW failed err=0x%08X", spec.title, GetLastError());
            return HRESULT_FROM_WIN32(GetLastError());
        }

        CloseHandle(processInfo.hThread);
        CloseHandle(processInfo.hProcess);
        AppendShellLog(L"LaunchFallbackProcess title=%s CreateProcessW ok", spec.title);
        return S_OK;
    }

    HRESULT ItemMatchesCommandTarget(IShellItem* item, const CommandSpec& spec)
    {
        if (!item)
        {
            return E_POINTER;
        }

        SFGAOF attributes = 0;
        const auto hr = item->GetAttributes(SFGAO_FILESYSTEM | SFGAO_FOLDER, &attributes);
        if (FAILED(hr))
        {
            return hr;
        }

        if ((attributes & SFGAO_FILESYSTEM) == 0)
        {
            return S_FALSE;
        }

        const bool isDirectory = (attributes & SFGAO_FOLDER) != 0;
        if (spec.target_kind == CommandTargetKind::Directory)
        {
            return isDirectory ? S_OK : S_FALSE;
        }

        return isDirectory ? S_FALSE : S_OK;
    }

    class ExplorerCommand;

    class ExplorerCommandEnumerator final : public IEnumExplorerCommand
    {
    public:
        ExplorerCommandEnumerator(IExplorerCommand** commands, UINT count) :
            _refCount(1),
            _count(count),
            _index(0)
        {
            for (UINT i = 0; i < count; i += 1)
            {
                _commands[i] = commands[i];
                if (_commands[i])
                {
                    _commands[i]->AddRef();
                }
            }
            AddServerLock();
        }

        ~ExplorerCommandEnumerator()
        {
            for (UINT i = 0; i < _count; i += 1)
            {
                if (_commands[i])
                {
                    _commands[i]->Release();
                }
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

            if (riid == IID_IUnknown || riid == IID_IEnumExplorerCommand)
            {
                *ppv = static_cast<IEnumExplorerCommand*>(this);
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

        IFACEMETHODIMP Next(ULONG celt, IExplorerCommand** pUICommand, ULONG* pceltFetched) override
        {
            if (!pUICommand)
            {
                return E_POINTER;
            }

            ULONG fetched = 0;
            while (fetched < celt && _index < _count)
            {
                pUICommand[fetched] = _commands[_index];
                if (pUICommand[fetched])
                {
                    pUICommand[fetched]->AddRef();
                }
                fetched += 1;
                _index += 1;
            }

            if (pceltFetched)
            {
                *pceltFetched = fetched;
            }

            return fetched == celt ? S_OK : S_FALSE;
        }

        IFACEMETHODIMP Skip(ULONG celt) override
        {
            _index = (_index + celt > _count) ? _count : _index + celt;
            return _index < _count ? S_OK : S_FALSE;
        }

        IFACEMETHODIMP Reset() override
        {
            _index = 0;
            return S_OK;
        }

        IFACEMETHODIMP Clone(IEnumExplorerCommand** ppenum) override
        {
            if (!ppenum)
            {
                return E_POINTER;
            }
            *ppenum = nullptr;

            auto* clone = new ExplorerCommandEnumerator(_commands, _count);
            if (!clone)
            {
                return E_OUTOFMEMORY;
            }
            clone->_index = _index;
            *ppenum = clone;
            return S_OK;
        }

    private:
        long _refCount;
        IExplorerCommand* _commands[4]{};
        UINT _count;
        UINT _index;
    };

    class ExplorerCommand final : public IExplorerCommand, public IObjectWithSite
    {
    public:
        explicit ExplorerCommand(const CommandSpec& spec) :
            _refCount(1),
            _site(nullptr),
            _spec(spec)
        {
            AddServerLock();
        }

        ~ExplorerCommand()
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
            AppendShellLog(L"GetTitle title=%s", _spec.title);
            return DuplicateString(_spec.title, name);
        }

        IFACEMETHODIMP GetIcon(IShellItemArray*, LPWSTR* icon) override
        {
            wchar_t iconPath[MAX_PATH];
            auto hr = GetModuleDirectory(iconPath, ARRAYSIZE(iconPath));
            if (FAILED(hr))
            {
                return hr;
            }
            hr = StringCchCatW(iconPath, ARRAYSIZE(iconPath), L"\\");
            if (FAILED(hr))
            {
                return hr;
            }
            hr = StringCchCatW(iconPath, ARRAYSIZE(iconPath), _spec.icon_relative_path);
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
            *guidCommandName = *_spec.clsid;
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
                AppendShellLog(L"GetState title=%s hidden resolve hr=0x%08X item=%p", _spec.title, hr, item);
                *cmdState = ECS_HIDDEN;
                if (item)
                {
                    item->Release();
                }
                return S_OK;
            }

            const auto matchHr = ItemMatchesCommandTarget(item, _spec);
            item->Release();
            *cmdState = matchHr == S_OK ? ECS_ENABLED : ECS_HIDDEN;
            AppendShellLog(L"GetState title=%s state=%d matchHr=0x%08X", _spec.title, *cmdState, matchHr);
            return S_OK;
        }

        IFACEMETHODIMP Invoke(IShellItemArray* items, IBindCtx*) override
        {
            if (!IsLeafCommand(_spec))
            {
                AppendShellLog(L"Invoke title=%s ignored on submenu root", _spec.title);
                return E_NOTIMPL;
            }

            IShellItem* item = nullptr;
            auto hr = GetBestLocation(items, &item);
            if (FAILED(hr) || !item)
            {
                AppendShellLog(L"Invoke title=%s failed to resolve location hr=0x%08X item=%p", _spec.title, hr, item);
                if (item)
                {
                    item->Release();
                }
                return hr;
            }

            hr = ItemMatchesCommandTarget(item, _spec);
            if (hr != S_OK)
            {
                item->Release();
                AppendShellLog(L"Invoke title=%s target mismatch hr=0x%08X", _spec.title, hr);
                return hr == S_FALSE ? E_FAIL : hr;
            }

            PWSTR targetPath = nullptr;
            hr = GetPathFromItem(item, &targetPath);
            item->Release();
            if (FAILED(hr))
            {
                AppendShellLog(L"Invoke title=%s failed to resolve path hr=0x%08X", _spec.title, hr);
                return hr;
            }

            AppendShellLog(L"Invoke title=%s path=%s", _spec.title, targetPath);
            hr = LaunchFallbackProcess(_spec, targetPath);
            CoTaskMemFree(targetPath);
            if (FAILED(hr))
            {
                AppendShellLog(L"Invoke title=%s launch failed hr=0x%08X", _spec.title, hr);
                return hr;
            }

            AppendShellLog(L"Invoke title=%s launched ok", _spec.title);
            return S_OK;
        }

        IFACEMETHODIMP GetFlags(EXPCMDFLAGS* flags) override
        {
            if (!flags)
            {
                return E_POINTER;
            }
            *flags = IsLeafCommand(_spec) ? ECF_DEFAULT : ECF_HASSUBCOMMANDS;
            return S_OK;
        }

        IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** commands) override
        {
            if (!commands)
            {
                return E_POINTER;
            }
            *commands = nullptr;

            if (IsLeafCommand(_spec))
            {
                return E_NOTIMPL;
            }

            IExplorerCommand* childCommands[4]{};
            for (size_t i = 0; i < _spec.subcommand_count; i += 1)
            {
                auto* child = new ExplorerCommand(*_spec.subcommands[i]);
                if (!child)
                {
                    for (size_t j = 0; j < i; j += 1)
                    {
                        if (childCommands[j])
                        {
                            childCommands[j]->Release();
                        }
                    }
                    return E_OUTOFMEMORY;
                }

                if (_site)
                {
                    child->SetSite(_site);
                }

                childCommands[i] = child;
            }

            auto* enumerator = new ExplorerCommandEnumerator(childCommands, static_cast<UINT>(_spec.subcommand_count));
            for (size_t i = 0; i < _spec.subcommand_count; i += 1)
            {
                if (childCommands[i])
                {
                    childCommands[i]->Release();
                }
            }
            if (!enumerator)
            {
                return E_OUTOFMEMORY;
            }

            *commands = enumerator;
            return S_OK;
        }

        IFACEMETHODIMP SetSite(IUnknown* site) override
        {
            AppendShellLog(L"SetSite title=%s site=%p", _spec.title, site);
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

            if (!_spec.allow_background)
            {
                return S_FALSE;
            }

            if (!_site)
            {
                AppendShellLog(L"GetLocationFromSite title=%s no site", _spec.title);
                return S_FALSE;
            }

            IServiceProvider* serviceProvider = nullptr;
            auto hr = _site->QueryInterface(IID_PPV_ARGS(&serviceProvider));
            if (FAILED(hr))
            {
                AppendShellLog(L"GetLocationFromSite title=%s QI IServiceProvider failed hr=0x%08X", _spec.title, hr);
                return hr;
            }

            IFolderView* folderView = nullptr;
            hr = serviceProvider->QueryService(SID_SFolderView, IID_PPV_ARGS(&folderView));
            serviceProvider->Release();
            if (FAILED(hr))
            {
                AppendShellLog(L"GetLocationFromSite title=%s QueryService SID_SFolderView failed hr=0x%08X", _spec.title, hr);
                return hr;
            }

            hr = folderView->GetFolder(IID_PPV_ARGS(location));
            folderView->Release();
            AppendShellLog(L"GetLocationFromSite title=%s GetFolder hr=0x%08X location=%p", _spec.title, hr, location ? *location : nullptr);
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
                const auto countHr = items->GetCount(&count);
                if (SUCCEEDED(countHr) && count > 0)
                {
                    if (count != 1)
                    {
                        AppendShellLog(L"GetBestLocation title=%s hiding multi-select count=%lu", _spec.title, count);
                        return HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);
                    }
                    AppendShellLog(L"GetBestLocation title=%s using selection count=%lu", _spec.title, count);
                    return items->GetItemAt(0, location);
                }
            }

            AppendShellLog(L"GetBestLocation title=%s falling back to site", _spec.title);
            return GetLocationFromSite(location);
        }

        long _refCount;
        IUnknown* _site;
        const CommandSpec& _spec;
    };

    const CommandSpec kOpenZideTerminalHere = {
        &CLSID_OpenZideTerminalHere,
        L"Open Zide Terminal here",
        L"icons\\zide-terminal.ico",
        CommandTargetKind::Directory,
        true,
        ZIDE_TERMINAL_AUMID,
        L"zide-terminal.exe",
        CommandLaunchArgs::TerminalCwd,
        nullptr,
        0,
    };

    const CommandSpec kOpenInZideFile = {
        &CLSID_OpenInZideFile,
        L"Open in Zide",
        L"icons\\zide.ico",
        CommandTargetKind::File,
        false,
        ZIDE_AUMID,
        L"zide.exe",
        CommandLaunchArgs::PositionalPath,
        nullptr,
        0,
    };

    const CommandSpec kOpenInZideEditorFile = {
        &CLSID_OpenInZideEditorFile,
        L"Open in Zide Editor",
        L"icons\\zide.ico",
        CommandTargetKind::File,
        false,
        ZIDE_EDITOR_AUMID,
        L"zide-editor.exe",
        CommandLaunchArgs::PositionalPath,
        nullptr,
        0,
    };

    const CommandSpec kOpenInZideFolder = {
        &CLSID_OpenInZideFolder,
        L"Open in Zide",
        L"icons\\zide.ico",
        CommandTargetKind::Directory,
        false,
        ZIDE_AUMID,
        L"zide.exe",
        CommandLaunchArgs::FolderFlag,
        nullptr,
        0,
    };

    const CommandSpec* const kFileMenuChildren[] = {
        &kOpenInZideFile,
        &kOpenInZideEditorFile,
    };

    const CommandSpec* const kFolderMenuChildren[] = {
        &kOpenInZideFolder,
        &kOpenZideTerminalHere,
    };

    const CommandSpec kZideFileMenu = {
        &CLSID_ZideFileMenu,
        L"Zide",
        L"icons\\zide.ico",
        CommandTargetKind::File,
        false,
        nullptr,
        nullptr,
        CommandLaunchArgs::None,
        kFileMenuChildren,
        ARRAYSIZE(kFileMenuChildren),
    };

    const CommandSpec kZideFolderMenu = {
        &CLSID_ZideFolderMenu,
        L"Zide",
        L"icons\\zide.ico",
        CommandTargetKind::Directory,
        false,
        nullptr,
        nullptr,
        CommandLaunchArgs::None,
        kFolderMenuChildren,
        ARRAYSIZE(kFolderMenuChildren),
    };

    const CommandSpec* const kComVisibleCommands[] = {
        &kZideFileMenu,
        &kZideFolderMenu,
        &kOpenZideTerminalHere,
    };

    HRESULT ResolveCommandSpec(REFCLSID clsid, const CommandSpec** spec)
    {
        if (!spec)
        {
            return E_POINTER;
        }
        *spec = nullptr;

        for (const auto* candidate : kComVisibleCommands)
        {
            if (*candidate->clsid == clsid)
            {
                *spec = candidate;
                return S_OK;
            }
        }

        return CLASS_E_CLASSNOTAVAILABLE;
    }

    class ExplorerCommandClassFactory final : public IClassFactory
    {
    public:
        explicit ExplorerCommandClassFactory(const CommandSpec& spec) :
            _refCount(1),
            _spec(spec)
        {
            AddServerLock();
        }

        ~ExplorerCommandClassFactory()
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

            auto* command = new ExplorerCommand(_spec);
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
        const CommandSpec& _spec;
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

    const CommandSpec* spec = nullptr;
    const auto resolveHr = ResolveCommandSpec(rclsid, &spec);
    if (FAILED(resolveHr) || !spec)
    {
        return CLASS_E_CLASSNOTAVAILABLE;
    }

    auto* factory = new ExplorerCommandClassFactory(*spec);
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
