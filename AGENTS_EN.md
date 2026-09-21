# AGENTS.md — Microsoft Photos Fix Project (Windows 10 & 11)

> **Context for AI Agents (Antigravity / Claude / Gemini / Copilot)**:  
> This document details the technical architecture, business logic, reverse-engineered UWP subsystem behavior, workarounds, and operational procedures for this repository.  
> If you are an AI agent working within this workspace on any machine, environment, or session, strictly adhere to the guidelines below to maintain stability, cleanliness, and code integrity.

---

## 1. Overview and Problem Architecture

The modern **Microsoft Photos** application (AUMID: `Microsoft.Windows.Photos_8wekyb3d8bbwe!App`) is a UWP (Universal Windows Platform) package deployed via the Microsoft Store that runs within Windows' restrictive sandbox (**AppContainer**).

### The Chronic Issue
Across all builds of Windows 10 and Windows 11, a persistent design flaw affects standard image file associations:
1. **The Symptom**: When a user double-clicks any image file in Windows Explorer and attempts to use the **"Set as desktop background"** or **"Set as lock screen"** options inside the Photos viewer (via the three-dots menu or right-click context menu):
   - The app silently ignores the command or errors out;
   - The background image **fails to apply**.
2. **The Root Cause**: The default COM shell delegate handler in Windows Explorer uses `DelegateExecute: {BFEC0C93-0B7D-4F2C-B09C-AFFFC4BDAE78}`. When launched via this indirect shell delegate route, the `Photos.exe` process is initialized without inheriting the original file context privilege token needed to dispatch calls to the `IActiveDesktop` / `SystemParametersInfo(SPI_SETDESKWALLPAPER)` API.
3. **Why the Protocol Route Resolves It**: Activating images via the URI protocol handler `ms-photos:viewer?fileName=<escaped_path>` forces the application to load the image in rich viewer mode with full file context, instantly and permanently restoring desktop and lock screen background settings.

---

## 2. Repository File Structure

```
Microsoft-Photos-Fix/
├── Microsoft-Photos-Fix.ps1   # Master PowerShell script (Interactive UI, Silent CLI, Embedded C# Compiler)
├── README.md                  # Primary GitHub documentation (Default PT-BR with language badges)
├── README-PT-BR.md            # Brazilian Portuguese user manual
├── README-EN.md               # English user manual
├── AGENTS.md                  # Architectural specification for AI agents (Portuguese)
├── AGENTS_EN.md               # Architectural specification for AI agents (English)
├── LICENSE                    # MIT License
└── .gitignore                 # Exclusions for local and temporary files
```

---

## 3. The 10 Critical Engineering Maneuvers

When refactoring, optimizing, or maintaining `Microsoft-Photos-Fix.ps1`, **NEVER modify or remove** these 10 critical maneuvers:

### Maneuver 1: Protocol Routing via `ms-photos:viewer?fileName=...`
- **Mechanism**: The native helper receives the file path `%1`, resolves it to a normalized absolute path via `Path.GetFullPath()`, escapes special URI characters using `Uri.EscapeDataString()`, and launches `Process.Start("ms-photos:viewer?fileName=" + uri)`.
- **Impact**: This is the only route that guarantees Photos activation with full context for wallpaper changes without relying on intermediate visible PowerShell console windows.

### Maneuver 2: Alternate Data Stream Deletion (`:Zone.Identifier`)
- **Problem**: Images downloaded from browsers, Google Chrome, WhatsApp, or messaging apps receive the hidden NTFS `:Zone.Identifier` stream (Mark of the Web). The Photos UWP sandbox container frequently rejects or fails to open marked files when launched via custom protocol invocations.
- **Solution**: The native helper invokes `DeleteFileW(fullPath + ":Zone.Identifier")` via `kernel32.dll` P/Invoke before launching the image.

### Maneuver 3: Helper Isolation in `%LOCALAPPDATA%\MicrosoftPhotosFix`
- **Problem**: Outputting the compiled binary (`FotosModernRouteLauncherV2.exe`) in the user's working directory (such as Downloads) visually clutters the folder and creates the risk of accidental user deletion.
- **Solution**: The embedded C# compiler generates the binary in `%TEMP%` and atomically moves it to `%LOCALAPPDATA%\MicrosoftPhotosFix\FotosModernRouteLauncherV2.exe`. The user's active folder strictly retains **only the `.ps1` script**.

### Maneuver 4: Anti Self-Deletion Guard in Scheduled Task (`Remove-OldLaunchers`)
- **Critical Problem**: The startup maintenance task executes the script copy stored in `%LOCALAPPDATA%\MicrosoftPhotosFix\`. If the cleanup routine inspects `$script:CurrentFolder` without verifying whether it matches the install directory, **the startup task will delete its own `.exe` launcher on every PC reboot/logon**, causing double-clicked images to prompt *"How do you want to open this .jpg file?"*.
- **Immutable Solution**:
  ```powershell
  $currFull = [IO.Path]::GetFullPath($script:CurrentFolder).TrimEnd('\')
  $instFull = [IO.Path]::GetFullPath($script:InstallDir).TrimEnd('\')
  if ($currFull -ne $instFull) {
      # Remove legacy binaries from user working folder, but NEVER from InstallDir!
  }
  ```

### Maneuver 5: Surgical ProgID Targeting (`AppX4mntx4h978m1v9gtzv0ewksfd6pmwsre`)
- **Critical Problem**: Microsoft Photos registers over 8 distinct ProgIDs (including video players, camera roll hooks, and internal COM interfaces). Modifying `DelegateExecute` on auxiliary ProgIDs corrupts UWP sandbox initialization, causing:
  > **`Photos.exe - Application Error (0xc0000142)` (`STATUS_DLL_INIT_FAILED`)**
- **Solution**: The script strictly targets verified image extensions and active user choices (`UserChoice` / `OpenWithProgids`), updating exclusively the primary photo ProgID (`AppX4mntx4h978m1v9gtzv0ewksfd6pmwsre`). All auxiliary system ProgIDs remain untouched.

### Maneuver 6: Interactive Terminal UX with `Clear-Host` and Single Keystroke (`ReadKey`)
- **Problem**: Standard `Read-Host` loops accumulate multiple repetitive menus down the console buffer and leave trailing newline characters that trigger false "Invalid option" alerts.
- **Solution**:
  - Screen is cleared with `Clear-Host` before each menu render;
  - Non-blocking single key input via `[Console]::ReadKey($true)` (with automated fallback to `Read-Host` if input is redirected);
  - Pressing `1`, `2`, `3`, or `0` executes immediately without needing to press Enter;
  - `Enter` clears the screen and returns to the root menu;
  - `Esc` terminates immediately.

### Maneuver 7: Mandatory UTF-8 BOM Encoding
- **Problem**: Windows PowerShell 5.1 interprets UTF-8 files lacking a Byte Order Mark (BOM) as ANSI/Windows-1252, corrupting accented characters (`ç`, `ã`, `é`, etc.) into mojibake in the terminal.
- **Solution**: All `.ps1` files in this repository must be saved with **UTF-8 with BOM** (`[System.Text.UTF8Encoding]::new($true)`).

### Maneuver 8: Post-Update Persistence via Task Scheduler
- **Mechanism**: Registers a scheduled task (`\Fotos moderno - manter rota corrigida`) with two triggers:
  1. `LogonTrigger` (Trigger 9): Validates route integrity at every user logon;
  2. `EventTrigger` (Trigger 0): Monitors channel `Microsoft-Windows-AppXDeploymentServer/Operational` for Event `822` (package updates). When the Microsoft Store updates Photos and resets default registry keys, the fix silently reapplies in the background.

### Maneuver 9: Shell Refresh Notification (`SHChangeNotify`)
- **Mechanism**: After modifying registry keys under `HKCU:\Software\Classes`, the script calls Windows shell notification via P/Invoke:
  ```csharp
  [DllImport("shell32.dll")]
  public static extern void SHChangeNotify(uint eventId, uint flags, IntPtr item1, IntPtr item2);
  ```
  Using `eventId = 0x08000000` (`SHCNE_ASSOCCHANGED`).
- **Impact**: Windows Explorer instantly refreshes its internal icon and file association caches without requiring `explorer.exe` restarts or system logoffs.

### Maneuver 10: Complete Rollback and Snapshot Restore (`-Desfazer`)
- **Mechanism**: Before writing new route definitions, the script takes a snapshot of `(default)` and `DelegateExecute` at `HKCU:\Software\FotosModernoRouteFix\<ProgId>`.
- **Restoration**: The `-Desfazer` switch (or menu option 2) restores exact factory values for `DelegateExecute`, removes custom commands, deletes the scheduled task, purges `%LOCALAPPDATA%\MicrosoftPhotosFix`, and notifies the shell, returning Windows to default settings.

---

## 4. Guidelines and Strict Rules for AI Agents

1. **PowerShell 5.1 Compatibility**: All code must remain compatible with native Windows PowerShell 5.1 (do not introduce syntax or cmdlets exclusive to PowerShell Core 7+).
2. **HKCU Scope (No Admin Elevation Required)**: The script operates within the Current User registry hive (`HKCU`), avoiding unnecessary Administrator UAC prompts. Do not migrate routes to `HKLM`.
3. **Repository Script Naming**:
   - The primary script in the GitHub repository must remain `Microsoft-Photos-Fix.ps1` (without spaces) for CLI convenience and consistent cross-platform referencing.
4. **GitHub Synchronization**:
   - Official remote repository: `https://github.com/Emertels/Microsoft-Photos-Fix.git` (`main` branch).
   - Keep `README.md`, `README-PT-BR.md`, `README-EN.md`, `AGENTS.md`, and `AGENTS_EN.md` aligned whenever menu items, switches, or behaviors are updated.
