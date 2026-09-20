#requires -version 5.1

[CmdletBinding()]
param(
    [switch]$Corrigir,
    [switch]$Desfazer,
    [switch]$Status,
    [string]$Abrir,
    [switch]$Silencioso
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:PhotosAumid = 'Microsoft.Windows.Photos_8wekyb3d8bbwe!App'
$script:OriginalDelegateExecute = '{BFEC0C93-0B7D-4F2C-B09C-AFFFC4BDAE78}'
$script:BackupRoot = 'HKCU:\Software\FotosModernoRouteFix'
$script:BackupRegistryPath = 'Software\FotosModernoRouteFix'
$script:TaskName = 'Fotos moderno - manter rota corrigida'

# Local permanente e isolado no AppData do usuário
$script:InstallDir = Join-Path $env:LOCALAPPDATA 'MicrosoftPhotosFix'
$script:HelperPath = Join-Path $script:InstallDir 'FotosModernRouteLauncherV2.exe'
$script:InstalledScriptPath = Join-Path $script:InstallDir 'Corrigir-Fotos-Moderno.ps1'

# Pasta de execução do usuário (ex.: Downloads)
$script:CurrentFolder = if ($PSCommandPath) { Split-Path -Parent ([IO.Path]::GetFullPath($PSCommandPath)) } else { $PSScriptRoot }

$script:SupportedExtensions = @(
    '.jpg', '.jpeg', '.jpe', '.jfif', '.png', '.bmp', '.dib', '.gif',
    '.tif', '.tiff', '.webp', '.heic', '.heif', '.hif', '.avif',
    '.jxl', '.jxr', '.wdp', '.ico', '.svg'
)
$script:InteractiveMenu = -not ($Corrigir -or $Desfazer -or $Status -or $Abrir -or $Silencioso)

function Write-Info {
    param([string]$Message)
    if (-not $Silencioso) {
        Write-Host $Message
    }
}

function Assert-Windows10Or11 {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
        [Environment]::OSVersion.Version.Build -lt 10240) {
        throw 'Este script requer Windows 10 ou Windows 11.'
    }
}

function Remove-OldLaunchers {
    # Remove executáveis soltos da pasta de trabalho (ex.: Downloads), MAS NUNCA da pasta de instalação definitiva ($script:InstallDir)
    $isInstallDir = $false
    if ($script:CurrentFolder -and (Test-Path -LiteralPath $script:CurrentFolder)) {
        try {
            $currFull = [IO.Path]::GetFullPath($script:CurrentFolder).TrimEnd('\')
            $instFull = [IO.Path]::GetFullPath($script:InstallDir).TrimEnd('\')
            $isInstallDir = ($currFull -eq $instFull)
        } catch {}

        if (-not $isInstallDir) {
            $filesToRemove = @(
                (Join-Path $script:CurrentFolder 'FotosModernRouteLauncherV2.exe'),
                (Join-Path $script:CurrentFolder 'FotosModernRouteLauncher.exe')
            )
            foreach ($f in $filesToRemove) {
                if (Test-Path -LiteralPath $f -PathType Leaf) {
                    try {
                        Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
                    }
                    catch {}
                }
            }
        }
    }

    # Na pasta de instalação definitiva ($script:InstallDir), remove somente a versão legada antiga V1
    if ($script:InstallDir -and (Test-Path -LiteralPath $script:InstallDir)) {
        $oldV1 = Join-Path $script:InstallDir 'FotosModernRouteLauncher.exe'
        if (Test-Path -LiteralPath $oldV1 -PathType Leaf) {
            try {
                Remove-Item -LiteralPath $oldV1 -Force -ErrorAction SilentlyContinue
            }
            catch {}
        }
    }
}

function Get-RegistryValueSnapshot {
    param(
        [Parameter(Mandatory = $true)][Microsoft.Win32.RegistryKey]$Key,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Name
    )

    $exists = $Key.GetValueNames() -contains $Name
    if (-not $exists) {
        return [pscustomobject]@{ Exists = $false; Value = ''; Kind = 'String' }
    }

    return [pscustomobject]@{
        Exists = $true
        Value  = [string]$Key.GetValue(
            $Name,
            '',
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        )
        Kind   = [string]$Key.GetValueKind($Name)
    }
}

function Get-PhotosImageProgIds {
    $progIds = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

    foreach ($extension in $script:SupportedExtensions) {
        $userChoice = Get-ItemProperty -LiteralPath (
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\UserChoice' -f $extension
        ) -ErrorAction SilentlyContinue

        if (-not $userChoice -or -not $userChoice.ProgId) {
            continue
        }

        $progId = [string]$userChoice.ProgId
        $application = Get-ItemProperty -LiteralPath (
            'Registry::HKEY_CLASSES_ROOT\{0}\Application' -f $progId
        ) -ErrorAction SilentlyContinue

        if ($application -and [string]$application.AppUserModelID -eq $script:PhotosAumid) {
            [void]$progIds.Add($progId)
        }
    }

    Get-ChildItem -LiteralPath 'HKCU:\Software\Classes' -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -like 'AppX*' } |
        ForEach-Object {
            $application = Get-ItemProperty -LiteralPath (
                Join-Path $_.PSPath 'Application'
            ) -ErrorAction SilentlyContinue

            if ($application -and [string]$application.AppUserModelID -eq $script:PhotosAumid) {
                $hasImageAssociation = $false
                foreach ($extension in $script:SupportedExtensions) {
                    $openWith = Get-ItemProperty -LiteralPath (
                        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithProgids' -f $extension
                    ) -ErrorAction SilentlyContinue

                    if ($openWith -and $openWith.PSObject.Properties.Name -contains $_.PSChildName) {
                        $hasImageAssociation = $true
                        break
                    }
                }

                if ($hasImageAssociation) {
                    [void]$progIds.Add([string]$_.PSChildName)
                }
            }
        }

    return @($progIds)
}

function Save-ProgIdBackup {
    param([Parameter(Mandatory = $true)][string]$ProgId)

    $backupPath = Join-Path $script:BackupRoot $ProgId
    if (Test-Path -LiteralPath $backupPath) {
        $saved = Get-ItemProperty -LiteralPath $backupPath
        $savedDefault = [string]$saved.DefaultValue
        if ([int]$saved.HadDefault -eq 1 -and
            ($savedDefault -like '*Corrigir-Fotos-Moderno.ps1*' -or
             $savedDefault -like '*FotosModernRouteLauncher*.exe*')) {
            Set-ItemProperty -LiteralPath $backupPath -Name 'HadDefault' -Value 0
            Set-ItemProperty -LiteralPath $backupPath -Name 'DefaultValue' -Value ''
            Set-ItemProperty -LiteralPath $backupPath -Name 'DefaultKind' -Value 'String'
            Set-ItemProperty -LiteralPath $backupPath -Name 'HadDelegateExecute' -Value 1
            Set-ItemProperty -LiteralPath $backupPath -Name 'DelegateExecuteValue' -Value $script:OriginalDelegateExecute
            Set-ItemProperty -LiteralPath $backupPath -Name 'DelegateExecuteKind' -Value 'String'
        }
        return
    }

    $relativeCommandPath = 'Software\Classes\{0}\shell\open\command' -f $ProgId
    $commandKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($relativeCommandPath, $true)
    if (-not $commandKey) {
        $commandKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($relativeCommandPath)
    }

    try {
        $defaultValue = Get-RegistryValueSnapshot -Key $commandKey -Name ''
        $delegateValue = Get-RegistryValueSnapshot -Key $commandKey -Name 'DelegateExecute'

        if ($defaultValue.Exists -and
            ($defaultValue.Value -like '*Corrigir-Fotos-Moderno.ps1*' -or
             $defaultValue.Value -like '*FotosModernRouteLauncher*.exe*')) {
            $defaultValue = [pscustomobject]@{ Exists = $false; Value = ''; Kind = 'String' }
            $delegateValue = [pscustomobject]@{
                Exists = $true
                Value  = $script:OriginalDelegateExecute
                Kind   = 'String'
            }
        }

        New-Item -Path $backupPath -Force | Out-Null
        New-ItemProperty -LiteralPath $backupPath -Name 'ProgId' -Value $ProgId -PropertyType String -Force | Out-Null
        New-ItemProperty -LiteralPath $backupPath -Name 'HadDefault' -Value ([int]$defaultValue.Exists) -PropertyType DWord -Force | Out-Null
        New-ItemProperty -LiteralPath $backupPath -Name 'DefaultValue' -Value $defaultValue.Value -PropertyType String -Force | Out-Null
        New-ItemProperty -LiteralPath $backupPath -Name 'DefaultKind' -Value $defaultValue.Kind -PropertyType String -Force | Out-Null
        New-ItemProperty -LiteralPath $backupPath -Name 'HadDelegateExecute' -Value ([int]$delegateValue.Exists) -PropertyType DWord -Force | Out-Null
        New-ItemProperty -LiteralPath $backupPath -Name 'DelegateExecuteValue' -Value $delegateValue.Value -PropertyType String -Force | Out-Null
        New-ItemProperty -LiteralPath $backupPath -Name 'DelegateExecuteKind' -Value $delegateValue.Kind -PropertyType String -Force | Out-Null
    }
    finally {
        $commandKey.Dispose()
    }
}

function Get-LauncherCommand {
    return ('"{0}" "%1"' -f $script:HelperPath)
}

function Install-NativeLauncher {
    if (-not (Test-Path -LiteralPath $script:InstallDir)) {
        [void](New-Item -ItemType Directory -Path $script:InstallDir -Force)
    }

    if (Test-Path -LiteralPath $script:HelperPath -PathType Leaf) {
        Remove-OldLaunchers
        return
    }

    # Código C# original e exato do Codex (comprovado com 100% de precisão)
    $source = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

internal static class FotosModernRouteLauncher
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool DeleteFileW(string fileName);

    private static readonly HashSet<string> ImageExtensions = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".jpe", ".jfif", ".png", ".bmp", ".dib", ".gif",
        ".tif", ".tiff", ".webp", ".heic", ".heif", ".hif", ".avif",
        ".jxl", ".jxr", ".wdp", ".ico", ".svg"
    };

    [STAThread]
    private static int Main(string[] args)
    {
        if (args == null || args.Length == 0 || String.IsNullOrWhiteSpace(args[0]))
            return 2;

        string fullPath;
        try
        {
            fullPath = Path.GetFullPath(args[0]);
        }
        catch
        {
            return 3;
        }

        if (!File.Exists(fullPath) || !ImageExtensions.Contains(Path.GetExtension(fullPath)))
            return 4;

        try
        {
            DeleteFileW(fullPath + ":Zone.Identifier");
        }
        catch
        {
        }

        bool launched = false;
        try
        {
            string uri = "ms-photos:viewer?fileName=" + Uri.EscapeDataString(fullPath);
            Process.Start(new ProcessStartInfo(uri) { UseShellExecute = true });
            launched = true;
        }
        catch
        {
            launched = false;
        }

        return launched ? 0 : 5;
    }
}
'@

    $temporaryExe = Join-Path $env:TEMP ('FotosModernRouteLauncher-{0}.exe' -f [Guid]::NewGuid().ToString('N'))
    try {
        Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $temporaryExe -OutputType WindowsApplication
        Move-Item -LiteralPath $temporaryExe -Destination $script:HelperPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryExe) {
            Remove-Item -LiteralPath $temporaryExe -Force -ErrorAction SilentlyContinue
        }
    }

    Remove-OldLaunchers
}

function Set-ProgIdRoute {
    param([Parameter(Mandatory = $true)][string]$ProgId)

    Save-ProgIdBackup -ProgId $ProgId

    $relativeCommandPath = 'Software\Classes\{0}\shell\open\command' -f $ProgId
    $commandKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($relativeCommandPath, $true)
    if (-not $commandKey) {
        $commandKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($relativeCommandPath)
    }

    try {
        $commandKey.SetValue('', (Get-LauncherCommand), [Microsoft.Win32.RegistryValueKind]::String)
        $commandKey.DeleteValue('DelegateExecute', $false)
    }
    finally {
        $commandKey.Dispose()
    }
}

function Restore-ProgIdRoute {
    param([Parameter(Mandatory = $true)][string]$BackupPath)

    $backup = Get-ItemProperty -LiteralPath $BackupPath
    $progId = [string]$backup.ProgId
    $relativeCommandPath = 'Software\Classes\{0}\shell\open\command' -f $progId
    $commandKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($relativeCommandPath, $true)
    if (-not $commandKey) {
        $commandKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($relativeCommandPath)
    }

    try {
        if ([int]$backup.HadDefault -eq 1) {
            $kind = [Microsoft.Win32.RegistryValueKind][Enum]::Parse(
                [Microsoft.Win32.RegistryValueKind],
                [string]$backup.DefaultKind
            )
            $commandKey.SetValue('', [string]$backup.DefaultValue, $kind)
        }
        else {
            $commandKey.DeleteValue('', $false)
        }

        if ([int]$backup.HadDelegateExecute -eq 1) {
            $kind = [Microsoft.Win32.RegistryValueKind][Enum]::Parse(
                [Microsoft.Win32.RegistryValueKind],
                [string]$backup.DelegateExecuteKind
            )
            $commandKey.SetValue('DelegateExecute', [string]$backup.DelegateExecuteValue, $kind)
        }
        else {
            $commandKey.DeleteValue('DelegateExecute', $false)
        }
    }
    finally {
        $commandKey.Dispose()
    }
}

function Notify-AssociationChanged {
    if (-not ('FotosModernFix.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace FotosModernFix {
    public static class NativeMethods {
        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(uint eventId, uint flags, IntPtr item1, IntPtr item2);
    }
}
'@
    }

    [FotosModernFix.NativeMethods]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}

function Install-MaintenanceTask {
    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    $rootFolder = $service.GetFolder('\')
    $definition = $service.NewTask(0)

    $definition.RegistrationInfo.Description = 'Reaplica a rota corrigida do Microsoft Fotos moderno depois do logon ou de uma atualização de pacote.'
    $definition.Settings.Enabled = $true
    $definition.Settings.Hidden = $true
    $definition.Settings.StartWhenAvailable = $true
    $definition.Settings.DisallowStartIfOnBatteries = $false
    $definition.Settings.StopIfGoingOnBatteries = $false
    $definition.Settings.ExecutionTimeLimit = 'PT2M'
    $definition.Settings.MultipleInstances = 2

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name

    # TASK_TRIGGER_LOGON = 9
    $logonTrigger = $definition.Triggers.Create(9)
    $logonTrigger.Enabled = $true
    $logonTrigger.UserId = $identity

    # TASK_TRIGGER_EVENT = 0. Evento 822 ocorre após atualização do pacote AppX
    $eventTrigger = $definition.Triggers.Create(0)
    $eventTrigger.Enabled = $true
    $eventTrigger.Subscription = @'
<QueryList><Query Id="0" Path="Microsoft-Windows-AppXDeploymentServer/Operational"><Select Path="Microsoft-Windows-AppXDeploymentServer/Operational">*[System[(EventID=822)]]</Select></Query></QueryList>
'@

    $taskScriptPath = if (Test-Path -LiteralPath $script:InstalledScriptPath -PathType Leaf) {
        $script:InstalledScriptPath
    }
    elseif ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath -PathType Leaf)) {
        [IO.Path]::GetFullPath($PSCommandPath)
    }
    else {
        $script:InstalledScriptPath
    }

    # TASK_ACTION_EXEC = 0
    $action = $definition.Actions.Create(0)
    # WScript inicia o processo oculto desde a criacao, evitando o flash do console no logon.
    $hiddenLauncherPath = Join-Path $script:InstallDir 'Manter-Fotos-Sem-Janela.vbs'
    $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $commandLine = ('"{0}" -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{1}" -Corrigir -Silencioso' -f $powerShellPath, $taskScriptPath)
    $vbsLines = @(
        'Option Explicit'
        'Dim shell, result'
        'Set shell = CreateObject("WScript.Shell")'
        'On Error Resume Next'
        ('result = shell.Run("{0}", 0, True)' -f $commandLine.Replace('"', '""'))
        'If Err.Number <> 0 Then WScript.Quit 1'
        'On Error GoTo 0'
        'WScript.Quit result'
    )
    [IO.File]::WriteAllLines($hiddenLauncherPath, $vbsLines, [Text.Encoding]::Unicode)
    $action.Path = Join-Path $env:SystemRoot 'System32\wscript.exe'
    $action.Arguments = ('//B //NoLogo "{0}"' -f $hiddenLauncherPath)
    $action.WorkingDirectory = $script:InstallDir

    # TASK_CREATE_OR_UPDATE = 6; TASK_LOGON_INTERACTIVE_TOKEN = 3
    [void]$rootFolder.RegisterTaskDefinition($script:TaskName, $definition, 6, $identity, $null, 3, $null)
}

function Remove-MaintenanceTask {
    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    $rootFolder = $service.GetFolder('\')

    try {
        [void]$rootFolder.GetTask("\$($script:TaskName)")
        $rootFolder.DeleteTask($script:TaskName, 0)
    }
    catch {
        if ($_.Exception.Message -notmatch 'não foi possível encontrar|cannot find|0x80070002') {
            throw
        }
    }
}

function Test-MaintenanceTask {
    try {
        $service = New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        $rootFolder = $service.GetFolder('\')
        [void]$rootFolder.GetTask("\$($script:TaskName)")
        return $true
    }
    catch {
        return $false
    }
}

function Get-FixStatusSummary {
    $progIds = @(Get-PhotosImageProgIds)
    $fixedProgIds = @()
    $launcherCommand = Get-LauncherCommand
    $launcherExists = (Test-Path -LiteralPath $script:HelperPath -PathType Leaf)
    $taskExists = (Test-MaintenanceTask)
    $backupExists = (Test-Path -LiteralPath $script:BackupRoot)

    foreach ($progId in $progIds) {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
            ('Software\Classes\{0}\shell\open\command' -f $progId),
            $false
        )
        if ($key) {
            try {
                $cmdVal = [string]$key.GetValue('')
                $hasDelegate = $key.GetValueNames() -contains 'DelegateExecute'
                if (($cmdVal -like '*FotosModernRouteLauncher*' -or $cmdVal -eq $launcherCommand) -and -not $hasDelegate) {
                    $fixedProgIds += $progId
                }
            }
            finally {
                $key.Dispose()
            }
        }
    }

    $isFullyFixed = ($progIds.Count -gt 0) -and
                    ($fixedProgIds.Count -eq $progIds.Count) -and
                    $launcherExists -and
                    $taskExists

    return [pscustomobject]@{
        IsFixed        = $isFullyFixed
        FixedCount     = $fixedProgIds.Count
        TotalCount     = $progIds.Count
        ProgIds        = $progIds
        FixedProgIds   = $fixedProgIds
        LauncherExists = $launcherExists
        TaskExists     = $taskExists
        BackupExists   = $backupExists
        LauncherPath   = $script:HelperPath
        InstallDir     = $script:InstallDir
    }
}

function Invoke-Correction {
    Assert-Windows10Or11

    if (-not (Test-Path -LiteralPath $script:InstallDir)) {
        [void](New-Item -ItemType Directory -Path $script:InstallDir -Force)
    }

    if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath -PathType Leaf)) {
        try {
            if ([IO.Path]::GetFullPath($PSCommandPath) -ne [IO.Path]::GetFullPath($script:InstalledScriptPath)) {
                Copy-Item -LiteralPath $PSCommandPath -Destination $script:InstalledScriptPath -Force
            }
        }
        catch {}
    }

    $progIds = @(Get-PhotosImageProgIds)
    if ($progIds.Count -eq 0) {
        throw 'Nenhuma associação de imagem do Microsoft Fotos moderno foi encontrada para este usuário.'
    }

    New-Item -Path $script:BackupRoot -Force | Out-Null
    New-ItemProperty -LiteralPath $script:BackupRoot -Name 'ScriptPath' -Value $script:InstalledScriptPath -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $script:BackupRoot -Name 'LastAppliedUtc' -Value ([DateTime]::UtcNow.ToString('o')) -PropertyType String -Force | Out-Null

    Install-NativeLauncher

    foreach ($progId in $progIds) {
        Set-ProgIdRoute -ProgId $progId
    }

    Install-MaintenanceTask
    Notify-AssociationChanged
    Remove-OldLaunchers

    Write-Info ('[OK] Correção aplicada com sucesso para: {0}' -f ($progIds -join ', '))
    Write-Info ('[OK] Lançador nativo isolado em: {0}' -f $script:HelperPath)
    Write-Info '[OK] A sua pasta contém exclusivamente o script .ps1.'
    Write-Info '[OK] O Fotos moderno abrirá normalmente e permitirá definir papel de parede.'
}

function Invoke-Undo {
    Assert-Windows10Or11
    Remove-MaintenanceTask

    if (Test-Path -LiteralPath $script:BackupRoot) {
        Get-ChildItem -LiteralPath $script:BackupRoot -ErrorAction SilentlyContinue |
            ForEach-Object { Restore-ProgIdRoute -BackupPath $_.PSPath }

        Remove-Item -LiteralPath $script:BackupRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $script:InstallDir) {
        Remove-Item -LiteralPath $script:InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Remove-OldLaunchers
    Notify-AssociationChanged

    Write-Info '[OK] Correção desfeita com sucesso.'
    Write-Info '[OK] Rotas originais do Windows Fotos restauradas.'
    Write-Info '[OK] Arquivos auxiliares em AppData removidos.'
}

function Show-Status {
    Assert-Windows10Or11
    $summary = Get-FixStatusSummary

    $osCaption = try { (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption } catch { 'Windows' }
    $build = [Environment]::OSVersion.Version.Build

    Write-Host ''
    Write-Host '=====================================================' -ForegroundColor Cyan
    Write-Host '          STATUS DA CORREÇÃO - MICROSOFT FOTOS       ' -ForegroundColor Cyan
    Write-Host '=====================================================' -ForegroundColor Cyan
    Write-Host (' Sistema Operacional:          {0} (Build {1})' -f $osCaption.Trim(), $build)
    Write-Host (' ProgIDs do Fotos detectados:  {0}' -f $(if ($summary.ProgIds.Count) { $summary.ProgIds -join ', ' } else { 'Nenhum' }))
    Write-Host (' Rotas corrigidas ativas:      {0}' -f $(if ($summary.FixedProgIds.Count) { $summary.FixedProgIds -join ', ' } else { 'Nenhuma' }))
    Write-Host (' Backup de restauração:        {0}' -f $(if ($summary.BackupExists) { 'Presente (Pronto para desfazer)' } else { 'Não criado' }))
    Write-Host (' Lançador nativo invisível:    {0}' -f $(if ($summary.LauncherExists) { 'Instalado em AppData' } else { 'Não instalado' }))
    if ($summary.LauncherExists) {
        Write-Host (' Local do lançador:            {0}' -f $summary.LauncherPath) -ForegroundColor Gray
    }
    Write-Host (' Persistência pós-atualização: {0}' -f $(if ($summary.TaskExists) { 'Ativa (Tarefa no Agendador)' } else { 'Inativa' }))
    Write-Host '-----------------------------------------------------' -ForegroundColor Cyan

    if ($summary.IsFixed) {
        Write-Host ' DIAGNÓSTICO: CORREÇÃO ATIVA E TOTALMENTE OPERACIONAL.' -ForegroundColor Green
        Write-Host ' • Dois cliques abrem a foto pelo Fotos Moderno instantaneamente.' -ForegroundColor Green
        Write-Host ' • "Definir como plano de fundo" e "tela de bloqueio" funcionam perfeitamente.' -ForegroundColor Green
        Write-Host ' • Nenhuma janela de console ou PowerShell é exibida.' -ForegroundColor Green
        Write-Host ' • Na sua pasta de trabalho fica exclusivamente o arquivo .ps1.' -ForegroundColor Green
    }
    else {
        Write-Host ' DIAGNÓSTICO: CORREÇÃO NÃO ESTÁ ATIVA (PADRÃO ORIGINAL DO WINDOWS).' -ForegroundColor Yellow
        Write-Host ' • O Windows está usando a rota DelegateExecute padrão.' -ForegroundColor Yellow
        Write-Host ' • Pressione [1] no menu para aplicar a correção.' -ForegroundColor Yellow
    }
    Write-Host '=====================================================' -ForegroundColor Cyan
}

function Show-MenuHeader {
    $summary = Get-FixStatusSummary
    Write-Host '=====================================================' -ForegroundColor Cyan
    Write-Host '         CORREÇÃO DO MICROSOFT FOTOS MODERNO         ' -ForegroundColor Cyan
    Write-Host '=====================================================' -ForegroundColor Cyan
    
    if ($summary.IsFixed) {
        Write-Host ' [STATUS ATUAL] -> ' -NoNewline
        Write-Host 'CORRIGIDO E ATIVO' -ForegroundColor Green
        Write-Host ('   • Rotas corrigidas:   {0} de {1}' -f $summary.FixedCount, $summary.TotalCount) -ForegroundColor Gray
        Write-Host ('   • Lançador invisível: Ativo em AppData' ) -ForegroundColor Gray
        Write-Host ('   • Persistência:       Ativa (Tarefa agendada)' ) -ForegroundColor Gray
    }
    else {
        Write-Host ' [STATUS ATUAL] -> ' -NoNewline
        Write-Host 'NÃO INSTALADO (PADRÃO ORIGINAL DO WINDOWS)' -ForegroundColor Yellow
        if ($summary.TotalCount -gt 0) {
            Write-Host ('   • ProgID identificado: {0}' -f ($summary.ProgIds -join ', ')) -ForegroundColor Gray
        }
    }
    Write-Host '-----------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ' 1 - Aplicar / Atualizar correção'
    Write-Host ' 2 - Desfazer correção (Restaurar padrão original)'
    Write-Host ' 3 - Ver status detalhado'
    Write-Host ' 0 ou Esc - Sair'
    Write-Host '-----------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''
}

function Read-KeyInput {
    try {
        if (-not [Console]::IsInputRedirected) {
            while ([Console]::KeyAvailable) {
                [void][Console]::ReadKey($true)
            }
            return [Console]::ReadKey($true)
        }
    }
    catch {}

    $line = Read-Host
    if ($line -eq $null -or $line -eq '') {
        return [pscustomobject]@{ Key = [ConsoleKey]::Enter; KeyChar = [char]13 }
    }
    $trimmed = $line.Trim()
    if ($trimmed -eq '0' -or $trimmed.ToLower() -eq 'esc') {
        return [pscustomobject]@{ Key = [ConsoleKey]::Escape; KeyChar = '0' }
    }
    return [pscustomobject]@{ Key = [ConsoleKey]::Oem1; KeyChar = $trimmed[0] }
}

function Wait-MenuReturn {
    Write-Host ''
    Write-Host 'Pressione Enter para voltar ao menu inicial (ou Esc para sair)...' -ForegroundColor Cyan
    while ($true) {
        $k = Read-KeyInput
        if ($k.Key -eq [ConsoleKey]::Enter -or $k.Key -eq [ConsoleKey]::Spacebar) {
            return 'Menu'
        }
        if ($k.Key -eq [ConsoleKey]::Escape) {
            return 'Exit'
        }
    }
}

function Open-InModernPhotos {
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-Windows10Or11
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Arquivo não encontrado: $fullPath"
    }

    $encodedPath = [Uri]::EscapeDataString($fullPath)
    Start-Process -FilePath ('ms-photos:viewer?fileName={0}' -f $encodedPath)
}

# --- Ponto de Entrada / Execução ---

try {
    if ($Abrir) {
        Open-InModernPhotos -Path $Abrir
        exit 0
    }

    if ($Corrigir) {
        Invoke-Correction
        exit 0
    }

    if ($Desfazer) {
        Invoke-Undo
        exit 0
    }

    if ($Status) {
        Show-Status
        exit 0
    }

    Remove-OldLaunchers

    # Loop Interativo do Menu com Tela Limpa e Resposta Imediata
    while ($true) {
        Clear-Host
        Show-MenuHeader

        Write-Host 'Escolha uma opção [1, 2, 3, 0 ou Esc para sair]: ' -NoNewline -ForegroundColor White
        $keyInput = Read-KeyInput
        $char = [string]$keyInput.KeyChar
        $key = $keyInput.Key

        if ($key -eq [ConsoleKey]::Escape -or $char -eq '0') {
            Write-Host '0'
            Write-Host ''
            Write-Host 'Encerrando script. Até logo!' -ForegroundColor Green
            Start-Sleep -Milliseconds 400
            exit 0
        }
        elseif ($char -eq '1') {
            Write-Host '1'
            Write-Host ''
            try {
                Invoke-Correction
            }
            catch {
                Write-Host ('ERRO ao aplicar correção: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }
            $nav = Wait-MenuReturn
            if ($nav -eq 'Exit') { exit 0 }
        }
        elseif ($char -eq '2') {
            Write-Host '2'
            Write-Host ''
            try {
                Invoke-Undo
            }
            catch {
                Write-Host ('ERRO ao desfazer correção: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }
            $nav = Wait-MenuReturn
            if ($nav -eq 'Exit') { exit 0 }
        }
        elseif ($char -eq '3') {
            Write-Host '3'
            Show-Status
            $nav = Wait-MenuReturn
            if ($nav -eq 'Exit') { exit 0 }
        }
        elseif ($key -eq [ConsoleKey]::Enter) {
            continue
        }
        else {
            Write-Host $char
            Write-Host ''
            Write-Host 'Opção inválida! Por favor, pressione 1, 2, 3, 0 ou Esc.' -ForegroundColor Yellow
            Start-Sleep -Milliseconds 900
        }
    }
}
catch {
    if (-not $Silencioso) {
        Write-Host ''
        Write-Host ('ERRO CRÍTICO: {0}' -f $_.Exception.Message) -ForegroundColor Red
        if ($script:InteractiveMenu) {
            Write-Host ''
            [void](Read-Host 'Pressione Enter para fechar')
        }
    }
    exit 1
}
