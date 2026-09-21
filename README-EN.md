# 🖼️ Microsoft Photos Route Fix (Windows 10 & 11)

<div align="center">

**🌐 Languages / Idiomas:**  
[![Português Brasil](https://img.shields.io/badge/Idioma-Portugu%C3%AAs%20(Brasil)-green?style=for-the-badge)](README-PT-BR.md)
[![English](https://img.shields.io/badge/Language-English-blue?style=for-the-badge)](README-EN.md)

</div>

---

An advanced automated PowerShell utility designed to permanently resolve the chronic launch failure, route association bugs, and wallpaper application issues affecting the modern **Microsoft Photos** app on Windows 10 and Windows 11.

---

## 🛑 The Chronic Issue: What actually happens?

If you use Windows 10 or Windows 11, you have likely encountered this problem: **no matter how many times you format your computer or clean install Windows, this chronic Microsoft Photos bug inevitably resurfaces.**

### The Symptom
When you double-click any image file and attempt to set it as your **Desktop Background** or **Lock Screen** directly from within the viewer (via the three-dots menu or right-clicking inside the Photos app):
- ❌ **The wallpaper simply fails to apply.** Windows silently fails, ignores the action, or errors out.

### The Inconvenient Workarounds (Before this script)
Prior to this fix, users were forced into annoying workarounds:
1. Manually launching the Microsoft Photos app from the Start Menu first, browsing for the picture inside the app's internal folders, and only then setting it as wallpaper; OR
2. Leaving the photo closed and right-clicking the file in File Explorer to select "Set as desktop background".

### 🔍 Root Cause
The modern UWP/AppX Microsoft Photos application relies on a COM delegate routing path (`DelegateExecute` / AUMID / AppX routing). Due to persistent registry inconsistencies and sandboxing limitations in Windows, when an image file is opened via the standard Explorer shell association, the app loses the necessary privilege context to invoke the operating system's desktop background API.

---

## 💡 The Permanent Solution Provided by This Script

This script applies a safe, isolated, and permanent engineering maneuver:

- ⚙️ **Isolated Lightweight Launcher:** Locally compiles and deploys a native, ultra-lightweight C# launcher (`FotosModernRouteLauncherV2.exe`) into `%LOCALAPPDATA%\MicrosoftPhotosFix`.
- 🎯 **Intelligent Route Redirection:** Corrects file handler associations so images open instantly while preserving the full parent process context, restoring 100% functionality to set wallpapers and lock screen backgrounds directly from inside the viewer.
- 🛡️ **Automated Registry Snapshot:** Automatically backs up all modified registry values to `HKCU:\Software\FotosModernoRouteFix` before applying any changes.
- 🔄 **Fully Reversible:** At any time, with a single command or menu option (`-Desfazer`), the original factory Windows registry entries are restored and the local folder is purged.
- 🖼️ **Wide Format Support (20 Extensions):** Supports `.jpg`, `.jpeg`, `.jpe`, `.jfif`, `.png`, `.bmp`, `.dib`, `.gif`, `.tif`, `.tiff`, `.webp`, `.heic`, `.heif`, `.hif`, `.avif`, `.jxl`, `.jxr`, `.wdp`, `.ico`, and `.svg`.

---

## 🚀 How to Use

### 1. Requirements
* **Windows 10** (Build 10240 or higher) or **Windows 11**.
* Run via **PowerShell** (no invasive kernel modifications; operates strictly within the secure user registry scope `HKCU`).

### 2. Interactive Terminal Menu
Right-click `Microsoft-Photos-Fix.ps1` and choose **"Run with PowerShell"** (or open a terminal in the folder and execute):

```powershell
.\Microsoft-Photos-Fix.ps1
```

An interactive menu will guide you:
```text
==================================================
   CORREÇÃO ROTA MICROSOFT FOTOS (WINDOWS 10/11)  
==================================================
1. Apply full fix
2. Check current route status
3. Roll back changes and restore Windows defaults
4. Exit
```

### 3. Silent CLI & Automation Parameters

Ideal for post-installation scripts, IT deployment, or batch automation:

| Parameter | Description |
| :--- | :--- |
| `-Corrigir` | Applies the route fix, compiles/deploys the launcher, and updates file associations immediately. |
| `-Status` | Prints a comprehensive diagnostic report of the current Photos routing state. |
| `-Desfazer` | Removes the helper launcher and restores factory Microsoft default handlers. |
| `-Silencioso` | Executes without printing terminal logs. |

#### CLI Examples:
```powershell
# Apply fix directly:
.\Microsoft-Photos-Fix.ps1 -Corrigir

# Check current diagnostics:
.\Microsoft-Photos-Fix.ps1 -Status

# Roll back all changes:
.\Microsoft-Photos-Fix.ps1 -Desfazer
```

---

## 🛡️ Security & Integrity
* **Non-destructive:** No protected Windows system files are modified or deleted.
* **100% Transparent:** Open-source PowerShell and embedded C# code readily auditable.
* **Windows Defender Friendly:** Zero heuristic false positives, respecting Windows user configuration guidelines.

---

## 👤 About the Author

Developed by **Emerson Teles** (known in the community as **Emertels**).

Passionate about technology, PC hardware, gaming, system maintenance, and open software/emulator localization into Brazilian Portuguese (PT-BR).

### 🛠️ Notable Projects & Contributions:
- **Software & Utilities:** 100% Brazilian localization for **DSX** (DualSense X - Trusted Translator), **ASUS GPU Tweak III**, **dnGrep**, **XWidget**, and web utilities (**DualSense Tester**, **DualShock Tools**).
- **Emulation & Systems:** Contributor and localizer for systems and emulators including **PSBBN** (PlayStation Broadband Navigator for PS2), **PCSX2**, **Dolphin**, **shadPS4**, **Azahar**, and **RetroArch**.
- **Games & Apps:** Localization of **Silent Hill 5: Homecoming**, ongoing translation for **Silent Hill 4: The Room**, and various Android & PC applications.

---

### 🌐 Connect with me:

<div align="left">

[![GitHub](https://img.shields.io/badge/GitHub-Emertels-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/emertels)
[![YouTube](https://img.shields.io/badge/YouTube-Emerson_Teles-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/@emersonteles2379)
[![X / Twitter](https://img.shields.io/badge/X_Twitter-@emertels-000000?style=for-the-badge&logo=x&logoColor=white)](https://x.com/emertels)

</div>
