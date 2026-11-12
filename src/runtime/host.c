/*
 * Macromedia Flash MX 2004 - static recompilation host.
 *
 * A 32-bit host on pcrecomp's runtime/native32 (the native bridge, callbacks
 * and the machine lock; see its header). Flash.exe (MFC 7.1 linked in) is
 * lifted; every DLL it loads (xerces, GdiPlus, the player, the SafeCast
 * licensing client) runs natively. What is here is only the guest image, its
 * folder, its command line and the fault report. From the Retail Plus host.
 *
 * Flash.exe is based at 0x00400000 and is 14 MB, which overlaps where Windows
 * puts the first thread's stack: native32_hold_image keeps the range free and
 * the host runs on a thread of its own (main()), as Bully's does.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "native32.h"
#include "recomp_trace.h"

extern const uint32_t fl_entry_va;       /* recomp_dispatch.c */

#define FL_BASE 0x00400000u

static DWORD g_watchdog_s;
static char  g_app[MAX_PATH];            /* the app folder, with a trailing '\' */
static char  g_guest_exe[MAX_PATH], g_guest_cmdline[MAX_PATH + 1024];
static WCHAR g_guest_exe_w[MAX_PATH], g_guest_cmdline_w[MAX_PATH + 1024];

#define ARG(n) MEM32(g_esp + 4 + 4 * (n))
#define RET(v, nargs) do { g_eax = (uint32_t)(v); g_esp += 4 + 4 * (nargs); } while (0)

/* The guest is Flash.exe, not this host: its hInstance (menus, dialogs,
 * strings) is GetModuleHandle(NULL), and Flash finds its Configuration
 * folder, DLLs and licensing manager next to its own path, the real Flash.exe
 * in the install folder. Redirected rather than shimmed: Flash links MSLU
 * (unicows), whose thunks get the W functions from GetProcAddress, and MFC's
 * CWinApp::SetCurrentHandles threw CUserException when GetModuleFileNameW of
 * 0x00400000 failed. */
static HMODULE WINAPI fl_GetModuleHandleA(LPCSTR name) { return name ? GetModuleHandleA(name) : (HMODULE)(uintptr_t)FL_BASE; }
static HMODULE WINAPI fl_GetModuleHandleW(LPCWSTR name) { return name ? GetModuleHandleW(name) : (HMODULE)(uintptr_t)FL_BASE; }

static DWORD WINAPI fl_GetModuleFileNameA(HMODULE h, LPSTR out, DWORD size) {
    if (h && (uintptr_t)h != FL_BASE) return GetModuleFileNameA(h, out, size);
    DWORD n = (DWORD)strlen(g_guest_exe);
    if (!size) return 0;
    if (n >= size) n = size - 1;
    memcpy(out, g_guest_exe, n);
    out[n] = 0;
    return n;
}
static DWORD WINAPI fl_GetModuleFileNameW(HMODULE h, LPWSTR out, DWORD size) {
    if (h && (uintptr_t)h != FL_BASE) return GetModuleFileNameW(h, out, size);
    DWORD n = (DWORD)wcslen(g_guest_exe_w);
    if (!size) return 0;
    if (n >= size) n = size - 1;
    memcpy(out, g_guest_exe_w, n * 2);
    out[n] = 0;
    return n;
}

static LPSTR WINAPI fl_GetCommandLineA(void) { return g_guest_cmdline; }
static LPWSTR WINAPI fl_GetCommandLineW(void) { return g_guest_cmdline_w; }


/* MSLU (unicows.lib, linked in) does not import the W functions: each has a
 * pointer that starts at a resolver thunk,
 *     push fail; push [hmod]; push &slot; push "Name"; push "kernel32.dll"; call resolve
 * and the resolver walks kernel32's export table itself, so neither the
 * import binding nor native32_redirect's GetProcAddress hook sees it. The
 * functions the host must answer get their slot filled before the guest
 * runs, so the thunk is never taken. */
static void mslu_redirect(const char* name, void* fn) {
    for (uint32_t p = FL_BASE + 0x1000; p + 26 < FL_BASE + 0x9F4000; p++) {
        const uint8_t* c = (const uint8_t*)(uintptr_t)p;
        if (c[0] != 0x68 || c[5] != 0xFF || c[6] != 0x35 || c[11] != 0x68 || c[16] != 0x68 || c[21] != 0x68 || c[26] != 0xE8)
            continue;
        uint32_t slot = *(const uint32_t*)(c + 12), nm = *(const uint32_t*)(c + 17);
        if (native32_in_guest(slot) && native32_in_guest(nm) && !strcmp((const char*)(uintptr_t)nm, name)) {
            MEM32(slot) = (uint32_t)(uintptr_t)fn;
            return;
        }
    }
    fprintf(stderr, "[mslu] no thunk for %s\n", name);
}

/* FL_TRACE_REG=1: the registry keys and values Flash opens and reads (the
 * MSLU thunks reach them, so --native-trace, which is slow here, is not
 * needed to see them). */
static LONG WINAPI fl_RegOpenKeyExW(HKEY k, LPCWSTR sub, DWORD o, REGSAM s, PHKEY out) {
    LONG r = RegOpenKeyExW(k, sub, o, s, out);
    fprintf(stderr, "[reg] open %p\\%ls -> %ld %p\n", k, sub ? sub : L"", r, r ? NULL : *out);
    return r;
}
static LONG WINAPI fl_RegCreateKeyExW(HKEY k, LPCWSTR sub, DWORD r0, LPWSTR c, DWORD o, REGSAM s,
                                      LPSECURITY_ATTRIBUTES sa, PHKEY out, LPDWORD disp) {
    LONG r = RegCreateKeyExW(k, sub, r0, c, o, s, sa, out, disp);
    fprintf(stderr, "[reg] create %p\\%ls -> %ld %p\n", k, sub ? sub : L"", r, r ? NULL : *out);
    return r;
}
static LONG WINAPI fl_RegQueryValueExW(HKEY k, LPCWSTR v, LPDWORD r0, LPDWORD t, LPBYTE d, LPDWORD n) {
    LONG r = RegQueryValueExW(k, v, r0, t, d, n);
    fprintf(stderr, "[reg] query %p [%ls] -> %ld\n", k, v ? v : L"", r);
    return r;
}

static LONG WINAPI fl_RegOpenKeyExA(HKEY k, LPCSTR sub, DWORD o, REGSAM s, PHKEY out) {
    LONG r = RegOpenKeyExA(k, sub, o, s, out);
    fprintf(stderr, "[reg] openA %p\\%s -> %ld %p\n", k, sub ? sub : "", r, r ? NULL : *out);
    return r;
}
static LONG WINAPI fl_RegCreateKeyExA(HKEY k, LPCSTR sub, DWORD r0, LPSTR c, DWORD o, REGSAM s,
                                      LPSECURITY_ATTRIBUTES sa, PHKEY out, LPDWORD disp) {
    LONG r = RegCreateKeyExA(k, sub, r0, c, o, s, sa, out, disp);
    fprintf(stderr, "[reg] createA %p\\%s -> %ld %p\n", k, sub ? sub : "", r, r ? NULL : *out);
    return r;
}
static LONG WINAPI fl_RegQueryValueExA(HKEY k, LPCSTR v, LPDWORD r0, LPDWORD t, LPBYTE d, LPDWORD n) {
    LONG r = RegQueryValueExA(k, v, r0, t, d, n);
    fprintf(stderr, "[reg] queryA %p [%s] -> %ld\n", k, v ? v : "", r);
    return r;
}

/* Who ends the process, and how. */
static BOOL WINAPI fl_TerminateProcess(HANDLE h, UINT code) {
    if (h == GetCurrentProcess() || GetProcessId(h) == GetCurrentProcessId()) {
        fprintf(stderr, "[exit] TerminateProcess(self, 0x%08X) in sub_%08X\n", code, g_cur_func);
        recomp_dump_trace("TerminateProcess");
    }
    return TerminateProcess(h, code);
}
static VOID WINAPI fl_ExitThread(DWORD code) {
    fprintf(stderr, "[exit] ExitThread(0x%08X) on thread %lu in sub_%08X\n", code, GetCurrentThreadId(), g_cur_func);
    recomp_dump_trace("ExitThread");
    ExitThread(code);
}
/* FL_TRACE_EXIT=1: whatever ends the process, by any route (a private
 * kernel32, a direct syscall stub, another DLL), passes NtTerminateProcess:
 * its first bytes jump here, which reports, puts them back and goes on. */
typedef LONG (NTAPI* nt_term_t)(HANDLE, LONG);
static uint8_t g_ntterm_saved[5];
static nt_term_t g_ntterm;
static LONG NTAPI fl_NtTerminateProcess(HANDLE h, LONG code) {
    DWORD old;
    void* bt[24];
    USHORT n = RtlCaptureStackBackTrace(0, 24, bt, NULL);
    fprintf(stderr, "[exit] NtTerminateProcess(%p, 0x%08lX) on thread %lu in sub_%08X, last native call %s\n",
            h, (unsigned long)code, GetCurrentThreadId(), g_cur_func, g_cur_import);
    for (USHORT i = 0; i < n; i++) fprintf(stderr, "  host %p\n", bt[i]);
    recomp_dump_trace("NtTerminateProcess");
    VirtualProtect((void*)g_ntterm, 5, PAGE_EXECUTE_READWRITE, &old);
    memcpy((void*)g_ntterm, g_ntterm_saved, 5);
    return g_ntterm(h, code);
}
static void trace_exit(void) {
    DWORD old;
    g_ntterm = (nt_term_t)GetProcAddress(GetModuleHandleA("ntdll.dll"), "NtTerminateProcess");
    uint8_t* p = (uint8_t*)g_ntterm;
    memcpy(g_ntterm_saved, p, 5);
    VirtualProtect(p, 5, PAGE_EXECUTE_READWRITE, &old);
    p[0] = 0xE9;
    *(int32_t*)(p + 1) = (int32_t)((uint8_t*)fl_NtTerminateProcess - (p + 5));
    VirtualProtect(p, 5, old, &old);
}

static VOID WINAPI fl_ExitProcess(UINT code) {
    fprintf(stderr, "[exit] ExitProcess(0x%08X) in sub_%08X\n", code, g_cur_func);
    recomp_dump_trace("ExitProcess");
    ExitProcess(code);
}


/* ------------------------------------------------------------ reports */

recomp_func_t recomp_lookup_manual(uint32_t va) { (void)va; return NULL; }

/* Added after native32's own handler, so callbacks are resolved first and
 * only real faults get here. */
static LONG CALLBACK crash(EXCEPTION_POINTERS* ep) {
    EXCEPTION_RECORD* r = ep->ExceptionRecord;
    if ((r->ExceptionCode & 0xF0000000u) != 0xC0000000u) {
        fprintf(stderr, "[exception] 0x%08lX at 0x%p, in sub_%08X, last native call %s\n",
                r->ExceptionCode, r->ExceptionAddress, g_cur_func, g_cur_import);
        if (r->ExceptionCode == 0xE06D7363u) recomp_dump_trace("C++ throw");   /* what threw */
        return EXCEPTION_CONTINUE_SEARCH;
    }
    fprintf(stderr, "\n=== fault 0x%08lX at 0x%p ===\n", r->ExceptionCode, r->ExceptionAddress);
    if (r->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && r->NumberParameters >= 2) {
        ULONG_PTR op = r->ExceptionInformation[0];
        uint32_t at = (uint32_t)r->ExceptionInformation[1];
        fprintf(stderr, "  %s of 0x%08X%s\n", op == 0 ? "read" : op == 1 ? "write" : "execute", at,
                native32_in_guest(at) ? " (inside the guest image)" : at < 0x10000 ? " (null/low)" : "");
    }
    recomp_trace_flush();
    fprintf(stderr, "  in lifted sub_%08X, last native call %s\n", g_cur_func, g_cur_import);
    fprintf(stderr, "  eax=%08X ecx=%08X edx=%08X ebx=%08X esp=%08X ebp=%08X esi=%08X edi=%08X\n",
            g_eax, g_ecx, g_edx, g_ebx, g_esp, g_ebp, g_esi, g_edi);
    native32_dump_icalls(12);
    recomp_dump_trace("fault");
    TerminateProcess(GetCurrentProcess(), 3);
    return EXCEPTION_CONTINUE_SEARCH;
}

static DWORD WINAPI watchdog(LPVOID unused) {
    (void)unused;
    Sleep(g_watchdog_s * 1000);
    fprintf(stderr, "\n[watchdog] %lu s: in sub_%08X, last native call %s\n",
            g_watchdog_s, g_cur_func, g_cur_import);
    TerminateProcess(GetCurrentProcess(), 4);
    return 0;
}

static int host_main(int argc, char** argv) {
    const char* app = "game";
    const char* args = "";
    int run = 0, native_exe = 0;
    for (int i = 1; i < argc; i++) {
        int n = recomp_trace_arg(argc, argv, i);
        if (n) { i += n - 1; continue; }
        if (!strcmp(argv[i], "--run")) run = 1;
        else if (!strcmp(argv[i], "--game") && i + 1 < argc) app = argv[++i];
        else if (!strcmp(argv[i], "--args") && i + 1 < argc) args = argv[++i];
        else if (!strcmp(argv[i], "--watchdog") && i + 1 < argc) g_watchdog_s = strtoul(argv[++i], NULL, 0);
        else if (!strcmp(argv[i], "--native-trace")) native32_trace_native = 1;
        else if (!strcmp(argv[i], "--callbacks")) native32_trace_callbacks = 1;
        else if (!strcmp(argv[i], "--native-exe")) native_exe = 1;
        else {
            printf("usage: flashmxrecomp [--run] [--game DIR] [--args \"GUEST ARGS\"] [--watchdog S]\n"
                   "                     [--native-trace] [--callbacks] [--native-exe]\n"
                   "  DIR is the installed Flash MX 2004 folder (Flash.exe, Configuration\\, ...)\n"
                   "  without --run: map and bind Flash.exe, then stop (no window)\n");
            recomp_trace_help();
            return argv[i][1] == 'h' || argv[i][2] == 'h' ? 0 : 1;
        }
    }
    GetFullPathNameA(app, MAX_PATH - 1, g_app, NULL);
    if (g_app[strlen(g_app) - 1] != '\\') strcat(g_app, "\\");
    _snprintf(g_guest_exe, sizeof g_guest_exe - 1, "%sFlash.exe", g_app);
    _snprintf(g_guest_cmdline, sizeof g_guest_cmdline - 1, "\"%s\" %s", g_guest_exe, args);
    MultiByteToWideChar(CP_ACP, 0, g_guest_exe, -1, g_guest_exe_w, MAX_PATH);
    MultiByteToWideChar(CP_ACP, 0, g_guest_cmdline, -1, g_guest_cmdline_w, MAX_PATH + 1024);

    SetDllDirectoryA(g_app);
    native32_init();
    /* Guest exceptions go to the guest's own handlers (seh32.c): the
     * licensing code's anti-debug checks fault on purpose inside __try. */
    native32_guest_seh = 1;
    if (getenv("FL_TRACE_EXIT")) trace_exit();
    if (getenv("FL_TRACE_REG")) {
        native32_redirect("RegOpenKeyExA", (void*)fl_RegOpenKeyExA);
        native32_redirect("RegCreateKeyExA", (void*)fl_RegCreateKeyExA);
        native32_redirect("RegQueryValueExA", (void*)fl_RegQueryValueExA);
    }
    native32_redirect("ExitProcess", (void*)fl_ExitProcess);
    native32_redirect("ExitThread", (void*)fl_ExitThread);
    native32_redirect("TerminateProcess", (void*)fl_TerminateProcess);
    native32_redirect("GetCommandLineA", (void*)fl_GetCommandLineA);
    native32_redirect("GetCommandLineW", (void*)fl_GetCommandLineW);
    native32_redirect("GetModuleHandleA", (void*)fl_GetModuleHandleA);
    native32_redirect("GetModuleHandleW", (void*)fl_GetModuleHandleW);
    native32_redirect("GetModuleFileNameA", (void*)fl_GetModuleFileNameA);
    native32_redirect("GetModuleFileNameW", (void*)fl_GetModuleFileNameW);
    AddVectoredExceptionHandler(0, crash);
    printf("Flash MX 2004 recomp host\n  lifted functions in dispatch: %u\n", recomp_dispatch_count);
    uint32_t span = native32_map(g_guest_exe, FL_BASE);
    if (!span) { fprintf(stderr, "cannot map %s at 0x%08X\n", g_guest_exe, FL_BASE); return 1; }
    printf("  mapped Flash.exe: 0x%08X-0x%08X\n", FL_BASE, FL_BASE + span);
    int unresolved = native32_bind(FL_BASE, NULL, 0);
    printf("  imports bound, %d unresolved\n", unresolved);
    if (unresolved) return 1;
    mslu_redirect("GetModuleFileNameW", (void*)fl_GetModuleFileNameW);
    mslu_redirect("GetModuleHandleW", (void*)fl_GetModuleHandleW);
    if (getenv("FL_TRACE_REG")) {
        mslu_redirect("RegOpenKeyExW", (void*)fl_RegOpenKeyExW);
        mslu_redirect("RegCreateKeyExW", (void*)fl_RegCreateKeyExW);
        mslu_redirect("RegQueryValueExW", (void*)fl_RegQueryValueExW);
    }
    /* Bisection: Flash.exe's original code instead of its lift. */
    if (native_exe && native32_set_native(FL_BASE)) printf("  Flash.exe runs natively (--native-exe)\n");
    if (!run) {
        printf("\n(dry run: image mapped and bound; --run enters 0x%08X)\n", fl_entry_va);
        return 0;
    }
    if (!SetCurrentDirectoryA(g_app)) { fprintf(stderr, "cannot enter %s\n", g_app); return 1; }
    if (g_watchdog_s) CloseHandle(CreateThread(NULL, 0, watchdog, NULL, 0, NULL));
    printf("  entering 0x%08X\n\n", fl_entry_va);
    fflush(stdout);
    native32_call_guest(fl_entry_va, 0, NULL);
    fprintf(stderr, "\nentry returned eax=%08X, last native call %s\n", g_eax, g_cur_import);
    return (int)g_eax;
}

/* The host runs on a thread with a 16 MB stack; the first thread's stack is
 * small (/STACK in CMakeLists.txt) so it fits below the held guest image. */
static int g_argc;
static char** g_argv;
static DWORD WINAPI host_thread(LPVOID unused) {
    (void)unused;
    return (DWORD)host_main(g_argc, g_argv);
}

int main(int argc, char** argv) {
    DWORD code = 1;
    char app[MAX_PATH] = "game", exe[MAX_PATH];
    setvbuf(stderr, NULL, _IONBF, 0);
    for (int i = 1; i + 1 < argc; i++)
        if (!strcmp(argv[i], "--game")) strncpy(app, argv[i + 1], MAX_PATH - 1);
    _snprintf(exe, MAX_PATH - 1, "%s\\Flash.exe", app);
    native32_hold_image(exe, FL_BASE);
    g_argc = argc, g_argv = argv;
    HANDLE t = CreateThread(NULL, 16u << 20, host_thread, NULL, STACK_SIZE_PARAM_IS_A_RESERVATION, NULL);
    if (!t) { fprintf(stderr, "cannot start the host thread (error %lu)\n", GetLastError()); return 1; }
    WaitForSingleObject(t, INFINITE);
    GetExitCodeThread(t, &code);
    return (int)code;
}
