param()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Resolve the folder containing the running program in both script and compiled EXE modes.
# $script:AppRoot can be empty in a PS2EXE-compiled executable.
$script:AppRoot = $null
try {
    if(-not [string]::IsNullOrWhiteSpace($PSScriptRoot)){
        $script:AppRoot = $PSScriptRoot
    }
} catch {}

if([string]::IsNullOrWhiteSpace($script:AppRoot)){
    try {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if(-not [string]::IsNullOrWhiteSpace($exePath)){
            $script:AppRoot = [IO.Path]::GetDirectoryName($exePath)
        }
    } catch {}
}

if([string]::IsNullOrWhiteSpace($script:AppRoot)){
    $script:AppRoot = [Environment]::CurrentDirectory
}

function New-RoundedRectPath {
    param(
        [Drawing.Rectangle]$Rect,
        [int]$Radius
    )
    $path=New-Object Drawing.Drawing2D.GraphicsPath
    $d=[Math]::Max(2,$Radius*2)
    $path.AddArc($Rect.X,$Rect.Y,$d,$d,180,90)
    $path.AddArc($Rect.Right-$d,$Rect.Y,$d,$d,270,90)
    $path.AddArc($Rect.Right-$d,$Rect.Bottom-$d,$d,$d,0,90)
    $path.AddArc($Rect.X,$Rect.Bottom-$d,$d,$d,90,90)
    $path.CloseFigure()
    return $path
}

function Set-GlassPanelBitmap { param() }

function Set-GlassButtonStyle {
    param(
        [Windows.Forms.Button]$Button,
        [bool]$Dark,
        [bool]$Accent=$false,
        [bool]$Selected=$false
    )
    if(-not $Button){return}

    $Button.FlatStyle="Flat"
    $Button.FlatAppearance.BorderSize=1
    $Button.Cursor=[Windows.Forms.Cursors]::Hand
    $Button.UseVisualStyleBackColor=$false

    if($Accent -or $Selected){
        $Button.BackColor=[Drawing.Color]::FromArgb(51,110,245)
        $Button.ForeColor=[Drawing.Color]::White
        $Button.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(105,158,255)
        $Button.FlatAppearance.MouseOverBackColor=[Drawing.Color]::FromArgb(68,128,255)
        $Button.FlatAppearance.MouseDownBackColor=[Drawing.Color]::FromArgb(39,91,220)
    }elseif($Dark){
        $Button.BackColor=[Drawing.Color]::FromArgb(28,45,68)
        $Button.ForeColor=[Drawing.Color]::FromArgb(245,248,253)
        $Button.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(78,109,150)
        $Button.FlatAppearance.MouseOverBackColor=[Drawing.Color]::FromArgb(38,59,87)
        $Button.FlatAppearance.MouseDownBackColor=[Drawing.Color]::FromArgb(20,36,58)
    }else{
        $Button.BackColor=[Drawing.Color]::FromArgb(248,251,255)
        $Button.ForeColor=[Drawing.Color]::FromArgb(31,53,86)
        $Button.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(203,214,234)
        $Button.FlatAppearance.MouseOverBackColor=[Drawing.Color]::FromArgb(236,243,255)
        $Button.FlatAppearance.MouseDownBackColor=[Drawing.Color]::FromArgb(224,235,252)
    }
}

function Set-MainBackgroundBitmap { param() }


$script:DarkMode=$true


# ---------- UI helper functions ----------
function Set-RoundedRegion {
    param(
        [System.Windows.Forms.Control]$Control,
        [int]$Radius = 12
    )

    # Rounding is cosmetic only. Never allow it to break the installer.
    if(-not $Control -or $Control.Width -lt 2 -or $Control.Height -lt 2){ return }

    try {
        $rect = New-Object Drawing.Rectangle(0,0,$Control.Width,$Control.Height)
        $path = New-RoundedRectPath -Rect $rect -Radius $Radius

        if($Control.Region){
            try{$Control.Region.Dispose()}catch{}
        }

        $Control.Region = New-Object Drawing.Region($path)
        $path.Dispose()
    } catch {
        # Cosmetic failure: intentionally ignored.
    }
}

function Apply-RoundedLayout {
    # Keep this deliberately conservative and safe.
    try {
        foreach($item in @(
            @($installerNavButton,10),
            @($debugNavButton,10),
            @($darkThemeButton,10),
            @($lightThemeButton,10),
            @($selectButton,9),
            @($detectButton,9),
            @($installButton,10),
            @($verifyButton,9),
            @($repairButton,9),
            @($dgVoodooButton,9),
            @($feedFixButton,9),
            @($sr2IsolationButton,9),
            @($smallerLogButton,8),
            @($largerLogButton,8),
            @($openButton,9),
            @($copyDebugButton,9),
            @($saveDebugButton,9),
            @($clearDebugButton,9),
            @($loadGameLogsButton,9),
            @($openCollectedLogsButton,9),
            @($themeCard,12),
            @($adminCard,12),
            @($gameCard,12),
            @($infoCard,12),
            @($actionCard,12),
            @($statusCard,12),
            @($debugToolbar,12),
            @($adminDot,8),
            @($darkDot,8),
            @($lightDot,8)
        )){
            if($item[0]){
                Set-RoundedRegion -Control $item[0] -Radius $item[1]
            }
        }
    } catch {
        # Cosmetic failure: intentionally ignored.
    }
}

function Set-WindowsBackdrop {
    # The UI does not depend on DWM effects. This helper is intentionally
    # non-fatal so unsupported Windows versions can never break the program.
    try {
        if(-not $form -or -not $form.IsHandleCreated){ return }

        if(-not ("DLSS5Dwm" -as [type])){
            Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class DLSS5Dwm {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(
        IntPtr hwnd, int attr, ref int value, int size);
}
"@
        }

        # Dark title-bar preference.
        $dark = if($script:DarkMode){1}else{0}
        [void][DLSS5Dwm]::DwmSetWindowAttribute($form.Handle,20,[ref]$dark,4)
    } catch {
        # DWM support is optional.
    }
}

# ---------- Uniform theme ----------
$Theme = @{
    Dark = @{
        Form        = [Drawing.Color]::FromArgb(15,18,24)
        Sidebar     = [Drawing.Color]::FromArgb(19,23,31)
        Surface     = [Drawing.Color]::FromArgb(24,29,39)
        Surface2    = [Drawing.Color]::FromArgb(29,35,47)
        Input       = [Drawing.Color]::FromArgb(18,22,30)
        Text        = [Drawing.Color]::FromArgb(240,244,248)
        Muted       = [Drawing.Color]::FromArgb(151,161,176)
        Accent      = [Drawing.Color]::FromArgb(70,124,242)
        AccentHover = [Drawing.Color]::FromArgb(84,139,255)
        Border      = [Drawing.Color]::FromArgb(53,62,77)
        Warning     = [Drawing.Color]::FromArgb(245,170,55)
        Success     = [Drawing.Color]::FromArgb(54,201,112)
    }
    Light = @{
        Form        = [Drawing.Color]::FromArgb(245,247,250)
        Sidebar     = [Drawing.Color]::FromArgb(238,242,247)
        Surface     = [Drawing.Color]::FromArgb(255,255,255)
        Surface2    = [Drawing.Color]::FromArgb(248,250,253)
        Input       = [Drawing.Color]::FromArgb(255,255,255)
        Text        = [Drawing.Color]::FromArgb(29,36,47)
        Muted       = [Drawing.Color]::FromArgb(100,112,128)
        Accent      = [Drawing.Color]::FromArgb(53,104,224)
        AccentHover = [Drawing.Color]::FromArgb(68,119,239)
        Border      = [Drawing.Color]::FromArgb(210,217,226)
        Warning     = [Drawing.Color]::FromArgb(198,117,22)
        Success     = [Drawing.Color]::FromArgb(29,164,87)
    }
}

function Apply-Theme {
    try {
        $t = if($script:DarkMode){$Theme.Dark}else{$Theme.Light}

        # Entire app follows one palette.
        $form.BackColor=$t.Form
        $form.ForeColor=$t.Text
        $sidebar.BackColor=$t.Sidebar
        $contentHost.BackColor=$t.Form
        $installerPanel.BackColor=$t.Form
        $debugPanel.BackColor=$t.Form

        # Remove old generated background images that caused mismatched colors.
        foreach($p in @($sidebar,$contentHost,$themeCard,$adminCard,$gameCard,$infoCard,$actionCard,$statusCard,$debugToolbar)){
            if($p -and $p.BackgroundImage){
                try{$p.BackgroundImage.Dispose()}catch{}
                $p.BackgroundImage=$null
            }
        }

        foreach($card in @($themeCard,$adminCard,$gameCard,$infoCard,$actionCard,$statusCard,$debugToolbar)){
            if($card){
                $card.BackColor=$t.Surface
                $card.ForeColor=$t.Text
            }
        }

        # Secondary buttons.
        foreach($b in @($selectButton,$detectButton,$verifyButton,$repairButton,$dgVoodooButton,$feedFixButton,$sr2IsolationButton,$openButton,$smallerLogButton,$largerLogButton,
                        $copyDebugButton,$saveDebugButton,$clearDebugButton,$loadGameLogsButton,$openCollectedLogsButton)){
            if($b){
                $b.FlatStyle="Flat"
                $b.FlatAppearance.BorderSize=1
                $b.FlatAppearance.BorderColor=$t.Border
                $b.FlatAppearance.MouseOverBackColor=$t.Surface2
                $b.FlatAppearance.MouseDownBackColor=$t.Surface2
                $b.BackColor=$t.Surface2
                $b.ForeColor=$t.Text
                $b.UseVisualStyleBackColor=$false
                $b.Cursor=[Windows.Forms.Cursors]::Hand
            }
        }

        # Primary action.
        $installButton.FlatStyle="Flat"
        $installButton.FlatAppearance.BorderSize=0
        $installButton.FlatAppearance.MouseOverBackColor=$t.AccentHover
        $installButton.FlatAppearance.MouseDownBackColor=$t.Accent
        $installButton.BackColor=$t.Accent
        $installButton.ForeColor=[Drawing.Color]::White
        $installButton.UseVisualStyleBackColor=$false

        # Navigation.
        foreach($nav in @($installerNavButton,$debugNavButton)){
            $nav.FlatStyle="Flat"
            $nav.FlatAppearance.BorderSize=0
            $nav.UseVisualStyleBackColor=$false
            $nav.Cursor=[Windows.Forms.Cursors]::Hand
        }
        if($installerPanel.Visible){
            $installerNavButton.BackColor=$t.Accent
            $installerNavButton.ForeColor=[Drawing.Color]::White
            $debugNavButton.BackColor=$t.Sidebar
            $debugNavButton.ForeColor=$t.Text
        }else{
            $debugNavButton.BackColor=$t.Accent
            $debugNavButton.ForeColor=[Drawing.Color]::White
            $installerNavButton.BackColor=$t.Sidebar
            $installerNavButton.ForeColor=$t.Text
        }

        # Theme selector.
        foreach($b in @($darkThemeButton,$lightThemeButton)){
            $b.FlatStyle="Flat"
            $b.FlatAppearance.BorderSize=0
            $b.UseVisualStyleBackColor=$false
        }
        if($script:DarkMode){
            $darkThemeButton.BackColor=$t.Accent
            $darkThemeButton.ForeColor=[Drawing.Color]::White
            $lightThemeButton.BackColor=$t.Surface2
            $lightThemeButton.ForeColor=$t.Text
            $darkDot.BackColor=[Drawing.Color]::White
            $lightDot.BackColor=$t.Muted
        }else{
            $lightThemeButton.BackColor=$t.Accent
            $lightThemeButton.ForeColor=[Drawing.Color]::White
            $darkThemeButton.BackColor=$t.Surface2
            $darkThemeButton.ForeColor=$t.Text
            $lightDot.BackColor=[Drawing.Color]::White
            $darkDot.BackColor=$t.Muted
        }

        # Inputs.
        foreach($tb in @($gamePathBox,$logBox)){
            $tb.BackColor=$t.Input
            $tb.ForeColor=$t.Text
            $tb.BorderStyle="FixedSingle"
        }
        $apiCombo.BackColor=$t.Input
        $apiCombo.ForeColor=$t.Text
        $apiCombo.FlatStyle="Flat"

        # Text hierarchy.
        foreach($label in @($brandLabel,$title,$gameSectionTitle,$rendererLabel,$infoSectionTitle,
                            $actionsTitle,$statusTitle,$debugTitle,$logLabel,$archLabel,$profileLabel,
                            $detectLabel,$archValue,$profileValue,$detectValue,$themeLabel,
                            $adminLabel,$adminVersionLabel,$settingsLabel,$aboutLabel)){
            if($label){$label.ForeColor=$t.Text}
        }
        foreach($label in @($versionLabel,$subtitle,$reasonValue,$footer,$statusLabel,$debugSubtitle)){
            if($label){$label.ForeColor=$t.Muted}
        }

        $warning.ForeColor=$t.Warning
        if($installerMiniConsole){
            $installerMiniConsole.ForeColor=$t.Warning
            $installerMiniConsole.BackColor=$t.Surface
        }
        $adminDot.BackColor=$t.Success

        Apply-RoundedLayout
        Set-WindowsBackdrop
        $form.Invalidate()
    } catch {
        # Styling must never interrupt installation/repair operations.
        try {
            if($logBox){
                $logBox.AppendText("[UI] Theme refresh failed: $($_.Exception.Message)`r`n")
            }
        } catch {}
    }
}
$script:InstallerMiniLogLines=New-Object System.Collections.Generic.List[string]

function Write-Log {
    param([string]$Text)
    $stamp = (Get-Date).ToString("HH:mm:ss")
    $line="[$stamp] $Text"

    $logBox.AppendText("$line`r`n")
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()

    try {
        if(-not $script:InstallerMiniLogLines){
            $script:InstallerMiniLogLines=New-Object System.Collections.Generic.List[string]
        }
        $script:InstallerMiniLogLines.Add($line)
        while($script:InstallerMiniLogLines.Count -gt 2){
            $script:InstallerMiniLogLines.RemoveAt(0)
        }
        if($installerMiniConsole){
            $installerMiniConsole.Text=($script:InstallerMiniLogLines -join "`r`n")
        }
    } catch {}

    [System.Windows.Forms.Application]::DoEvents()
}

function Get-PeArchitecture {
    param([string]$Path)
    try {
        $bytes = [IO.File]::ReadAllBytes($Path)
        if ($bytes.Length -lt 64) { return "Unknown" }
        $peOffset = [BitConverter]::ToInt32($bytes,0x3C)
        $machine = [BitConverter]::ToUInt16($bytes,$peOffset+4)
        switch ($machine) {
            0x014c { "32-bit (x86)" }
            0x8664 { "64-bit (x64)" }
            default { ("Unknown (0x{0:X4})" -f $machine) }
        }
    } catch { "Unknown" }
}

function Get-GameProfile {
    param([string]$ExePath)
    $dir = Split-Path -Parent $ExePath
    $name = [IO.Path]::GetFileName($ExePath)

    if ($ExePath -match '\\Binaries\\Win64\\') { return "Unreal Engine / Win64" }
    if ($ExePath -match '\\Binaries\\Win32\\') { return "Unreal Engine / Win32" }
    if (Test-Path (Join-Path $dir "UnityPlayer.dll")) { return "Unity" }
    if (Test-Path (Join-Path $dir "GameAssembly.dll")) { return "Unity / IL2CPP" }
    if ($name -match '(?i)launcher|bootstrap|updater|patcher') { return "Possible launcher" }
    if (Test-Path (Join-Path $dir "steam_api64.dll")) { return "Steam game / x64" }
    if (Test-Path (Join-Path $dir "steam_api.dll")) { return "Steam game / x86" }
    return "Generic Windows game"
}

function Get-RendererGuess {
    param([string]$ExePath)

    $dir = Split-Path -Parent $ExePath

    # Runtime evidence from ReShade.log takes priority over static guessing.
    $reshadeLog = Join-Path $dir "ReShade.log"
    if (Test-Path $reshadeLog) {
        try {
            $log = Get-Content -LiteralPath $reshadeLog -Raw -ErrorAction Stop

            # Important: some D3D11 games create a separate D3D12 device for
            # RenoDX/DLSS. That does NOT make the game a D3D12 renderer.
            if ($log -match '(?i)device-only D3D12 proxy from D3D11 host') {
                return [pscustomobject]@{
                    Api="DirectX 11"; Confidence="Runtime / High";
                    Reason="ReShade.log shows a D3D11 host. RenoDX later creates a separate device-only D3D12 proxy, so the game renderer is still DirectX 11."
                }
            }

            $d11 = [regex]::Match($log,'(?im)^.*Redirecting D3D11CreateDevice(?:AndSwapChain)?')
            $d12 = [regex]::Match($log,'(?im)^.*Redirecting D3D12CreateDevice')
            $d9  = [regex]::Match($log,'(?im)^.*Direct3DCreate9')

            if ($d11.Success -and (-not $d12.Success -or $d11.Index -lt $d12.Index)) {
                return [pscustomobject]@{
                    Api="DirectX 11"; Confidence="Runtime / High";
                    Reason="ReShade.log shows D3D11 device creation before any D3D12 device creation."
                }
            }
            if ($d12.Success -and -not $d11.Success) {
                return [pscustomobject]@{
                    Api="DirectX 12"; Confidence="Runtime / High";
                    Reason="ReShade.log shows native D3D12 device creation and no D3D11 device creation."
                }
            }
            if ($d9.Success -and -not $d11.Success -and -not $d12.Success) {
                return [pscustomobject]@{
                    Api="DirectX 9"; Confidence="Runtime / High";
                    Reason="ReShade.log shows Direct3D 9 activity."
                }
            }
        } catch {}
    }

    # Static fallback when the game has not been launched yet.
    $signals = New-Object System.Collections.Generic.List[string]

    try {
        $bytes = [IO.File]::ReadAllBytes($ExePath)
        $ascii = [Text.Encoding]::ASCII.GetString($bytes)

        if ($ascii -match '(?i)d3d12\.dll|D3D12CreateDevice|ID3D12Device') { $signals.Add("DX12:EXE") }
        if ($ascii -match '(?i)d3d11\.dll|D3D11CreateDevice|ID3D11Device') { $signals.Add("DX11:EXE") }
        if ($ascii -match '(?i)d3d10(_1)?\.dll|D3D10CreateDevice') { $signals.Add("DX10:EXE") }
        if ($ascii -match '(?i)d3d9\.dll|Direct3DCreate9') { $signals.Add("DX9:EXE") }
    } catch {}

    foreach ($pair in @(
        @("d3d12.dll","DX12:LOCAL"),
        @("d3d11.dll","DX11:LOCAL"),
        @("d3d10.dll","DX10:LOCAL")
    )) {
        if (Test-Path (Join-Path $dir $pair[0])) { $signals.Add($pair[1]) }
    }

    if ((Test-Path (Join-Path $dir "dlss5-dx11-bridge.addon64")) -or
        (Test-Path (Join-Path $dir "dlss5-dx11-bridge.addon32"))) {
        $signals.Add("DX11:BRIDGE")
    }

    $searchRoots = @($dir)
    $parent = [IO.Directory]::GetParent($dir)
    if ($parent) { $searchRoots += $parent.FullName }

    foreach ($r in $searchRoots) {
        foreach ($cfg in @("Engine.ini","GameUserSettings.ini","DefaultEngine.ini")) {
            $matches = Get-ChildItem -LiteralPath $r -Filter $cfg -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 6
            foreach ($m in $matches) {
                try {
                    $txt = Get-Content -LiteralPath $m.FullName -Raw -ErrorAction Stop
                    if ($txt -match '(?i)DefaultGraphicsRHI\s*=\s*DefaultGraphicsRHI_DX12|D3D12TargetedShaderFormats') { $signals.Add("DX12:CFG") }
                    if ($txt -match '(?i)DefaultGraphicsRHI\s*=\s*DefaultGraphicsRHI_DX11|D3D11TargetedShaderFormats') { $signals.Add("DX11:CFG") }
                } catch {}
            }
        }
    }

    $dx12 = @($signals | Where-Object { $_ -like "DX12:*" }).Count
    $dx11 = @($signals | Where-Object { $_ -like "DX11:*" }).Count
    $dx10 = @($signals | Where-Object { $_ -like "DX10:*" }).Count
    $dx9  = @($signals | Where-Object { $_ -like "DX9:*" }).Count

    $scores = [ordered]@{
        "DirectX 12" = $dx12
        "DirectX 11" = $dx11
        "DirectX 10" = $dx10
        "DirectX 9"  = $dx9
    }

    $best = $scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
    if (-not $best -or $best.Value -eq 0) {
        return [pscustomobject]@{
            Api="Unknown"; Confidence="Low";
            Reason="No reliable DirectX evidence found yet. Launch the game once with ReShade, then click Re-detect."
        }
    }

    $second = $scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -Skip 1 -First 1
    $confidence = if ($best.Value -ge 2 -and $best.Value -gt $second.Value) { "High" }
                  elseif ($best.Value -gt $second.Value) { "Medium" }
                  else { "Low" }

    $detail = ($signals | Select-Object -Unique) -join ", "
    return [pscustomobject]@{
        Api=$best.Name; Confidence=$confidence;
        Reason="Static evidence: $detail. Runtime detection from ReShade.log takes priority after launch."
    }
}

function Test-AntiCheat {
    param([string]$Dir)
    foreach ($p in @("EasyAntiCheat","EasyAntiCheat_EOS","BEService","BattlEye","FACEIT","vgk","vgc")) {
        if (Get-ChildItem -LiteralPath $Dir -Filter "*$p*" -Force -ErrorAction SilentlyContinue | Select-Object -First 1) {
            return $true
        }
    }
    return $false
}

function Require-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LatestFeedKit {
    param([string]$OutFile)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ "User-Agent" = "Universal-DLSS5-Installer" }
    $release = Invoke-RestMethod "https://api.github.com/repos/ntqueryinformation/FeedKit/releases/latest" -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -ieq "FeedKit.exe" } | Select-Object -First 1
    if (-not $asset) { throw "FeedKit.exe was not found in the latest release." }
    Invoke-WebRequest $asset.browser_download_url -Headers $headers -OutFile $OutFile -UseBasicParsing
    $release.tag_name
}

function Download-File {
    param([string]$Url,[string]$OutFile)
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}



function Get-LatestDgVoodoo2 {
    param([string]$OutFile)

    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $headers=@{"User-Agent"="Universal-DLSS5-Installer"}
    $release=Invoke-RestMethod "https://api.github.com/repos/dege-diosg/dgVoodoo2/releases/latest" -Headers $headers

    $asset=$release.assets |
        Where-Object {
            $_.name -match '(?i)^dgVoodoo2.*\.zip$' -and
            $_.name -notmatch '(?i)dbg|debug|src|source|symbols'
        } |
        Select-Object -First 1

    if(-not $asset){
        throw "No dgVoodoo2 release ZIP was found in the latest official GitHub release."
    }

    Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $OutFile -UseBasicParsing
    return $release.tag_name
}

function Backup-IfPresent {
    param([string]$Path,[string]$Label="backup")
    if(Test-Path $Path){
        $stamp=Get-Date -Format "yyyyMMdd-HHmmss"
        $bak="$Path.before-$Label.$stamp.bak"
        Copy-Item -LiteralPath $Path -Destination $bak -Force
        Write-Log "[BACKUP] Existing $(Split-Path $Path -Leaf) saved as $(Split-Path $bak -Leaf)"
    }
}

function Install-DgVoodoo2 {
    if(-not $script:GameExe -or -not $script:GameDir){
        [Windows.Forms.MessageBox]::Show("Select a game executable first.","dgVoodoo2") | Out-Null
        return
    }

    if(Test-IsSaintsRow2){
        Write-Log "[SR2 BLOCKED] dgVoodoo2 is disabled for Saints Row 2 in this branch because Profiles A/B/C reproduced the same +0x5EE9F2 crash."
        Write-Log "[SR2] Use Install/Repair DXVK. DXVK is the preferred x86 D3D9 -> Vulkan compatibility path for Saints Row 2."
        [Windows.Forms.MessageBox]::Show(
            "dgVoodoo2 has been disabled for Saints Row 2 in this experimental branch because all three compatibility profiles reproduced the same crash.`r`n`r`nUse SR2 DXVK instead.",
            "SR2 dgVoodoo blocked",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $selectedDX9 = (([string]$apiCombo.SelectedItem) -eq "DirectX 9")
    $detectedDX9 = (([string]$apiCombo.Text) -eq "DirectX 9")

    if(-not ($selectedDX9 -or $detectedDX9)){
        Write-Log "[BLOCKED] dgVoodoo2 install was requested, but the current game is not detected/selected as DirectX 9."
        [Windows.Forms.MessageBox]::Show(
            "dgVoodoo2 installation is only available when the current game is detected as DirectX 9 or DirectX 9 is manually selected.",
            "dgVoodoo2",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    if(Test-AntiCheat $script:GameDir){
        $ans=[Windows.Forms.MessageBox]::Show(
            "Possible anti-cheat files were detected in this game folder.`r`n`r`nThis DLSS5/ReShade/dgVoodoo2 workflow is intended for single-player use. Continue anyway?",
            "Anti-cheat warning",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if($ans -ne [Windows.Forms.DialogResult]::Yes){ return }
    }

    $arch=Get-PeArchitecture $script:GameExe
    $dgArch=if($arch -match '32-bit|x86'){"x86"}else{"x64"}

    $installProfileText="Backend: Direct3D 11 feature level 11.0`r`nVRAM: 1024 MB`r`nVideo card: internal3D"
    if(Test-IsSaintsRow2){
        $installProfileText="SR2 compatibility profile A`r`nBackend: Direct3D 11 feature level 11.0`r`nVRAM: 512 MB`r`nVideo card: GeForce 9800 GT`r`nConservative app-driven rendering settings"
    }

    $confirm=[Windows.Forms.MessageBox]::Show(
        "Install the latest official dgVoodoo2 for this DirectX 9 game?`r`n`r`nTarget:`r`n$($script:GameExe)`r`n`r`nArchitecture: $arch`r`nWrapper: MS\$dgArch\D3D9.dll`r`n$installProfileText`r`n`r`nExisting dgVoodoo files will be backed up first.",
        "Install dgVoodoo2",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Question
    )
    if($confirm -ne [Windows.Forms.DialogResult]::Yes){ return }

    try {
        $tools=Join-Path $script:AppRoot "Tools"
        if(-not (Test-Path $tools)){ New-Item -ItemType Directory -Path $tools | Out-Null }

        $zip=Join-Path $tools "dgVoodoo2-latest.zip"
        $extract=Join-Path $tools "dgVoodoo2-extracted"
        if(Test-Path $extract){ Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue }

        Write-Log "Downloading latest official dgVoodoo2..."
        $tag=Get-LatestDgVoodoo2 $zip
        Write-Log "[OK] dgVoodoo2 $tag downloaded."

        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

        $d3d9=Get-ChildItem -LiteralPath $extract -File -Recurse -ErrorAction Stop |
            Where-Object {
                $_.Name -ieq "D3D9.dll" -and
                $_.FullName -match ("\\MS\\" + [regex]::Escape($dgArch) + "\\")
            } |
            Select-Object -First 1

        $conf=Get-ChildItem -LiteralPath $extract -File -Recurse -Filter "dgVoodoo.conf" -ErrorAction Stop |
            Select-Object -First 1
        $cpl=Get-ChildItem -LiteralPath $extract -File -Recurse -Filter "dgVoodooCpl.exe" -ErrorAction Stop |
            Select-Object -First 1

        if(-not $d3d9){ throw "Could not find MS\$dgArch\D3D9.dll inside the downloaded dgVoodoo2 package." }
        if(-not $conf){ throw "Could not find dgVoodoo.conf inside the downloaded dgVoodoo2 package." }
        if(-not $cpl){ throw "Could not find dgVoodooCpl.exe inside the downloaded dgVoodoo2 package." }

        $dstD3D9=Join-Path $script:GameDir "d3d9.dll"
        $dstConf=Join-Path $script:GameDir "dgVoodoo.conf"
        $dstCpl=Join-Path $script:GameDir "dgVoodooCpl.exe"

        Backup-IfPresent $dstD3D9 "dgvoodoo"
        Backup-IfPresent $dstConf "dgvoodoo"
        Backup-IfPresent $dstCpl "dgvoodoo"

        Copy-Item -LiteralPath $d3d9.FullName -Destination $dstD3D9 -Force
        Copy-Item -LiteralPath $conf.FullName -Destination $dstConf -Force
        Copy-Item -LiteralPath $cpl.FullName -Destination $dstCpl -Force

        # Configure the wrapper for the DLSS5 DX9 path.
        # SR2 is handled separately below so the official base config is not
        # touched by the generic global replacements before the SR2 profile.
        if(-not (Test-IsSaintsRow2)){
            $cfg=[IO.File]::ReadAllText($dstConf)
    
            if($cfg -match '(?m)^\s*OutputAPI\s*=.*$'){
                $cfg=[regex]::Replace($cfg,'(?m)^\s*OutputAPI\s*=.*$','OutputAPI = d3d11_fl11_0',1)
            }
    
            if($cfg -match '(?m)^\s*VRAM\s*=.*$'){
                $cfg=[regex]::Replace($cfg,'(?m)^\s*VRAM\s*=.*$','VRAM = 1024',1)
            }
    
            # Current dgVoodoo2 packages may ship DirectX pass-through enabled.
            # DLSS5's DX9 path requires actual D3D9 -> D3D11 translation.
            if($cfg -match '(?m)^\s*DisableAndPassThru\s*=.*$'){
                $cfg=[regex]::Replace($cfg,'(?m)^\s*DisableAndPassThru\s*=.*$','DisableAndPassThru = false',1)
            } else {
                $cfg=[regex]::Replace($cfg,'(?m)^\[DirectX\]\s*$',"[DirectX]`r`nDisableAndPassThru = false",1)
            }
    
            if($cfg -match '(?m)^\s*VideoCard\s*=.*$'){
                $cfg=[regex]::Replace($cfg,'(?m)^\s*VideoCard\s*=.*$','VideoCard = internal3D',1)
            } else {
                $cfg=[regex]::Replace($cfg,'(?m)^\[DirectX\]\s*$',"[DirectX]`r`nVideoCard = internal3D",1)
            }
    
            if($cfg -match '(?m)^\s*dgVoodooWatermark\s*=.*$'){
                $cfg=[regex]::Replace($cfg,'(?m)^\s*dgVoodooWatermark\s*=.*$','dgVoodooWatermark = true',1)
            }
    
            [IO.File]::WriteAllText($dstConf,$cfg,[Text.UTF8Encoding]::new($false))
        }

        Write-Log "[OK] Installed dgVoodoo2 D3D9 wrapper: $dstD3D9"
        Write-Log "[OK] Installed dgVoodoo.conf and dgVoodooCpl.exe."

        if(Test-IsSaintsRow2){
            if(Apply-SR2SafeDgVoodooProfile -Profile "A" -SkipBackup){
                Write-Log "[SR2 SAFE] Saints Row 2 detected. Generic internal3D/1024 profile was replaced with compatibility Profile A."
                Write-Log "[INFO] Use 'SR2 compatibility' -> Test Profile A to launch under automatic crash monitoring."
            } else {
                Write-Log "[WARN] SR2 compatibility Profile A could not be applied automatically."
            }
        } else {
            Write-Log "[OK] Configured dgVoodoo2 for D3D11 FL11_0, 1024 MB VRAM, internal3D, pass-through disabled."
            Write-Log "[INFO] Launch the game and look for the dgVoodoo watermark. Then close the game and click Verify files."
        }

        Update-RepairAvailability
        Verify-Install
    } catch {
        Write-Log "[ERROR] dgVoodoo2 installation failed: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show(
            "dgVoodoo2 installation failed.`r`n`r`n$($_.Exception.Message)",
            "dgVoodoo2",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}


function Update-ActionLayout {
    try {
        if(-not $actionCard){ return }

        $x=20
        $y=46
        $gap=10
        $h=42

        $layout=@(
            @{Button=$installButton;      Width=110},
            @{Button=$verifyButton;       Width=100},
            @{Button=$repairButton;       Width=120},
            @{Button=$dgVoodooButton;     Width=120},
            @{Button=$feedFixButton;      Width=118},
            @{Button=$sr2IsolationButton; Width=132},
            @{Button=$openButton;         Width=112}
        )

        foreach($item in $layout){
            $b=$item.Button
            if(-not $b){ continue }

            if(-not $b.Visible){
                continue
            }

            $b.Location=New-Object Drawing.Point($x,$y)
            $b.Size=New-Object Drawing.Size($item.Width,$h)
            $x += $item.Width + $gap
        }
    } catch {}
}

function Update-DgVoodooButton {
    if(-not $dgVoodooButton){ return }
    try {
        $selectedDX9 = (([string]$apiCombo.SelectedItem) -eq "DirectX 9")
        $detectedDX9 = $false

        # Treat the current detection result as DX9 when the UI has positively
        # identified DirectX 9 for the selected executable.
        if($script:GameExe -and (Test-Path $script:GameExe)){
            if(([string]$apiCombo.Text) -eq "DirectX 9"){
                $detectedDX9 = $true
            }
        }

        $allowDX9 = ($selectedDX9 -or $detectedDX9)

        $dgVoodooButton.Visible = $allowDX9
        $dgVoodooButton.Enabled = ($allowDX9 -and $script:GameExe -and (Test-Path $script:GameExe))
        if($feedFixButton){
            $feedFixButton.Visible = $allowDX9
            $feedFixButton.Enabled = ($allowDX9 -and $script:GameExe -and (Test-Path $script:GameExe))
        }

        if($allowDX9 -and (Test-DX9TranslationReady)){
            $dgVoodooButton.Text="Reinstall dgVoodoo2"
        } else {
            $dgVoodooButton.Text="Install dgVoodoo2"
        }

        Update-ActionLayout
    } catch {
        $dgVoodooButton.Visible=$false
        $dgVoodooButton.Enabled=$false
        if($feedFixButton){
            $feedFixButton.Visible=$false
            $feedFixButton.Enabled=$false
        }
    }
}

function Find-LikelyRenderingExe {
    param([string]$SelectedExe)

    $root = Split-Path -Parent $SelectedExe
    $candidates = @()

    try {
        $candidates = Get-ChildItem -LiteralPath $root -Filter *.exe -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -match '\\Binaries\\Win(32|64)\\' -and
                $_.Name -notmatch '(?i)CrashReport|Launcher|Bootstrap|Helper|Prereq|UnrealCEF|EpicWebHelper|Uninstall'
            } |
            Select-Object -First 40
    } catch {}

    if (-not $candidates -or $candidates.Count -eq 0) { return $null }

    $ranked = foreach ($c in $candidates) {
        $score = 0
        if ($c.FullName -match '\\Binaries\\Win64\\') { $score += 50 }
        if ($c.FullName -match '\\Binaries\\Win32\\') { $score += 45 }
        if ($c.Name -match '(?i)Shipping\.exe$') { $score += 30 }
        if ($c.Name -notmatch '(?i)Crash|Launcher|Bootstrap|Helper|Prereq') { $score += 10 }
        [pscustomobject]@{ Path=$c.FullName; Score=$score }
    }

    ($ranked | Sort-Object -Property @{Expression="Score";Descending=$true}, @{Expression="Path";Descending=$false} | Select-Object -First 1).Path
}

function Select-Game {
    $dlg=New-Object Windows.Forms.OpenFileDialog
    $dlg.Title="Select the game's executable (launcher is OK; the app can search for the real renderer)"
    $dlg.Filter="Executable (*.exe)|*.exe"
    if($dlg.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        $chosen=$dlg.FileName
        $likely=Find-LikelyRenderingExe $chosen

        if($likely -and ($likely -ne $chosen)) {
            $msg="A more likely rendering executable was found:`r`n`r`n$likely`r`n`r`nUse this instead of:`r`n$chosen ?"
            $answer=[Windows.Forms.MessageBox]::Show($msg,"Rendering EXE detected","YesNo","Question")
            if($answer -eq [Windows.Forms.DialogResult]::Yes) {
                $script:GameExe=$likely
                Write-Log "Auto-resolved to rendering EXE: $likely"
            } else {
                $script:GameExe=$chosen
            }
        } else {
            $script:GameExe=$chosen
        }

        Update-GameDisplay
    }
}

function Update-GameDisplay {
    if(-not $script:GameExe){return}
    $script:GameDir=Split-Path -Parent $script:GameExe
    $script:Architecture=Get-PeArchitecture $script:GameExe
    $script:Profile=Get-GameProfile $script:GameExe
    $guess=Get-RendererGuess $script:GameExe

    $gamePathBox.Text=$script:GameExe
    $archValue.Text=$script:Architecture
    $profileValue.Text=$script:Profile
    $detectValue.Text="$($guess.Api) ($($guess.Confidence))"
    $reasonValue.Text=$guess.Reason

    if($guess.Api -ne "Unknown"){$apiCombo.SelectedItem=$guess.Api}
    Write-Log "Selected: $($script:GameExe)"
    Write-Log "Architecture: $($script:Architecture) | Profile: $($script:Profile) | Renderer: $($guess.Api) ($($guess.Confidence))"
    Copy-GameLogsToInstaller -Quiet

    if($gameNameValue){
        try {
            $displayName=[IO.Path]::GetFileNameWithoutExtension($script:GameExe)
            # Prefer FileDescription/ProductName when it is useful and not generic.
            $vi=[Diagnostics.FileVersionInfo]::GetVersionInfo($script:GameExe)
            if($vi.ProductName -and $vi.ProductName.Trim().Length -gt 2){
                $displayName=$vi.ProductName.Trim()
            } elseif($vi.FileDescription -and $vi.FileDescription.Trim().Length -gt 2){
                $displayName=$vi.FileDescription.Trim()
            }
            $gameNameValue.Text=$displayName
        } catch {
            $gameNameValue.Text=[IO.Path]::GetFileNameWithoutExtension($script:GameExe)
        }
    }

    Update-GameArtwork
    Update-RepairAvailability
    Update-DgVoodooButton
    Update-SR2IsolationButton
}


function Test-DX9TranslationReady {
    if(-not $script:GameDir){ return $false }
    return (Test-Path (Join-Path $script:GameDir "d3d9.dll"))
}


function Get-ReShadeRuntimeState {
    if(-not $script:GameDir){ return "Missing" }
    $log=Join-Path $script:GameDir "ReShade.log"
    if(-not (Test-Path $log)){ return "Missing" }

    try {
        $s=[IO.File]::ReadAllText($log)

        if($s -match '(?i)If you are reading this after launching the game at least once,\s*it likely means ReShade was not loaded by the game'){
            return "NotLoaded"
        }

        # Real ReShade runtime evidence. The first pattern matches current
        # ReShade logs such as:
        # "Initializing crosire's ReShade version '6.8.0.2156' (32-bit)"
        if($s -match "(?i)Initializing\s+crosire'?s\s+ReShade\s+version" -or
           $s -match '(?i)Registered add-on "DLSS 5 Feed' -or
           $s -match '(?i)Redirecting CreateDXGIFactory' -or
           $s -match '(?i)Redirecting D3D11CreateDevice' -or
           $s -match '(?i)IDXGIFactory::CreateSwapChain'){
            return "Loaded"
        }

        return "Unknown"
    } catch {
        return "Unreadable"
    }
}

function Get-DX9RuntimeEvidence {
    $result=[ordered]@{
        ReShadeLoaded=$false
        ReShadeVersion=""
        ReShadeArch=""
        D3D11Translated=$false
        FeedAddonRegistered=$false
        FeedAddonVersion=""
        FeedShaderCompiled=$false
        RealSwapChain=$false
        Resolution=""
    }

    if(-not $script:GameDir){ return [pscustomobject]$result }
    $log=Join-Path $script:GameDir "ReShade.log"
    if(-not (Test-Path $log)){ return [pscustomobject]$result }

    try {
        $s=[IO.File]::ReadAllText($log)

        $init=[regex]::Match($s,"(?im)Initializing\s+crosire'?s\s+ReShade\s+version\s+'([^']+)'\s+\((32-bit|64-bit)\)")
        if($init.Success){
            $result.ReShadeLoaded=$true
            $result.ReShadeVersion=$init.Groups[1].Value
            $result.ReShadeArch=$init.Groups[2].Value
        } elseif((Get-ReShadeRuntimeState) -eq "Loaded"){
            $result.ReShadeLoaded=$true
        }

        if($s -match '(?i)Redirecting D3D11CreateDevice(?:AndSwapChain)?' -or
           $s -match '(?i)CreateDXGIFactory1'){
            $result.D3D11Translated=$true
        }

        $feed=[regex]::Match($s,'(?im)Registered add-on "DLSS 5 Feed \((?:32-bit|64-bit)\) ([^"]+)"')
        if($feed.Success){
            $result.FeedAddonRegistered=$true
            $result.FeedAddonVersion=$feed.Groups[1].Value
        } elseif($s -match '(?i)Registered add-on "DLSS 5 Feed'){
            $result.FeedAddonRegistered=$true
        }

        if($s -match "(?im)Successfully compiled '.*\\DLSS5_Feed\.fx'"){
            $result.FeedShaderCompiled=$true
        }

        # Prefer a real, non-trivial swap-chain resolution over the temporary 1x1 device.
        $widths=[regex]::Matches($s,'(?im)^\s*\|\s*Width\s*\|\s*(\d+)\s*\|')
        $heights=[regex]::Matches($s,'(?im)^\s*\|\s*Height\s*\|\s*(\d+)\s*\|')
        $count=[Math]::Min($widths.Count,$heights.Count)
        for($i=0;$i -lt $count;$i++){
            $w=[int]$widths[$i].Groups[1].Value
            $h=[int]$heights[$i].Groups[1].Value
            if($w -gt 16 -and $h -gt 16){
                $result.RealSwapChain=$true
                $result.Resolution="${w}x${h}"
            }
        }

        return [pscustomobject]$result
    } catch {
        return [pscustomobject]$result
    }
}


function Get-DLSS5FeedState {
    $r=[ordered]@{
        LogPresent=$false
        Attached=$false
        FeedVersion=""
        TechniqueMissing=$false
        MVMissing=$false
        DepthMissing=$false
        ProviderMissing=$false
        ProviderExpected=""
        ProviderEnabled=$false
        FeatureReady=$false
        FramesDelivered=$false
        DeliveredFrame=""
        HostLogPresent=$false
        HostFeatureCreated=$false
        HostInlineSucceeded=$false
    }

    if(-not $script:GameDir){ return [pscustomobject]$r }

    $feedLog=Join-Path $script:GameDir "dlss5-feed.log"
    if(Test-Path $feedLog){
        $r.LogPresent=$true
        try {
            $s=[IO.File]::ReadAllText($feedLog)

            $m=[regex]::Match($s,'(?im)dlss5-feed(?:32|64)?\s+([0-9][^\s]*)\s+.*attached')
            if($m.Success){
                $r.Attached=$true
                $r.FeedVersion=$m.Groups[1].Value
            } elseif($s -match '(?i)attached\.'){
                $r.Attached=$true
            }

            $r.TechniqueMissing = ($s -match '(?i)effects:\s*technique\s+MISSING')
            $r.MVMissing        = ($s -match '(?i)DLSS5_MV\s+MISSING')
            $r.DepthMissing     = ($s -match '(?i)DLSS5_Depth\s+MISSING')
            $r.ProviderMissing  = ($s -match '(?i)->\s*none\s*\(not installed\)|provider.*not installed')

            $pm=[regex]::Match($s,'(?im)DLSS5_MV_PROVIDER=\d+\s+\(([^)]+)\)')
            if($pm.Success){ $r.ProviderExpected=$pm.Groups[1].Value }

            if($s -match '(?im)DLSS5_MV_PROVIDER=\d+.*->\s*[^\r\n]*\(enabled\)'){
                $r.ProviderEnabled=$true
            }

            if($s -match '(?im)feature ready[^\r\n]*DLAA'){
                $r.FeatureReady=$true
            }

            $fm=[regex]::Matches($s,'(?im)frame\s+(\d+)\s+delivered')
            if($fm.Count -gt 0){
                $r.FramesDelivered=$true
                $r.DeliveredFrame=$fm[$fm.Count-1].Groups[1].Value
            }
        } catch {}
    }

    $hostLog=Join-Path $script:GameDir "host64\dlss5-feed-host.log"
    if(Test-Path $hostLog){ $r.HostLogPresent=$true }

    $hostRs=Join-Path $script:GameDir "host64\ReShade.log"
    if(Test-Path $hostRs){
        try {
            $hs=[IO.File]::ReadAllText($hostRs)
            if($hs -match '(?i)feature\s+18\s+created'){ $r.HostFeatureCreated=$true }
            if($hs -match '(?i)inline feature\s+18\s+evaluation succeeded'){ $r.HostInlineSucceeded=$true }
        } catch {}
    }

    return [pscustomobject]$r
}

function Get-ReShadePresetPath {
    if(-not $script:GameDir){ return $null }
    $ini=Join-Path $script:GameDir "ReShade.ini"
    $preset=$null

    if(Test-Path $ini){
        try {
            $s=[IO.File]::ReadAllText($ini)
            $m=[regex]::Match($s,'(?im)^\s*PresetPath\s*=\s*(.+?)\s*$')
            if($m.Success){
                $raw=$m.Groups[1].Value.Trim().Trim('"')
                if([IO.Path]::IsPathRooted($raw)){
                    $preset=$raw
                } else {
                    $preset=Join-Path $script:GameDir $raw
                }
            }
        } catch {}
    }

    if(-not $preset){
        $preset=Join-Path $script:GameDir "ReShadePreset.ini"
    }
    return $preset
}

function Set-IniListFront {
    param(
        [string]$Text,
        [string]$Key,
        [string[]]$FrontItems
    )

    $pattern='(?im)^\s*'+[regex]::Escape($Key)+'\s*=\s*(.*)$'
    $m=[regex]::Match($Text,$pattern)
    $existing=@()
    if($m.Success -and $m.Groups[1].Value.Trim()){
        $existing=@($m.Groups[1].Value.Split(',') | ForEach-Object {$_.Trim()} | Where-Object {$_})
    }

    $removeNames=@(
        'Lumenite_Kernel@lumenite_Kernel.fx',
        'DLSS5_Feed@DLSS5_Feed.fx'
    )
    $clean=@($existing | Where-Object { $removeNames -notcontains $_ })
    $value=(($FrontItems + $clean) -join ',')

    if($m.Success){
        return [regex]::Replace($Text,$pattern,($Key+'='+$value),1)
    }
    return ($Key+'='+$value+"`r`n"+$Text)
}

function Set-DLSS5ProviderPreprocessor {
    param([string]$Text)

    $pattern='(?im)^\s*PreprocessorDefinitions\s*=\s*(.*)$'
    $m=[regex]::Match($Text,$pattern)
    $defs=@()
    if($m.Success -and $m.Groups[1].Value.Trim()){
        $defs=@($m.Groups[1].Value.Split(',') | ForEach-Object {$_.Trim()} | Where-Object {$_})
    }

    $defs=@($defs | Where-Object {$_ -notmatch '^(?i)DLSS5_MV_PROVIDER='})
    $value=(('DLSS5_MV_PROVIDER=3' + $defs) -join ',')

    if($m.Success){
        return [regex]::Replace($Text,$pattern,('PreprocessorDefinitions='+$value),1)
    }
    return ('PreprocessorDefinitions='+$value+"`r`n"+$Text)
}

function Install-OrRepairLumeniteFX {
    if(-not $script:GameDir){ throw "No game directory is selected." }

    $shaderRoot=Join-Path $script:GameDir "reshade-shaders"
    $shaders=Join-Path $shaderRoot "Shaders"
    $textures=Join-Path $shaderRoot "Textures"
    New-Item -ItemType Directory -Force -Path $shaders,$textures | Out-Null

    $kernel=Join-Path $shaders "lumenite_Kernel.fx"
    $include=Join-Path $shaders "include"

    $needDownload = (-not (Test-Path $kernel)) -or (-not (Test-Path $include))
    if($needDownload){
        Write-Log "[REPAIR] LumeniteFX Kernel files are incomplete. Downloading current upstream LumeniteFX..."
        $tools=Join-Path $script:AppRoot "Tools"
        New-Item -ItemType Directory -Force -Path $tools | Out-Null
        $zip=Join-Path $tools "LumeniteFX-mainline.zip"
        $extract=Join-Path $tools "LumeniteFX-mainline"
        if(Test-Path $extract){ Remove-Item -Recurse -Force $extract -ErrorAction SilentlyContinue }

        Invoke-WebRequest -UseBasicParsing -Headers @{"User-Agent"="Universal-DLSS5-Installer"} `
            -Uri "https://github.com/umar-afzaal/LumeniteFX/archive/refs/heads/mainline.zip" `
            -OutFile $zip
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

        $root=Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
        if(-not $root){ throw "LumeniteFX archive layout was not recognized." }

        $srcShaders=Join-Path $root.FullName "Shaders"
        $srcTextures=Join-Path $root.FullName "Textures"
        if(-not (Test-Path $srcShaders)){ throw "LumeniteFX Shaders folder was not found." }

        Copy-Item -Path (Join-Path $srcShaders "*") -Destination $shaders -Recurse -Force
        if(Test-Path $srcTextures){
            Copy-Item -Path (Join-Path $srcTextures "*") -Destination $textures -Recurse -Force
        }
        Write-Log "[OK] Installed/repaired LumeniteFX motion-vector provider files."
    } else {
        Write-Log "[OK] LumeniteFX Kernel files are already installed."
    }
}

function Repair-DLSS5Inputs {
    if(Test-IsSaintsRow2){
        Write-Log "[INFO] Fix DLSS inputs is unavailable while SR2 is using the DXVK/Vulkan path."
        [Windows.Forms.MessageBox]::Show("SR2 is using DXVK/Vulkan. The current 32-bit DLSS5 input repair path is not enabled for this renderer, so no unsupported changes will be applied.","SR2 DXVK")|Out-Null
        return
    }
    if(-not $script:GameExe -or -not $script:GameDir){
        [Windows.Forms.MessageBox]::Show("Select a game first.","Fix DLSS inputs","OK","Information")|Out-Null
        return
    }

    try {
        Write-Log "----- DLSS5 Input Repair -----"
        Install-OrRepairLumeniteFX

        $preset=Get-ReShadePresetPath
        if(-not (Test-Path $preset)){
            [IO.File]::WriteAllText($preset,"",[Text.UTF8Encoding]::new($false))
        }

        $p=[IO.File]::ReadAllText($preset)
        $backup=$preset+".before-dlss5-input-fix."+([DateTime]::Now.ToString("yyyyMMdd-HHmmss"))+".bak"
        Copy-Item -LiteralPath $preset -Destination $backup -Force

        # Safer staged setup for fragile DX9 games:
        # install the provider and set provider=3, but DO NOT auto-enable techniques.
        # Some older DX9 titles can crash before menu if heavy providers are forced
        # active during device/swap-chain bootstrap.
        $p=Set-DLSS5ProviderPreprocessor -Text $p
        [IO.File]::WriteAllText($preset,$p,[Text.UTF8Encoding]::new($false))

        Write-Log "[OK] Set DLSS5_MV_PROVIDER=3 (LumeniteFX Kernel)."
        Write-Log "[SAFE MODE] Did NOT force-enable Lumenite_Kernel or DLSS5_Feed in the preset."
        Write-Log "[INFO] Preset backup: $backup"
        Write-Log "[ACTION] Launch the game first with both DLSS techniques disabled."
        Write-Log "[ACTION] After the game reaches the menu/gameplay, open ReShade with Home."
        Write-Log "[ACTION] Enable 'LUMENITE: Kernel 2.0' FIRST. Confirm the game remains stable."
        Write-Log "[ACTION] Then enable 'DLSS 5 Feed' beneath it. If the game crashes, leave the last technique disabled."
        Write-Log "[ACTION] Disable game MSAA/SSAA while testing."
        Write-Log "[ACTION] After testing, close the game and click Verify files."
        Write-Log "------------------------------"

        [Windows.Forms.MessageBox]::Show(
            "DLSS5 input files were repaired in SAFE STAGE mode.`r`n`r`nThe installer set DLSS5_MV_PROVIDER=3 but did not auto-enable Lumenite Kernel or DLSS 5 Feed.`r`n`r`nLaunch the game first. Once you reach the menu/gameplay, enable LUMENITE: Kernel 2.0, test stability, then enable DLSS 5 Feed beneath it.",
            "DLSS5 inputs repaired - Safe Stage",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        Write-Log "[ERROR] DLSS5 input repair failed: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show(
            "DLSS5 input repair failed.`r`n`r`n$($_.Exception.Message)",
            "Fix DLSS inputs",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}


function Test-IsSaintsRow2 {
    try {
        if(-not $script:GameExe){ return $false }
        return ([IO.Path]::GetFileName($script:GameExe) -ieq "SR2_pc.exe")
    } catch { return $false }
}


function Set-DgVoodooSectionValue {
    param(
        [string]$Text,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )

    $sectionPattern="(?ms)(^\[" + [regex]::Escape($Section) + "\]\s*\r?\n)(.*?)(?=^\[|\z)"
    $match=[regex]::Match($Text,$sectionPattern)
    if(-not $match.Success){ return $Text }

    $body=$match.Groups[2].Value
    $keyPattern='(?m)^\s*' + [regex]::Escape($Key) + '\s*=.*$'

    if([regex]::IsMatch($body,$keyPattern)){
        $body=[regex]::Replace($body,$keyPattern,("$Key = $Value"),1)
    } else {
        $body=("$Key = $Value`r`n") + $body
    }

    return $Text.Substring(0,$match.Groups[2].Index) + $body + $Text.Substring($match.Groups[2].Index+$match.Groups[2].Length)
}

function Apply-SR2SafeDgVoodooProfile {
    param(
        [ValidateSet("A","B","C")][string]$Profile="A",
        [switch]$SkipBackup
    )

    if(-not (Test-IsSaintsRow2) -or -not $script:GameDir){ return $false }

    $confPath=Join-Path $script:GameDir "dgVoodoo.conf"
    $d3d9Path=Join-Path $script:GameDir "d3d9.dll"
    $d3d9Off=$d3d9Path+".OFF"

    if(-not (Test-Path $confPath)){
        Write-Log "[SR2 SAFE] dgVoodoo.conf is missing. Install dgVoodoo2 first."
        return $false
    }

    # If Stage 3 or an automatic rollback disabled the wrapper, restore it for
    # this controlled compatibility test.
    if((Test-Path $d3d9Off) -and -not (Test-Path $d3d9Path)){
        Rename-Item -LiteralPath $d3d9Off -NewName "d3d9.dll" -Force
        Write-Log "[SR2 SAFE] Re-enabled dgVoodoo d3d9.dll for compatibility testing."
    } elseif((Test-Path $d3d9Off) -and (Test-Path $d3d9Path)){
        Remove-Item -LiteralPath $d3d9Off -Force -ErrorAction SilentlyContinue
    }

    if(-not (Test-Path $d3d9Path)){
        Write-Log "[SR2 SAFE] d3d9.dll is missing. Install dgVoodoo2 first."
        return $false
    }

    if(-not $SkipBackup){
        $stamp=Get-Date -Format "yyyyMMdd-HHmmss"
        $bak="$confPath.before-sr2-safe-$Profile.$stamp.bak"
        Copy-Item -LiteralPath $confPath -Destination $bak -Force
        Write-Log "[BACKUP] dgVoodoo.conf saved as $(Split-Path $bak -Leaf)"
    }

    $videoCard="geforce_9800_gt"
    $vram="512"
    $profileName="A - GeForce 9800 GT / 512 MB"

    if($Profile -eq "B"){
        $videoCard="internal3D"
        $vram="512"
        $profileName="B - Internal3D / 512 MB"
    } elseif($Profile -eq "C"){
        $videoCard="geforce_9800_gt"
        $vram="1024"
        $profileName="C - GeForce 9800 GT / 1024 MB"
    }

    $cfg=[IO.File]::ReadAllText($confPath)

    # Required for DLSS5's translated DX9 path.
    $cfg=Set-DgVoodooSectionValue $cfg "General" "OutputAPI" "d3d11_fl11_0"
    $cfg=Set-DgVoodooSectionValue $cfg "General" "Adapters" "all"
    $cfg=Set-DgVoodooSectionValue $cfg "General" "FullScreenOutput" "default"
    $cfg=Set-DgVoodooSectionValue $cfg "General" "FullScreenMode" "false"
    $cfg=Set-DgVoodooSectionValue $cfg "General" "ScalingMode" "unspecified"
    $cfg=Set-DgVoodooSectionValue $cfg "General" "EnumerateRefreshRates" "false"

    # SR2 compatibility profile: avoid forced rendering features and emulate
    # a period-appropriate card rather than the generic Internal3D profile
    # that reproduced SR2_pc.exe +0x5EE9F2 on this setup.
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "DisableAndPassThru" "false"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "VideoCard" $videoCard
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "VRAM" $vram
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "Filtering" "appdriven"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "DisableMipmapping" "false"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "Resolution" "unforced"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "Antialiasing" "appdriven"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "AppControlledScreenMode" "true"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "DisableAltEnterToToggleScreenMode" "true"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "Bilinear2DOperations" "false"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "PhongShadingWhenPossible" "false"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "ForceVerticalSync" "false"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "dgVoodooWatermark" "true"
    $cfg=Set-DgVoodooSectionValue $cfg "DirectX" "FastVideoMemoryAccess" "false"

    [IO.File]::WriteAllText($confPath,$cfg,[Text.UTF8Encoding]::new($false))

    Write-Log "----- SR2 dgVoodoo Compatibility -----"
    Write-Log "[SR2 SAFE] Applied profile $profileName."
    Write-Log "[SR2 SAFE] D3D11 FL11_0 / app-driven filtering-AA / unforced resolution."
    Write-Log "[SR2 SAFE] FullScreenMode=false / FastVideoMemoryAccess=false / VSync not forced."
    Write-Log "[SR2 SAFE] dgVoodoo watermark enabled for the compatibility test."
    Write-Log "--------------------------------------"
    return $true
}

function Get-SR2KnownCrashSince {
    param([datetime]$Since)

    if(-not $script:GameDir){ return $null }

    try {
        $logs=Get-ChildItem -LiteralPath $script:GameDir -File -Filter "SR2_pc.exe.*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $Since.AddSeconds(-2) } |
            Sort-Object LastWriteTime -Descending

        foreach($log in $logs){
            try {
                $content=[IO.File]::ReadAllText($log.FullName)
                if($content -match '(?i)0x009EE9F2|\+0x5ee9f2'){
                    return $log.FullName
                }
            } catch {}
        }
    } catch {}

    return $null
}

function Rollback-SR2ToNativeD3D9 {
    param([string]$Reason="")

    if(-not (Test-IsSaintsRow2) -or -not $script:GameDir){ return }

    $live=Join-Path $script:GameDir "d3d9.dll"
    $off=$live+".OFF"

    try {
        if(Test-Path $live){
            if(Test-Path $off){ Remove-Item -LiteralPath $off -Force -ErrorAction SilentlyContinue }
            Rename-Item -LiteralPath $live -NewName "d3d9.dll.OFF" -Force
        }

        Write-Log "----- SR2 Automatic Rollback -----"
        Write-Log "[AUTO-ROLLBACK] dgVoodoo d3d9.dll disabled."
        Write-Log "[AUTO-ROLLBACK] Saints Row 2 will use native DirectX 9 on the next launch."
        if($Reason){ Write-Log "[AUTO-ROLLBACK] Reason: $Reason" }
        Write-Log "[INFO] Use SR2 compatibility to re-enable a wrapper profile for another test."
        Write-Log "----------------------------------"
    } catch {
        Write-Log "[ERROR] SR2 automatic rollback failed: $($_.Exception.Message)"
    }
}

function Start-SR2SafeDgVoodooTest {
    param([ValidateSet("A","B","C")][string]$Profile="A")

    if(-not (Test-IsSaintsRow2) -or -not $script:GameExe -or -not $script:GameDir){ return }

    try {
        $already=Get-Process -Name "SR2_pc" -ErrorAction SilentlyContinue | Select-Object -First 1
        if($already){
            [Windows.Forms.MessageBox]::Show(
                "Saints Row 2 is already running. Close it before starting a compatibility test.",
                "SR2 Safe Voodoo Test",
                [Windows.Forms.MessageBoxButtons]::OK,
                [Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        Restore-SR2Isolation

        if(-not (Apply-SR2SafeDgVoodooProfile -Profile $Profile)){
            [Windows.Forms.MessageBox]::Show(
                "The SR2 dgVoodoo profile could not be applied. Check the Status/Debug log.",
                "SR2 Safe Voodoo Test",
                [Windows.Forms.MessageBoxButtons]::OK,
                [Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        $script:SR2SafeTestStart=Get-Date
        $script:SR2SafeTestExitSeen=$null
        $script:SR2SafeTestProfile=$Profile

        Write-Log "===== SR2 SAFE VOODOO TEST ====="
        Write-Log "[TEST] Starting SR2 with compatibility profile $Profile."
        Write-Log "[WATCH] The installer will watch for the known +0x5EE9F2 crash signature."
        Write-Log "[WATCH] If detected, dgVoodoo will be disabled automatically for the next launch."

        $proc=Start-Process -FilePath $script:GameExe -WorkingDirectory $script:GameDir -PassThru
        $script:SR2SafeTestProcessId=$proc.Id
        $script:SR2SafeTestActive=$true

        if($script:SR2SafeTimer){ $script:SR2SafeTimer.Start() }

        Write-Log "[LAUNCHED] SR2_pc.exe PID $($proc.Id)."
    } catch {
        $script:SR2SafeTestActive=$false
        Write-Log "[ERROR] Could not start SR2 safe dgVoodoo test: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show(
            "Could not launch Saints Row 2.`r`n`r`n$($_.Exception.Message)",
            "SR2 Safe Voodoo Test",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Move-SR2IsolationItem {
    param([string]$LivePath,[bool]$Disable)
    $offPath=$LivePath+".OFF"
    if($Disable){
        if(Test-Path $LivePath){
            if(Test-Path $offPath){
                Remove-Item -LiteralPath $offPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            Rename-Item -LiteralPath $LivePath -NewName ([IO.Path]::GetFileName($offPath)) -Force
        }
    } else {
        if(Test-Path $offPath){
            if(Test-Path $LivePath){
                # A newer live file wins. Remove the stale isolation copy instead
                # of replacing a freshly reinstalled wrapper/proxy.
                Remove-Item -LiteralPath $offPath -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Rename-Item -LiteralPath $offPath -NewName ([IO.Path]::GetFileName($LivePath)) -Force
            }
        }
    }
}

function Restore-SR2Isolation {
    if(-not (Test-IsSaintsRow2) -or -not $script:GameDir){ return }
    Move-SR2IsolationItem -LivePath (Join-Path $script:GameDir "reshade-shaders") -Disable:$false
    Move-SR2IsolationItem -LivePath (Join-Path $script:GameDir "dxgi.dll") -Disable:$false
    Move-SR2IsolationItem -LivePath (Join-Path $script:GameDir "d3d9.dll") -Disable:$false
    Write-Log "[SR2 TEST] Restored reshade-shaders, dxgi.dll, and d3d9.dll."
}

function Set-SR2IsolationStage {
    param([ValidateSet("ShadersOff","ReShadeOff","DgVoodooOff","RestoreAll")][string]$Stage)

    if(-not (Test-IsSaintsRow2)){
        [Windows.Forms.MessageBox]::Show("This helper is only for SR2_pc.exe.","SR2 Crash Isolation")|Out-Null
        return
    }
    if(-not $script:GameDir){ return }

    try {
        Restore-SR2Isolation

        switch($Stage){
            "ShadersOff" {
                Move-SR2IsolationItem -LivePath (Join-Path $script:GameDir "reshade-shaders") -Disable:$true
                Write-Log "----- SR2 Crash Isolation: Stage 1 -----"
                Write-Log "[TEST] Disabled reshade-shaders only."
                Write-Log "[ACTIVE] ReShade dxgi.dll remains enabled."
                Write-Log "[ACTIVE] dgVoodoo2 d3d9.dll remains enabled."
                Write-Log "[ACTION] Launch Saints Row 2 now."
                Write-Log "[RESULT] If it launches, shader/Lumenite is the likely crash boundary."
                Write-Log "----------------------------------------"
            }
            "ReShadeOff" {
                Move-SR2IsolationItem -LivePath (Join-Path $script:GameDir "dxgi.dll") -Disable:$true
                Write-Log "----- SR2 Crash Isolation: Stage 2 -----"
                Write-Log "[TEST] Disabled ReShade dxgi.dll only."
                Write-Log "[ACTIVE] dgVoodoo2 d3d9.dll remains enabled."
                Write-Log "[RESTORED] reshade-shaders."
                Write-Log "[ACTION] Launch Saints Row 2 now."
                Write-Log "[RESULT] If it launches but Stage 1 crashes, ReShade/Feed injection is the likely boundary."
                Write-Log "----------------------------------------"
            }
            "DgVoodooOff" {
                Move-SR2IsolationItem -LivePath (Join-Path $script:GameDir "d3d9.dll") -Disable:$true
                Write-Log "----- SR2 Crash Isolation: Stage 3 -----"
                Write-Log "[TEST] Disabled dgVoodoo2 d3d9.dll only."
                Write-Log "[RESTORED] ReShade dxgi.dll and reshade-shaders."
                Write-Log "[ACTION] Launch Saints Row 2 now."
                Write-Log "[RESULT] If it launches while Stage 2 crashes, dgVoodoo DX9->D3D11 is the likely crash trigger."
                Write-Log "----------------------------------------"
            }
            "RestoreAll" {
                Write-Log "----- SR2 Crash Isolation -----"
                Write-Log "[RESTORED] All SR2 rendering components are enabled."
                Write-Log "--------------------------------"
            }
        }
        Update-SR2IsolationButton
    } catch {
        Write-Log "[ERROR] SR2 crash isolation failed: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show("SR2 crash isolation failed.`r`n`r`n$($_.Exception.Message)","SR2 Crash Isolation")|Out-Null
    }
}

function Show-SR2IsolationDialog {
    if(-not (Test-IsSaintsRow2)){ return }

    $dlg=New-Object Windows.Forms.Form
    $dlg.Text="Saints Row 2 - dgVoodoo Compatibility"
    $dlg.StartPosition="CenterParent"
    $dlg.FormBorderStyle="FixedDialog"
    $dlg.MaximizeBox=$false
    $dlg.MinimizeBox=$false
    $dlg.Size=New-Object Drawing.Size(580,650)
    $dlg.BackColor=[Drawing.Color]::FromArgb(15,18,24)
    $dlg.ForeColor=[Drawing.Color]::FromArgb(240,244,248)

    $title=New-Object Windows.Forms.Label
    $title.Text="SR2 dgVoodoo compatibility"
    $title.Font=New-Object Drawing.Font("Segoe UI Semibold",15)
    $title.AutoSize=$true
    $title.Location=New-Object Drawing.Point(24,18)
    $dlg.Controls.Add($title)

    $info=New-Object Windows.Forms.Label
    $info.Text="The generic dgVoodoo profile reproduced SR2_pc.exe +0x5EE9F2. These profiles keep the required D3D9 -> D3D11 path but use conservative SR2 settings. The test launcher automatically rolls back to native D3D9 if that known crash is detected."
    $info.Font=New-Object Drawing.Font("Segoe UI",9.25)
    $info.Size=New-Object Drawing.Size(520,76)
    $info.Location=New-Object Drawing.Point(26,52)
    $dlg.Controls.Add($info)

    $profileLabel=New-Object Windows.Forms.Label
    $profileLabel.Text="Safe dgVoodoo test profiles"
    $profileLabel.Font=New-Object Drawing.Font("Segoe UI Semibold",10)
    $profileLabel.AutoSize=$true
    $profileLabel.Location=New-Object Drawing.Point(26,134)
    $dlg.Controls.Add($profileLabel)

    $profiles=@(
        @{Text="Test Profile A - GeForce 9800 GT / 512 MB (recommended first)"; Profile="A"; Y=160},
        @{Text="Test Profile B - Internal3D / 512 MB"; Profile="B"; Y=210},
        @{Text="Test Profile C - GeForce 9800 GT / 1024 MB"; Profile="C"; Y=260}
    )

    foreach($item in $profiles){
        $b=New-Object Windows.Forms.Button
        $b.Text=$item.Text
        $b.Size=New-Object Drawing.Size(520,38)
        $b.Location=New-Object Drawing.Point(26,$item.Y)
        $b.FlatStyle="Flat"
        $b.BackColor=[Drawing.Color]::FromArgb(29,35,47)
        $b.ForeColor=[Drawing.Color]::FromArgb(240,244,248)
        $profile=$item.Profile
        $b.Add_Click({
            $dlg.Close()
            Start-SR2SafeDgVoodooTest -Profile $profile
        }.GetNewClosure())
        $dlg.Controls.Add($b)
    }


    $launch=New-Object Windows.Forms.Button
    $launch.Text="Launch Saints Row 2"
    $launch.Size=New-Object Drawing.Size(480,38)
    $launch.Location=New-Object Drawing.Point(26,300)
    $launch.FlatStyle="Flat"
    $launch.Add_Click({
        try {
            if(-not (Test-SR2DXVKMode)){
                [Windows.Forms.MessageBox]::Show("Install DXVK first.","Saints Row 2 DXVK")|Out-Null
                return
            }
            Start-Process -FilePath $script:GameExe -WorkingDirectory $script:GameDir | Out-Null
            Write-Log "[SR2] Launched Saints Row 2 using the installed DXVK path."
            $dlg.Close()
        } catch {
            Write-Log "[ERROR] Could not launch Saints Row 2: $($_.Exception.Message)"
        }
    })
    $dlg.Controls.Add($launch)


    $settingsHelp=New-Object Windows.Forms.Button
    $settingsHelp.Text="Neural Rendering controls / Add-ons UI"
    $settingsHelp.Size=New-Object Drawing.Size(500,38)
    $settingsHelp.Location=New-Object Drawing.Point(26,548)
    $settingsHelp.FlatStyle="Flat"
    $settingsHelp.Add_Click({Show-SR2NRSettingsHelp})
    $dlg.Controls.Add($settingsHelp)

    $note=New-Object Windows.Forms.Label
    $note.Text="Each profile keeps OutputAPI=d3d11_fl11_0 and DisableAndPassThru=false. No forced AA, filtering, resolution, VSync, or FastVideoMemoryAccess."
    $note.Font=New-Object Drawing.Font("Segoe UI",8.75)
    $note.Size=New-Object Drawing.Size(520,42)
    $note.Location=New-Object Drawing.Point(26,308)
    $dlg.Controls.Add($note)

    $isoLabel=New-Object Windows.Forms.Label
    $isoLabel.Text="Manual isolation / recovery"
    $isoLabel.Font=New-Object Drawing.Font("Segoe UI Semibold",10)
    $isoLabel.AutoSize=$true
    $isoLabel.Location=New-Object Drawing.Point(26,360)
    $dlg.Controls.Add($isoLabel)

    $items=@(
        @{Text="Disable shaders / Lumenite"; Stage="ShadersOff"; Y=388},
        @{Text="Disable ReShade (dxgi.dll)"; Stage="ReShadeOff"; Y=434},
        @{Text="Disable dgVoodoo2 - native D3D9"; Stage="DgVoodooOff"; Y=480},
        @{Text="Restore all components"; Stage="RestoreAll"; Y=526}
    )

    foreach($item in $items){
        $b=New-Object Windows.Forms.Button
        $b.Text=$item.Text
        $b.Size=New-Object Drawing.Size(520,34)
        $b.Location=New-Object Drawing.Point(26,$item.Y)
        $b.FlatStyle="Flat"
        $b.BackColor=[Drawing.Color]::FromArgb(29,35,47)
        $b.ForeColor=[Drawing.Color]::FromArgb(240,244,248)
        $stage=$item.Stage
        $b.Add_Click({
            Set-SR2IsolationStage -Stage $stage
            $dlg.Close()
        }.GetNewClosure())
        $dlg.Controls.Add($b)
    }

    $dlg.ShowDialog($form)|Out-Null
    $dlg.Dispose()
}

function Update-SR2IsolationButton {
    try {
        if(-not $sr2IsolationButton){ return }
        $isSR2=Test-IsSaintsRow2
        $sr2IsolationButton.Visible=$isSR2
        $sr2IsolationButton.Enabled=($isSR2 -and $script:GameExe -and (Test-Path $script:GameExe))
        Update-ActionLayout
    } catch {}
}



# ---------- Saints Row 2 Vulkan32 DLSS5 beta path ----------
# Upstream CI build #14 / commit 7d61175 implements the 32-bit Vulkan (DXVK) transport.
$script:SR2Vulkan32ReleaseTag="v0.8.0-beta.3"
$script:SR2Vulkan32ReleaseApi="https://api.github.com/repos/jlrouzies-fr/DLSS5-Feeder/releases/tags/$($script:SR2Vulkan32ReleaseTag)"
$script:SR2Vulkan32Commit="a96cd72"


function Get-SR2Vulkan32ReleaseZipUrl {
    try {
        $headers=@{"User-Agent"="Universal-DLSS5-Installer"}
        $rel=Invoke-RestMethod -UseBasicParsing -Headers $headers -Uri $script:SR2Vulkan32ReleaseApi
        $asset=$rel.assets |
            Where-Object { $_.name -match '(?i)\.zip$' -and $_.name -notmatch '(?i)source|vk-layer|layer-only' } |
            Sort-Object size -Descending |
            Select-Object -First 1
        if(-not $asset){
            throw "No packaged ZIP asset was found for $($script:SR2Vulkan32ReleaseTag)."
        }
        Write-Log "[SR2 NR] Upstream package: $($asset.name)"
        return $asset.browser_download_url
    } catch {
        throw "Could not resolve the $($script:SR2Vulkan32ReleaseTag) release asset: $($_.Exception.Message)"
    }
}

function Get-SR2FeedVersionFromLog {
    try {
        $log=Join-Path $script:GameDir "dlss5-feed.log"
        if(-not (Test-Path $log)){ return "" }
        $first=(Get-Content -LiteralPath $log -TotalCount 3 -ErrorAction SilentlyContinue) -join " "
        if($first -match '(?i)dlss5-feed(?:32)?\s+([0-9A-Za-z\.\-]+)'){ return $matches[1] }
    } catch {}
    return ""
}

function Show-SR2NRSettingsHelp {
    if(-not (Test-IsSaintsRow2)){ return }

    $dlg=New-Object Windows.Forms.Form
    $dlg.Text="Saints Row 2 - Neural Rendering Controls"
    $dlg.StartPosition="CenterParent"
    $dlg.FormBorderStyle="FixedDialog"
    $dlg.MaximizeBox=$false
    $dlg.MinimizeBox=$false
    $dlg.Size=New-Object Drawing.Size(590,485)
    $dlg.BackColor=[Drawing.Color]::FromArgb(15,18,24)
    $dlg.ForeColor=[Drawing.Color]::FromArgb(240,244,248)

    $title=New-Object Windows.Forms.Label
    $title.Text="Neural Rendering controls"
    $title.Font=New-Object Drawing.Font("Segoe UI Semibold",15)
    $title.AutoSize=$true
    $title.Location=New-Object Drawing.Point(24,20)
    $dlg.Controls.Add($title)

    $body=New-Object Windows.Forms.Label
    $body.Text="Current feeder controls live in ReShade's Add-ons tab, not in the old shader sliders.`r`n`r`nIn Saints Row 2:`r`n1. Press Home.`r`n2. Open Add-ons.`r`n3. Expand DLSS 5 Feed.`r`n4. Confirm Mode = 2.`r`n5. Use the DLSS 5 host settings section for Neural Uplift, NR Intensity, Style, Local Structure, Local Tone, Auto Mask and UI Correction.`r`n6. Click APPLY after changing host settings.`r`n`r`nThe normal feed controls (mode, HDR/depth overrides, MV scale, preset, Advanced) save immediately. Host neural settings require APPLY."
    $body.Font=New-Object Drawing.Font("Segoe UI",9.5)
    $body.Size=New-Object Drawing.Size(530,270)
    $body.Location=New-Object Drawing.Point(26,58)
    $dlg.Controls.Add($body)

    $check=New-Object Windows.Forms.Button
    $check.Text="Check installed feeder version"
    $check.Size=New-Object Drawing.Size(530,40)
    $check.Location=New-Object Drawing.Point(26,338)
    $check.FlatStyle="Flat"
    $check.Add_Click({
        $v=Get-SR2FeedVersionFromLog
        if($v){
            Write-Log "[SR2 NR] Installed feeder log version: $v"
            [Windows.Forms.MessageBox]::Show("dlss5-feed.log reports: $v","SR2 Neural Rendering")|Out-Null
        } else {
            [Windows.Forms.MessageBox]::Show("No feeder version is visible in dlss5-feed.log yet. Launch SR2 once, then check again.","SR2 Neural Rendering")|Out-Null
        }
    })
    $dlg.Controls.Add($check)

    $note=New-Object Windows.Forms.Label
    $note.Text="Important: old DLSS5_Feed.fx host sliders are obsolete. This installer replaces the shader and addon/host as a matched release set."
    $note.Font=New-Object Drawing.Font("Segoe UI",9)
    $note.Size=New-Object Drawing.Size(530,48)
    $note.Location=New-Object Drawing.Point(26,392)
    $dlg.Controls.Add($note)

    $dlg.ShowDialog($form)|Out-Null
    $dlg.Dispose()
}

function Get-SR2Vulkan32MarkerPath {
    if(-not $script:GameDir){ return $null }
    return Join-Path $script:GameDir ".universal-dlss5-sr2-vulkan32-beta"
}

function Test-SR2Vulkan32Installed {
    try {
        if(-not (Test-IsSaintsRow2) -or -not $script:GameDir){ return $false }
        $marker=Get-SR2Vulkan32MarkerPath
        return ((Test-Path $marker) -and
                (Test-Path (Join-Path $script:GameDir "dlss5-feed.addon32")) -and
                (Test-Path (Join-Path $script:GameDir "host64\dlss5-feed-host64.exe")) -and
                (Test-Path (Join-Path $script:GameDir "reshade-shaders\Shaders\DLSS5_Feed.fx")))
    } catch { return $false }
}

function Set-SR2FeedMode {
    param([ValidateSet(0,1,2)][int]$Mode)

    if(-not (Test-IsSaintsRow2) -or -not $script:GameDir){ return }
    $cfg=Join-Path $script:GameDir "dlss5-feed.cfg"
    $lines=@()
    if(Test-Path $cfg){
        $lines=Get-Content -LiteralPath $cfg -ErrorAction SilentlyContinue
    }
    if(-not $lines){ $lines=@() }

    $seen=$false
    $out=@()
    foreach($line in $lines){
        if($line -match '^\s*mode\s*='){
            $out += "mode=$Mode"
            $seen=$true
        } else {
            $out += $line
        }
    }
    if(-not $seen){ $out += "mode=$Mode" }

    foreach($pair in @(
        @{K="enabled";V="1"},
        @{K="host_window";V="1"},
        @{K="work_resolution";V="100"}
    )){
        $found=$false
        for($i=0;$i -lt $out.Count;$i++){
            if($out[$i] -match ("^\s*"+[regex]::Escape($pair.K)+"\s*=")){
                $out[$i]=$pair.K+"="+$pair.V
                $found=$true
                break
            }
        }
        if(-not $found){ $out += ($pair.K+"="+$pair.V) }
    }

    [IO.File]::WriteAllLines($cfg,$out,[Text.UTF8Encoding]::new($false))
    switch($Mode){
        0 { Write-Log "[SR2 Vulkan32] Feed mode set to 0 (inert)." }
        1 { Write-Log "[SR2 Vulkan32] Feed mode set to 1 (transport test, no NGX)." }
        2 { Write-Log "[SR2 Vulkan32] Feed mode set to 2 (full DLSS5 Neural Rendering)." }
    }
}


function Set-IniKey {
    param([string]$Path,[string]$Section,[string]$Key,[string]$Value)

    if(-not (Test-Path $Path)){
        [IO.File]::WriteAllText($Path,"",[Text.UTF8Encoding]::new($false))
    }

    $lines=@(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    $out=New-Object System.Collections.Generic.List[string]
    $inSection=$false
    $sectionFound=$false
    $keyWritten=$false

    foreach($line in $lines){
        if($line -match '^\s*\[(.+?)\]\s*$'){
            if($inSection -and -not $keyWritten){
                $out.Add("$Key=$Value")
                $keyWritten=$true
            }
            $name=$matches[1]
            $inSection=($name -ieq $Section)
            if($inSection){ $sectionFound=$true }
            $out.Add($line)
            continue
        }

        if($inSection -and $line -match ("^\s*"+[regex]::Escape($Key)+"\s*=")){
            if(-not $keyWritten){
                $out.Add("$Key=$Value")
                $keyWritten=$true
            }
        } else {
            $out.Add($line)
        }
    }

    if(-not $sectionFound){
        if($out.Count -gt 0 -and $out[$out.Count-1] -ne ""){ $out.Add("") }
        $out.Add("[$Section]")
        $out.Add("$Key=$Value")
    } elseif($inSection -and -not $keyWritten){
        $out.Add("$Key=$Value")
    }

    [IO.File]::WriteAllLines($Path,$out,[Text.UTF8Encoding]::new($false))
}


function Repair-SR2DLSSFeedCore {
    if(-not (Test-IsSaintsRow2) -or -not $script:GameDir){ return $false }

    try {
        $tools=Join-Path $script:AppRoot "Tools\SR2-Vulkan32"
        $extract=Join-Path $tools "ci-extract"
        $zip=Join-Path $tools "dlss5-feeder-v0.8.0-beta.3.zip"
        New-Item -ItemType Directory -Force -Path $tools | Out-Null

        $addonTarget=Join-Path $script:GameDir "dlss5-feed.addon32"
        $shaderDir=Join-Path $script:GameDir "reshade-shaders\Shaders"
        $shaderTarget=Join-Path $shaderDir "DLSS5_Feed.fx"
        $hostDir=Join-Path $script:GameDir "host64"
        $hostTarget=Join-Path $hostDir "dlss5-feed-host64.exe"
        New-Item -ItemType Directory -Force -Path $shaderDir,$hostDir | Out-Null

        Write-Log "===== SR2 DLSS5 FEED CORE REPAIR ====="

        # Reuse current CI extraction when complete; otherwise refresh it.
        $addon=$null; $shader=$null; $hostExe=$null
        if(Test-Path $extract){
            $addon=Get-ChildItem -Path $extract -Filter "dlss5-feed.addon32" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            $shader=Get-ChildItem -Path $extract -Filter "DLSS5_Feed.fx" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            $hostExe=Get-ChildItem -Path $extract -Filter "dlss5-feed-host64.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        }

        if(-not $addon -or -not $shader -or -not $hostExe){
            Write-Log "[INFO] Refreshing upstream Vulkan32 release package..."
            if(Test-Path $extract){ Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Force -Path $extract | Out-Null
            $releaseZipUrl=Get-SR2Vulkan32ReleaseZipUrl
            Invoke-WebRequest -UseBasicParsing -Headers @{"User-Agent"="Universal-DLSS5-Installer"} -Uri $releaseZipUrl -OutFile $zip
            Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

            $addon=Get-ChildItem -Path $extract -Filter "dlss5-feed.addon32" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            $shader=Get-ChildItem -Path $extract -Filter "DLSS5_Feed.fx" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            $hostExe=Get-ChildItem -Path $extract -Filter "dlss5-feed-host64.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        }

        if(-not $addon){ throw "dlss5-feed.addon32 was not found in the v0.8.0-beta.3 release package." }
        if(-not $hostExe){ throw "dlss5-feed-host64.exe was not found in the v0.8.0-beta.3 release package." }

        # Always overwrite these AFTER ReShade setup. ReShade package installation can alter
        # the shader tree, so installing the feeder last makes the end state deterministic.
        if(Test-Path $addonTarget){
            Copy-Item -LiteralPath $addonTarget -Destination ($addonTarget+".before-feed-core-fix.bak") -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -LiteralPath $addon.FullName -Destination $addonTarget -Force

        if(Test-Path $hostTarget){
            Copy-Item -LiteralPath $hostTarget -Destination ($hostTarget+".before-feed-core-fix.bak") -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -LiteralPath $hostExe.FullName -Destination $hostTarget -Force

        if($shader){
            Copy-Item -LiteralPath $shader.FullName -Destination $shaderTarget -Force
        } else {
            # Shader source is open-source; use the exact Vulkan32 CI commit as a fallback.
            $raw="https://raw.githubusercontent.com/jlrouzies-fr/DLSS5-Feeder/$($script:SR2Vulkan32Commit)/shaders/DLSS5_Feed.fx"
            Write-Log "[INFO] Release package shader not found; downloading DLSS5_Feed.fx from the matching commit..."
            Invoke-WebRequest -UseBasicParsing -Uri $raw -OutFile $shaderTarget
        }

        # Validate that files really exist and are non-empty.
        $addonInfo=Get-Item -LiteralPath $addonTarget -ErrorAction SilentlyContinue
        $shaderInfo=Get-Item -LiteralPath $shaderTarget -ErrorAction SilentlyContinue
        $hostInfo=Get-Item -LiteralPath $hostTarget -ErrorAction SilentlyContinue

        if(-not $addonInfo -or $addonInfo.Length -lt 1024){
            throw "dlss5-feed.addon32 is missing or unexpectedly small after repair."
        }
        if(-not $shaderInfo -or $shaderInfo.Length -lt 512){
            throw "DLSS5_Feed.fx is missing or unexpectedly small after repair."
        }
        if(-not $hostInfo -or $hostInfo.Length -lt 1024){
            throw "dlss5-feed-host64.exe is missing or unexpectedly small after repair."
        }

        Write-Log ("[OK] dlss5-feed.addon32: {0:N0} bytes" -f $addonInfo.Length)
        Write-Log ("[OK] DLSS5_Feed.fx: {0:N0} bytes" -f $shaderInfo.Length)
        Write-Log ("[OK] host64\dlss5-feed-host64.exe: {0:N0} bytes" -f $hostInfo.Length)

        # Make sure ReShade is actually pointed at the shader directory.
        $ini=Join-Path $script:GameDir "ReShade.ini"
        Set-IniKey -Path $ini -Section "GENERAL" -Key "EffectSearchPaths" -Value ".\reshade-shaders\Shaders\**"
        Set-IniKey -Path $ini -Section "GENERAL" -Key "TextureSearchPaths" -Value ".\reshade-shaders\Textures\**"

        Write-Log "[SUCCESS] DLSS5 Feed core files repaired and validated."
        Write-Log "[NEXT] Fully exit Saints Row 2, then relaunch it."
        Write-Log "[EXPECTED] ReShade.log should register dlss5-feed.addon32 and compile DLSS5_Feed.fx."
        return $true
    } catch {
        Write-Log "[ERROR] DLSS5 Feed core repair failed: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show(
            "DLSS5 Feed core repair failed.`r`n`r`n$($_.Exception.Message)",
            "SR2 DLSS5 Feed Repair",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $false
    }
}

function Repair-SR2VulkanShaders {
    if(-not (Test-IsSaintsRow2) -or -not $script:GameDir){ return $false }

    try {
        if(-not (Repair-SR2DLSSFeedCore)){
            Write-Log "[WARN] Feed core repair did not fully complete; continuing with shader/provider repair."
        }
        $shaderRoot=Join-Path $script:GameDir "reshade-shaders"
        $shaderDir=Join-Path $shaderRoot "Shaders"
        $textureDir=Join-Path $shaderRoot "Textures"
        New-Item -ItemType Directory -Force -Path $shaderDir,$textureDir | Out-Null

        Write-Log "===== SR2 VULKAN SHADER REPAIR ====="

        # 1) Ensure DLSS5_Feed.fx exists in the actual ReShade search tree.
        $feedTarget=Join-Path $shaderDir "DLSS5_Feed.fx"
        if(-not (Test-Path $feedTarget)){
            $candidate=$null

            # Search our downloaded Vulkan32 release package first.
            $candidate=Get-ChildItem -Path (Join-Path $script:AppRoot "Tools") -Filter "DLSS5_Feed.fx" -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1

            # Then search the game folder in case it landed elsewhere.
            if(-not $candidate){
                $candidate=Get-ChildItem -Path $script:GameDir -Filter "DLSS5_Feed.fx" -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -ne $feedTarget } |
                    Select-Object -First 1
            }

            if($candidate){
                Copy-Item -LiteralPath $candidate.FullName -Destination $feedTarget -Force
                Write-Log "[OK] Installed DLSS5_Feed.fx -> reshade-shaders\Shaders"
            } else {
                Write-Log "[ERROR] DLSS5_Feed.fx could not be located. Run Install / Repair Vulkan32 Beta again."
            }
        } else {
            Write-Log "[OK] DLSS5_Feed.fx already exists."
        }

        # 2) Repair LumeniteFX, then normalize its shader tree into ReShade's search path.
        try {
            Install-OrRepairLumeniteFX | Out-Null
        } catch {
            Write-Log "[WARN] Built-in Lumenite repair returned: $($_.Exception.Message)"
        }

        $kernelTarget=Join-Path $shaderDir "lumenite_Kernel.fx"
        if(-not (Test-Path $kernelTarget)){
            $kernel=Get-ChildItem -Path $script:GameDir -Filter "lumenite_Kernel.fx" -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if(-not $kernel){
                $kernel=Get-ChildItem -Path (Join-Path $script:AppRoot "Tools") -Filter "lumenite_Kernel.fx" -File -Recurse -ErrorAction SilentlyContinue |
                    Select-Object -First 1
            }
            if($kernel){
                Copy-Item -LiteralPath $kernel.FullName -Destination $kernelTarget -Force
                Write-Log "[OK] Installed lumenite_Kernel.fx -> reshade-shaders\Shaders"
            } else {
                Write-Log "[ERROR] lumenite_Kernel.fx could not be located after repair."
            }
        } else {
            Write-Log "[OK] lumenite_Kernel.fx already exists."
        }

        # Copy Lumenite include folders into the same shader tree if they landed elsewhere.
        $includes=@(
            Get-ChildItem -Path $script:GameDir -Directory -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ieq "include" -and $_.FullName -match 'Lumenite|reshade-shaders' }
        )
        foreach($inc in $includes){
            $dest=Join-Path $shaderDir "include"
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item -Path (Join-Path $inc.FullName "*") -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
        }

        # 3) Make ReShade search the correct directories recursively.
        $ini=Join-Path $script:GameDir "ReShade.ini"
        Set-IniKey -Path $ini -Section "GENERAL" -Key "EffectSearchPaths" -Value ".\reshade-shaders\Shaders\**"
        Set-IniKey -Path $ini -Section "GENERAL" -Key "TextureSearchPaths" -Value ".\reshade-shaders\Textures\**"

        # 4) Keep provider=3 in the active preset, but do not auto-enable techniques.
        $preset=Join-Path $script:GameDir "ReShadePreset.ini"
        if(Test-Path $ini){
            $presetLine=Get-Content -LiteralPath $ini -ErrorAction SilentlyContinue |
                Where-Object { $_ -match '^\s*PresetPath\s*=' } | Select-Object -First 1
            if($presetLine){
                $pv=($presetLine -split '=',2)[1].Trim()
                if($pv){
                    if([IO.Path]::IsPathRooted($pv)){ $preset=$pv }
                    else { $preset=Join-Path $script:GameDir $pv }
                }
            }
        }

        if(-not (Test-Path $preset)){
            [IO.File]::WriteAllText($preset,"[GENERAL]`r`n",[Text.UTF8Encoding]::new($false))
        }

        $pc=Get-Content -LiteralPath $preset -Raw -ErrorAction SilentlyContinue
        if($pc -match '(?m)^\s*PreprocessorDefinitions\s*='){
            $line=[regex]::Match($pc,'(?m)^\s*PreprocessorDefinitions\s*=.*$').Value
            $defs=($line -split '=',2)[1]
            $parts=@($defs -split ',' | ForEach-Object {$_.Trim()} | Where-Object {$_ -and $_ -notmatch '^DLSS5_MV_PROVIDER='})
            $parts += "DLSS5_MV_PROVIDER=3"
            $newLine="PreprocessorDefinitions="+($parts -join ',')
            $pc=[regex]::Replace($pc,'(?m)^\s*PreprocessorDefinitions\s*=.*$',
                [System.Text.RegularExpressions.MatchEvaluator]{param($m)$newLine},1)
        } else {
            if($pc -notmatch '(?m)^\[GENERAL\]'){ $pc="[GENERAL]`r`n"+$pc }
            $pc=$pc -replace '(?m)^\[GENERAL\]\s*$',"[GENERAL]`r`nPreprocessorDefinitions=DLSS5_MV_PROVIDER=3"
        }
        [IO.File]::WriteAllText($preset,$pc,[Text.UTF8Encoding]::new($false))

        $feedOK=Test-Path $feedTarget
        $kernelOK=Test-Path $kernelTarget

        if($feedOK -and $kernelOK){
            Write-Log "[SUCCESS] Required SR2 Vulkan shaders are installed."
            Write-Log "[NEXT] Fully close SR2 and relaunch it so ReShade reloads the effect list."
            Write-Log "[EXPECTED] ReShade Home should now show LUMENITE: Kernel 2.0 and DLSS 5 Feed."
            return $true
        }

        Write-Log "[BLOCKED] One or more required shader files are still missing."
        return $false
    } catch {
        Write-Log "[ERROR] SR2 Vulkan shader repair failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-SR2ReShadeVulkan {
    param(
        [ValidateSet("FullAddon","Standard")]
        [string]$Edition="FullAddon"
    )

    if(-not (Test-IsSaintsRow2)){ return $false }

    try {
        $tools=Join-Path $script:AppRoot "Tools\SR2-Vulkan32"
        New-Item -ItemType Directory -Force -Path $tools | Out-Null

        if($Edition -eq "FullAddon"){
            $setupName="ReShade_Setup_6.8.0_Addon.exe"
            $setupUrl="https://reshade.me/downloads/ReShade_Setup_6.8.0_Addon.exe"
            Write-Log "[SR2 Vulkan32] ReShade edition: 6.8.0 Full Add-on (recommended / required for DLSS5 add-on loading)."
        } else {
            $setupName="ReShade_Setup_6.8.0.exe"
            $setupUrl="https://reshade.me/downloads/ReShade_Setup_6.8.0.exe"
            Write-Log "[SR2 Vulkan32] ReShade edition: 6.8.0 Standard."
            Write-Log "[WARN] Standard ReShade is for compatibility testing only; DLSS5 add-on loading may be unavailable."
        }

        $setup=Join-Path $tools $setupName
        if(-not (Test-Path $setup)){
            Write-Log "[SR2 Vulkan32] Downloading $setupName ..."
            Invoke-WebRequest -UseBasicParsing -Uri $setupUrl -OutFile $setup
        }

        # DXVK owns d3d9.dll. ReShade must attach as a Vulkan layer, not as a local dxgi.dll.
        $dxgi=Join-Path $script:GameDir "dxgi.dll"
        if(Test-Path $dxgi){
            $off=Join-Path $script:GameDir "dxgi.dll.SR2_VULKAN_OFF"
            if(Test-Path $off){ Remove-Item -LiteralPath $off -Force -ErrorAction SilentlyContinue }
            Rename-Item -LiteralPath $dxgi -NewName "dxgi.dll.SR2_VULKAN_OFF" -Force
            Write-Log "[SR2 Vulkan32] Disabled local dxgi.dll; ReShade will use the Vulkan layer."
        }

        Write-Log "[SR2 Vulkan32] Launching selected ReShade installer in Vulkan mode..."
        Write-Log "[INFO] If the installer UI appears, select SR2_pc.exe and Vulkan, then finish setup."

        # First try normal setup so the Vulkan layer can be registered correctly.
        $p=Start-Process -FilePath $setup -ArgumentList @("`"$script:GameExe`"","--api","vulkan") -Wait -PassThru

        if($p.ExitCode -ne 0){
            Write-Log "[WARN] ReShade setup returned exit code $($p.ExitCode)."
        } else {
            Write-Log "[OK] ReShade Vulkan setup completed."
        }

        # Remember the selected edition for verification/UI.
        $editionFile=Join-Path $script:GameDir ".universal-dlss5-reshade-edition"
        [IO.File]::WriteAllText($editionFile,$Edition,[Text.UTF8Encoding]::new($false))

        return $true
    } catch {
        Write-Log "[ERROR] ReShade Vulkan setup failed: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show(
            "ReShade Vulkan setup failed.`r`n`r`n$($_.Exception.Message)",
            "SR2 ReShade Vulkan",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $false
    }
}

function Install-SR2Vulkan32FeederBeta {
    if(-not (Test-IsSaintsRow2) -or -not $script:GameDir){ return $false }

    try {
        if(-not (Test-SR2DXVKMode)){
            Write-Log "[SR2 Vulkan32] DXVK is required. Installing DXVK first..."
            if(-not (Install-SR2DXVK24)){ return $false }
        }

        $tools=Join-Path $script:AppRoot "Tools\SR2-Vulkan32"
        New-Item -ItemType Directory -Force -Path $tools | Out-Null
        $zip=Join-Path $tools "dlss5-feeder-v0.8.0-beta.3.zip"
        $extract=Join-Path $tools "ci-extract"
        if(Test-Path $extract){ Remove-Item -LiteralPath $extract -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $extract | Out-Null

        Write-Log "===== SR2 VULKAN32 DLSS5 BETA ====="
        Write-Log "[INFO] Using upstream v0.8.0-beta.3 matched 32-bit Vulkan/DXVK feeder package."
        Write-Log "[INFO] Matched addon32 + host64 protocol set required for 0.8.0 beta."
        Write-Log "[INFO] Downloading upstream v0.8.0-beta.3 release package..."
        try {
            $releaseZipUrl=Get-SR2Vulkan32ReleaseZipUrl
            Invoke-WebRequest -UseBasicParsing -Headers @{"User-Agent"="Universal-DLSS5-Installer"} -Uri $releaseZipUrl -OutFile $zip
        } catch {
            throw "Could not download the public CI artifact through nightly.link. Open GitHub Actions build #14 and download '$($script:SR2Vulkan32Artifact)' manually, then retry. $($_.Exception.Message)"
        }

        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

        $addon=Get-ChildItem -Path $extract -Filter "dlss5-feed.addon32" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        $shader=Get-ChildItem -Path $extract -Filter "DLSS5_Feed.fx" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        $hostExe=Get-ChildItem -Path $extract -Filter "dlss5-feed-host64.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if(-not $addon -or -not $shader -or -not $hostExe){
            throw "Release package did not contain addon32, DLSS5_Feed.fx and host64 executable."
        }

        $shaderDir=Join-Path $script:GameDir "reshade-shaders\Shaders"
        $hostDir=Join-Path $script:GameDir "host64"
        New-Item -ItemType Directory -Force -Path $shaderDir,$hostDir | Out-Null

        foreach($spec in @(
            @{Src=$addon.FullName;Dst=(Join-Path $script:GameDir "dlss5-feed.addon32")},
            @{Src=$shader.FullName;Dst=(Join-Path $shaderDir "DLSS5_Feed.fx")},
            @{Src=$hostExe.FullName;Dst=(Join-Path $hostDir "dlss5-feed-host64.exe")}
        )){
            if(Test-Path $spec.Dst){
                Copy-Item -LiteralPath $spec.Dst -Destination ($spec.Dst+".before-vulkan32-beta.bak") -Force -ErrorAction SilentlyContinue
            }
            Copy-Item -LiteralPath $spec.Src -Destination $spec.Dst -Force
        }

        # Optional fallback Vulkan interop layer files from CI, if present.
        $layerFiles=Get-ChildItem -Path $extract -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^VkLayer_feed_vk.*\.(dll|json)$' }
        if($layerFiles){
            $layerDir=Join-Path $script:GameDir "layer\x86"
            New-Item -ItemType Directory -Force -Path $layerDir | Out-Null
            foreach($lf in $layerFiles){
                Copy-Item -LiteralPath $lf.FullName -Destination (Join-Path $layerDir $lf.Name) -Force
            }
            Write-Log "[OK] Copied feeder Vulkan-layer fallback files."
        }

        $selectedEdition="FullAddon"
        try {
            $editionFile=Join-Path $script:GameDir ".universal-dlss5-reshade-edition"
            if(Test-Path $editionFile){
                $saved=(Get-Content -LiteralPath $editionFile -Raw -ErrorAction SilentlyContinue).Trim()
                if($saved -in @("FullAddon","Standard")){ $selectedEdition=$saved }
            }
        } catch {}
        if(-not (Install-SR2ReShadeVulkan -Edition $selectedEdition)){ return $false }

        if(-not (Repair-SR2VulkanShaders)){ Write-Log "[WARN] Shader repair did not fully complete." }

        # Keep Lumenite available, but do not force-enable effects at startup.
        try { Install-OrRepairLumeniteFX | Out-Null } catch {}

        # Set provider=3 in active preset without enabling techniques.
        $preset=Join-Path $script:GameDir "ReShadePreset.ini"
        $reshadeIni=Join-Path $script:GameDir "ReShade.ini"
        if(Test-Path $reshadeIni){
            $rp=Get-Content -LiteralPath $reshadeIni -ErrorAction SilentlyContinue |
                Where-Object { $_ -match '^\s*PresetPath\s*=' } | Select-Object -First 1
            if($rp){
                $pv=($rp -split '=',2)[1].Trim()
                if($pv){
                    if([IO.Path]::IsPathRooted($pv)){ $preset=$pv }
                    else { $preset=Join-Path $script:GameDir $pv }
                }
            }
        }
        if(-not (Test-Path $preset)){
            [IO.File]::WriteAllText($preset,"[GENERAL]`r`n",[Text.UTF8Encoding]::new($false))
        }
        $pc=Get-Content -LiteralPath $preset -Raw -ErrorAction SilentlyContinue
        if($pc -match '(?m)^\s*PreprocessorDefinitions\s*='){
            $line=[regex]::Match($pc,'(?m)^\s*PreprocessorDefinitions\s*=.*$').Value
            $defs=($line -split '=',2)[1]
            $parts=@($defs -split ',' | ForEach-Object {$_.Trim()} | Where-Object {$_ -and $_ -notmatch '^DLSS5_MV_PROVIDER='})
            $parts += "DLSS5_MV_PROVIDER=3"
            $newLine="PreprocessorDefinitions="+($parts -join ',')
            $pc=[regex]::Replace($pc,'(?m)^\s*PreprocessorDefinitions\s*=.*$',[System.Text.RegularExpressions.MatchEvaluator]{param($m)$newLine},1)
        } else {
            if($pc -notmatch '(?m)^\[GENERAL\]'){ $pc="[GENERAL]`r`n"+$pc }
            $pc=$pc -replace '(?m)^\[GENERAL\]\s*$',"[GENERAL]`r`nPreprocessorDefinitions=DLSS5_MV_PROVIDER=3"
        }
        [IO.File]::WriteAllText($preset,$pc,[Text.UTF8Encoding]::new($false))

        Set-SR2FeedMode -Mode 1
        $marker=Get-SR2Vulkan32MarkerPath
        $markerText=@"
Mode=Vulkan32-NR-SettingsUI
Release=v0.8.0-beta.3
UpstreamCommit=a96cd72
DXVK=2.4-x32
Installed=$(Get-Date -Format o)
"@
        [IO.File]::WriteAllText($marker,$markerText,[Text.UTF8Encoding]::new($false))

        Write-Log "[READY] SR2 Vulkan32 feeder beta installed."
        Write-Log "[MODE 1] Transport test is active. Neural Rendering is NOT enabled yet."
        Write-Log "[NEXT] Launch SR2. In ReShade enable LUMENITE: Kernel 2.0, then DLSS 5 Feed beneath it."
        Write-Log "[PASS] Verify should show 'shared set ready (Vulkan)' and 'frame N delivered (... Vulkan)'."
        Write-Log "[THEN] Switch to Neural mode 2 and test host64/NGX."
        return $true
    } catch {
        Write-Log "[ERROR] SR2 Vulkan32 beta install failed: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show(
            "SR2 Vulkan32 beta installation failed.`r`n`r`n$($_.Exception.Message)",
            "SR2 Vulkan32 DLSS5 Beta",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $false
    }
}

function Get-SR2Vulkan32Status {
    $s=[ordered]@{
        Installed=$false
        ReShadeVulkan=$false
        InteropResolved=$false
        SharedSetReady=$false
        VulkanFrames=$false
        HostFeature=$false
        HostInline=$false
        AddonRegistered=$false
        FeedShaderCompiled=$false
        FeedVersion=""
        SettingsUIExpected=$false
    }
    if(-not $script:GameDir){ return [pscustomobject]$s }
    $s.Installed=Test-SR2Vulkan32Installed

    $rlog=Join-Path $script:GameDir "ReShade.log"
    if(Test-Path $rlog){
        $txt=Get-Content -LiteralPath $rlog -Raw -ErrorAction SilentlyContinue
        $s.ReShadeVulkan=($txt -match '(?i)Vulkan')
        $s.AddonRegistered=($txt -match '(?i)dlss5-feed.*addon32|DLSS 5 Feed \(32-bit\)')
        $s.FeedShaderCompiled=($txt -match '(?i)Successfully compiled .*DLSS5_Feed\.fx')
    }
    $s.FeedVersion=Get-SR2FeedVersionFromLog
    if($s.FeedVersion -match '^0\.8\.0-beta\.[123]$'){
        $s.SettingsUIExpected=$true
    }
    $flog=Join-Path $script:GameDir "dlss5-feed.log"
    if(Test-Path $flog){
        $ft=Get-Content -LiteralPath $flog -Raw -ErrorAction SilentlyContinue
        $s.InteropResolved=($ft -match '(?i)Vulkan:\s*interop entry points resolved')
        $s.SharedSetReady=($ft -match '(?i)shared set ready \(Vulkan\)')
        $s.VulkanFrames=($ft -match '(?i)frame\s+\d+\s+delivered.*Vulkan')
    }
    $hlog=Join-Path $script:GameDir "host64\ReShade.log"
    if(Test-Path $hlog){
        $ht=Get-Content -LiteralPath $hlog -Raw -ErrorAction SilentlyContinue
        $s.HostFeature=($ht -match '(?i)feature\s+18\s+created')
        $s.HostInline=($ht -match '(?i)inline feature 18 evaluation succeeded')
    }
    return [pscustomobject]$s
}

function Show-SR2Vulkan32Dialog {
    if(-not (Test-IsSaintsRow2)){ return }

    $dlg=New-Object Windows.Forms.Form
    $dlg.Text="Saints Row 2 - DLSS5 Neural Rendering"
    $dlg.StartPosition="CenterParent"
    $dlg.FormBorderStyle="FixedDialog"
    $dlg.MaximizeBox=$false
    $dlg.MinimizeBox=$false
    $dlg.Size=New-Object Drawing.Size(560,720)
    $dlg.BackColor=[Drawing.Color]::FromArgb(15,18,24)
    $dlg.ForeColor=[Drawing.Color]::FromArgb(240,244,248)

    $title=New-Object Windows.Forms.Label
    $title.Text="DLSS5 Neural Rendering - Saints Row 2"
    $title.Font=New-Object Drawing.Font("Segoe UI Semibold",15)
    $title.AutoSize=$true
    $title.Location=New-Object Drawing.Point(24,20)
    $dlg.Controls.Add($title)

    $info=New-Object Windows.Forms.Label
    $info.Text="Installs the matched upstream v0.8.0-beta.3 Vulkan32 feeder. Neural controls use ReShade -> Add-ons -> DLSS 5 Feed; host neural settings require APPLY."
    $info.Font=New-Object Drawing.Font("Segoe UI",9.5)
    $info.Size=New-Object Drawing.Size(500,60)
    $info.Location=New-Object Drawing.Point(26,58)
    $dlg.Controls.Add($info)


    $reshadeGroup=New-Object Windows.Forms.GroupBox
    $reshadeGroup.Text="ReShade Vulkan edition"
    $reshadeGroup.Size=New-Object Drawing.Size(500,88)
    $reshadeGroup.Location=New-Object Drawing.Point(26,118)
    $dlg.Controls.Add($reshadeGroup)

    $fullAddonRadio=New-Object Windows.Forms.RadioButton
    $fullAddonRadio.Text="Full Add-on 6.8.0  (recommended for DLSS5)"
    $fullAddonRadio.AutoSize=$true
    $fullAddonRadio.Location=New-Object Drawing.Point(16,26)
    $fullAddonRadio.Checked=$true
    $reshadeGroup.Controls.Add($fullAddonRadio)

    $standardRadio=New-Object Windows.Forms.RadioButton
    $standardRadio.Text="Standard 6.8.0  (compatibility test only)"
    $standardRadio.AutoSize=$true
    $standardRadio.Location=New-Object Drawing.Point(16,52)
    $reshadeGroup.Controls.Add($standardRadio)

    try {
        $editionFile=Join-Path $script:GameDir ".universal-dlss5-reshade-edition"
        if(Test-Path $editionFile){
            $saved=(Get-Content -LiteralPath $editionFile -Raw -ErrorAction SilentlyContinue).Trim()
            if($saved -eq "Standard"){
                $standardRadio.Checked=$true
            }
        }
    } catch {}

    $install=New-Object Windows.Forms.Button
    $install.Text="Install / Repair Vulkan32 Beta"
    $install.Size=New-Object Drawing.Size(500,42)
    $install.Location=New-Object Drawing.Point(26,216)
    $install.FlatStyle="Flat"
    $install.Add_Click({
        $edition=$(if($standardRadio.Checked){"Standard"}else{"FullAddon"})
        try {
            $editionFile=Join-Path $script:GameDir ".universal-dlss5-reshade-edition"
            [IO.File]::WriteAllText($editionFile,$edition,[Text.UTF8Encoding]::new($false))
        } catch {}
        if($edition -eq "Standard"){
            $answer=[Windows.Forms.MessageBox]::Show(
                "Standard ReShade is useful for Vulkan compatibility testing, but DLSS5 add-on loading requires Full Add-on support.`r`n`r`nContinue with Standard anyway?",
                "ReShade Edition",
                [Windows.Forms.MessageBoxButtons]::YesNo,
                [Windows.Forms.MessageBoxIcon]::Warning
            )
            if($answer -ne [Windows.Forms.DialogResult]::Yes){ return }
        }
        $dlg.Close()
        Install-SR2Vulkan32FeederBeta | Out-Null
    })
    $dlg.Controls.Add($install)


    $reshadeOnly=New-Object Windows.Forms.Button
    $reshadeOnly.Text="Install selected ReShade only"
    $reshadeOnly.Size=New-Object Drawing.Size(500,36)
    $reshadeOnly.Location=New-Object Drawing.Point(26,264)
    $reshadeOnly.FlatStyle="Flat"
    $reshadeOnly.Add_Click({
        $edition=$(if($standardRadio.Checked){"Standard"}else{"FullAddon"})
        try {
            $editionFile=Join-Path $script:GameDir ".universal-dlss5-reshade-edition"
            [IO.File]::WriteAllText($editionFile,$edition,[Text.UTF8Encoding]::new($false))
        } catch {}
        $dlg.Close()
        Install-SR2ReShadeVulkan -Edition $edition | Out-Null
    })
    $dlg.Controls.Add($reshadeOnly)


    $shaderRepair=New-Object Windows.Forms.Button
    $shaderRepair.Text="Repair DLSS5 Feed + Lumenite"
    $shaderRepair.Size=New-Object Drawing.Size(500,36)
    $shaderRepair.Location=New-Object Drawing.Point(26,304)
    $shaderRepair.FlatStyle="Flat"
    $shaderRepair.Add_Click({
        $dlg.Close()
        Repair-SR2VulkanShaders | Out-Null
    })
    $dlg.Controls.Add($shaderRepair)

    $m1=New-Object Windows.Forms.Button
    $m1.Text="Set Transport Test - Mode 1"
    $m1.Size=New-Object Drawing.Size(500,42)
    $m1.Location=New-Object Drawing.Point(26,348)
    $m1.FlatStyle="Flat"
    $m1.Add_Click({Set-SR2FeedMode -Mode 1; $dlg.Close()})
    $dlg.Controls.Add($m1)

    $m2=New-Object Windows.Forms.Button
    $m2.Text="Enable Neural Rendering - Mode 2"
    $m2.Size=New-Object Drawing.Size(500,42)
    $m2.Location=New-Object Drawing.Point(26,400)
    $m2.FlatStyle="Flat"
    $m2.Add_Click({
        $st=Get-SR2Vulkan32Status
        if(-not ($st.SharedSetReady -and $st.VulkanFrames)){
            [Windows.Forms.MessageBox]::Show(
                "Transport mode has not been confirmed yet.`r`n`r`nRun Mode 1 first, launch SR2, enable Lumenite Kernel + DLSS 5 Feed, then Verify until Vulkan frames are delivered.",
                "SR2 Vulkan32",
                [Windows.Forms.MessageBoxButtons]::OK,
                [Windows.Forms.MessageBoxIcon]::Warning
            )|Out-Null
            return
        }
        Set-SR2FeedMode -Mode 2
        Write-Log "[SR2 Vulkan32] Neural mode 2 enabled. Launch SR2 and verify host64 NGX/NR evidence."
        $dlg.Close()
    })
    $dlg.Controls.Add($m2)

    $verify=New-Object Windows.Forms.Button
    $verify.Text="Verify Vulkan32 / DLSS5"
    $verify.Size=New-Object Drawing.Size(500,42)
    $verify.Location=New-Object Drawing.Point(26,452)
    $verify.FlatStyle="Flat"
    $verify.Add_Click({
        $st=Get-SR2Vulkan32Status
        Write-Log "----- SR2 Vulkan32 NR Status -----"
        Write-Log ("[" + ($(if($st.ReShadeVulkan){"OK"}else{"WAIT"})) + "] ReShade Vulkan runtime")
        Write-Log ("[" + ($(if($st.AddonRegistered){"OK"}else{"BLOCKED"})) + "] dlss5-feed.addon32 registered")
        Write-Log ("[" + ($(if($st.FeedShaderCompiled){"OK"}else{"BLOCKED"})) + "] DLSS5_Feed.fx compiled")
        if($st.FeedVersion){ Write-Log "[INFO] Feeder version: $($st.FeedVersion)" }
        if($st.SettingsUIExpected){
            Write-Log "[OK] Current 0.8.0 beta settings architecture detected."
            Write-Log "[SETTINGS] ReShade -> Add-ons -> DLSS 5 Feed. Host neural controls require APPLY."
        } else {
            Write-Log "[WARN] Settings UI version not confirmed. Run Install / Repair to replace addon32 + host64 + DLSS5_Feed.fx as a matched set."
        }
        Write-Log ("[" + ($(if($st.InteropResolved){"OK"}else{"WAIT"})) + "] Vulkan interop entry points")
        Write-Log ("[" + ($(if($st.SharedSetReady){"OK"}else{"WAIT"})) + "] Shared set ready (Vulkan)")
        Write-Log ("[" + ($(if($st.VulkanFrames){"OK"}else{"WAIT"})) + "] Frames delivered through Vulkan")
        Write-Log ("[" + ($(if($st.HostFeature){"OK"}else{"WAIT"})) + "] host64 feature 18 created")
        Write-Log ("[" + ($(if($st.HostInline){"SUCCESS"}else{"WAIT"})) + "] host64 inline feature 18 evaluation succeeded")
        if($st.VulkanFrames -and $st.HostInline){
            Write-Log "[SUCCESS] SR2 DLSS5 Neural Rendering is active end-to-end over DXVK/Vulkan."
        } elseif($st.VulkanFrames){
            Write-Log "[TRANSPORT PASS] Vulkan32 transport works. Mode 2 / host64 NR still needs confirmation."
        }
        Write-Log "----------------------------------"
        $dlg.Close()
    })
    $dlg.Controls.Add($verify)

    $launch=New-Object Windows.Forms.Button
    $launch.Text="Launch Saints Row 2"
    $launch.Size=New-Object Drawing.Size(500,42)
    $launch.Location=New-Object Drawing.Point(26,504)
    $launch.FlatStyle="Flat"
    $launch.Add_Click({
        try {
            Start-Process -FilePath $script:GameExe -WorkingDirectory $script:GameDir | Out-Null
            Write-Log "[SR2 Vulkan32] Launched Saints Row 2."
            $dlg.Close()
        } catch {
            Write-Log "[ERROR] Could not launch SR2: $($_.Exception.Message)"
        }
    })
    $dlg.Controls.Add($launch)

    $note=New-Object Windows.Forms.Label
    $note.Text="If DLSS 5 Feed is missing, click Repair DLSS5 Feed + Lumenite, fully close SR2, and relaunch. Then Mode 1 -> LUMENITE Kernel -> DLSS 5 Feed -> Verify."
    $note.Font=New-Object Drawing.Font("Segoe UI",9)
    $note.Size=New-Object Drawing.Size(500,54)
    $note.Location=New-Object Drawing.Point(26,596)
    $dlg.Controls.Add($note)

    $dlg.ShowDialog($form)|Out-Null
    $dlg.Dispose()
}

# ---------- Saints Row 2 DXVK compatibility path ----------
# This validates SR2 + Juiced on a D3D9 -> Vulkan translator only.
# Current dlss5-feed32 still gates 32-bit games to D3D11, so this mode
# intentionally disables local DXGI ReShade and does NOT claim DLSS5 support.
function Get-SR2DXVKMarkerPath {
    if(-not $script:GameDir){ return $null }
    return (Join-Path $script:GameDir ".universal-dlss5-sr2-dxvk-test")
}

function Test-SR2DXVKMode {
    $m=Get-SR2DXVKMarkerPath
    return ($m -and (Test-Path $m))
}

function Expand-SR2DXVKArchive {
    param([string]$Archive,[string]$Destination)

    if(Test-Path $Destination){ Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    $tar=Get-Command tar.exe -ErrorAction SilentlyContinue
    if(-not $tar){
        throw "Windows tar.exe was not found. Windows 10/11 normally includes it and it is required to extract the official DXVK .tar.gz package."
    }

    & $tar.Source -xzf $Archive -C $Destination
    if($LASTEXITCODE -ne 0){ throw "tar.exe failed to extract DXVK (exit code $LASTEXITCODE)." }
}

function Get-SR2DXVKRuntimeLog {
    param([datetime]$Since=[datetime]::MinValue)
    if(-not $script:GameDir){ return $null }

    try {
        $logs=Get-ChildItem -LiteralPath $script:GameDir -File -Filter "*d3d9.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $Since.AddSeconds(-2) } |
            Sort-Object LastWriteTime -Descending

        foreach($log in $logs){
            try {
                $txt=[IO.File]::ReadAllText($log.FullName)
                if($txt -match '(?i)DXVK|Vulkan') { return $log.FullName }
            } catch {}
        }
    } catch {}
    return $null
}

function Get-SR2CrashSince {
    param([datetime]$Since)
    if(-not $script:GameDir){ return $null }

    try {
        $latest=Get-ChildItem -LiteralPath $script:GameDir -File -Filter "SR2_pc.exe.*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $Since.AddSeconds(-2) } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if($latest){ return $latest.FullName }
    } catch {}
    return $null
}

function Restore-SR2NativeD3D9FromDXVK {
    param([string]$Reason="")
    if(-not (Test-IsSaintsRow2) -or -not $script:GameDir){ return }

    try {
        $d3d9=Join-Path $script:GameDir "d3d9.dll"
        $dxvkOff=Join-Path $script:GameDir "d3d9.dll.DXVK.OFF"
        if(Test-Path $d3d9){
            if(Test-Path $dxvkOff){ Remove-Item -LiteralPath $dxvkOff -Force -ErrorAction SilentlyContinue }
            Rename-Item -LiteralPath $d3d9 -NewName "d3d9.dll.DXVK.OFF" -Force
        }

        # Restore the user's previous local ReShade proxy. It is inert under
        # native D3D9 but is preserved for later experiments.
        $dxgi=Join-Path $script:GameDir "dxgi.dll"
        $dxgiOff=Join-Path $script:GameDir "dxgi.dll.SR2_DXVK_OFF"
        if((Test-Path $dxgiOff) -and -not (Test-Path $dxgi)){
            Rename-Item -LiteralPath $dxgiOff -NewName "dxgi.dll" -Force
        }

        $conf=Join-Path $script:GameDir "dxvk.conf"
        $confOff=Join-Path $script:GameDir "dxvk.conf.DXVK.OFF"
        if(Test-Path $conf){
            if(Test-Path $confOff){ Remove-Item -LiteralPath $confOff -Force -ErrorAction SilentlyContinue }
            Rename-Item -LiteralPath $conf -NewName "dxvk.conf.DXVK.OFF" -Force
        }

        $marker=Get-SR2DXVKMarkerPath
        if($marker -and (Test-Path $marker)){ Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue }

        Write-Log "----- SR2 DXVK Restore -----"
        Write-Log "[RESTORED] DXVK d3d9.dll disabled; Saints Row 2 will use native DirectX 9."
        Write-Log "[RESTORED] Previous dxgi.dll was restored if it existed."
        if($Reason){ Write-Log "[RESTORED] Reason: $Reason" }
        Write-Log "----------------------------"
        Update-SR2IsolationButton
    } catch {
        Write-Log "[ERROR] SR2 DXVK restore failed: $($_.Exception.Message)"
    }
}


function Test-PELargeAddressAware {
    param([string]$Path)
    try {
        $fs=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        $br=New-Object IO.BinaryReader($fs)
        try {
            $fs.Position=0x3C
            $peOffset=$br.ReadInt32()
            if($peOffset -lt 0 -or $peOffset -gt ($fs.Length-24)){ return $false }
            $fs.Position=$peOffset
            if($br.ReadUInt32() -ne 0x00004550){ return $false }
            [void]$br.ReadUInt16() # Machine
            [void]$br.ReadUInt16() # NumberOfSections
            [void]$br.ReadUInt32()
            [void]$br.ReadUInt32()
            [void]$br.ReadUInt32()
            [void]$br.ReadUInt16() # SizeOfOptionalHeader
            $characteristics=$br.ReadUInt16()
            return (($characteristics -band 0x0020) -ne 0)
        } finally {
            $br.Close(); $fs.Close()
        }
    } catch { return $false }
}

function Install-SR2DXVK24 {
    if(-not (Test-IsSaintsRow2) -or -not $script:GameExe -or -not $script:GameDir){ return $false }

    try {
        $arch=Get-PeArchitecture $script:GameExe
        if($arch -notmatch '32-bit|x86'){
            throw "Saints Row 2 was expected to be 32-bit, but the selected executable was detected as: $arch"
        }

        if(Test-PELargeAddressAware $script:GameExe){
            Write-Log "[OK] SR2_pc.exe is Large Address Aware (4 GB user-mode address space available on 64-bit Windows)."
        } else {
            Write-Log "[WARN] SR2_pc.exe is NOT marked Large Address Aware. DXVK adds address-space pressure and older SR2 DXVK setups commonly require an LAA/4 GB executable."
            $laaAnswer=[Windows.Forms.MessageBox]::Show(
                "SR2_pc.exe is not marked Large Address Aware.`r`n`r`nDXVK can increase 32-bit address-space usage, and SR2 may crash after loading without an LAA/4 GB executable.`r`n`r`nThis installer will NOT modify the game executable automatically.`r`n`r`nContinue with the compatibility test anyway?",
                "SR2 DXVK - LAA warning",
                [Windows.Forms.MessageBoxButtons]::YesNo,
                [Windows.Forms.MessageBoxIcon]::Warning
            )
            if($laaAnswer -ne [Windows.Forms.DialogResult]::Yes){ return $false }
        }

        $tools=Join-Path $script:AppRoot "Tools\SR2-DXVK"
        New-Item -ItemType Directory -Path $tools -Force | Out-Null
        $archive=Join-Path $tools "dxvk-2.4.tar.gz"
        $extract=Join-Path $tools "dxvk-2.4-extracted"
        $url="https://github.com/doitsujin/dxvk/releases/download/v2.4/dxvk-2.4.tar.gz"

        Write-Log "===== SR2 DXVK INSTALL / REPAIR ====="
        Write-Log "[INFO] Installing DXVK 2.4 x32 as the preferred Saints Row 2 compatibility layer."
        Write-Log "[INFO] This is D3D9 -> Vulkan, not the dgVoodoo D3D11 route."
        Write-Log "[IMPORTANT] Current dlss5-feed32 does not provide a released 32-bit Vulkan feed path; this test is compatibility-only."

        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        Write-Log "Downloading official DXVK 2.4..."
        Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing -Headers @{"User-Agent"="Universal-DLSS5-Installer"}
        Write-Log "[OK] DXVK 2.4 downloaded."

        Expand-SR2DXVKArchive -Archive $archive -Destination $extract
        $dxvkD3D9=Get-ChildItem -LiteralPath $extract -File -Recurse -Filter "d3d9.dll" -ErrorAction Stop |
            Where-Object { $_.FullName -match '(?i)[\\/]x32[\\/]d3d9\.dll$' } |
            Select-Object -First 1
        if(-not $dxvkD3D9){ throw "DXVK x32\\d3d9.dll was not found after extraction." }

        # Normalize remnants from the earlier isolation tests before swapping translators.
        Restore-SR2Isolation

        $liveD3D9=Join-Path $script:GameDir "d3d9.dll"
        if(Test-Path $liveD3D9){ Backup-IfPresent $liveD3D9 "sr2-dxvk" }

        # DXVK owns d3d9.dll. Local dxgi.dll is the previous D3D11 ReShade proxy,
        # so disable it for this Vulkan compatibility test.
        $dxgi=Join-Path $script:GameDir "dxgi.dll"
        $dxgiOff=Join-Path $script:GameDir "dxgi.dll.SR2_DXVK_OFF"
        if(Test-Path $dxgi){
            Backup-IfPresent $dxgi "sr2-dxvk"
            if(Test-Path $dxgiOff){ Remove-Item -LiteralPath $dxgiOff -Force -ErrorAction SilentlyContinue }
            Rename-Item -LiteralPath $dxgi -NewName "dxgi.dll.SR2_DXVK_OFF" -Force
            Write-Log "[OK] Disabled local ReShade dxgi.dll during the Vulkan compatibility test."
        }

        Copy-Item -LiteralPath $dxvkD3D9.FullName -Destination $liveD3D9 -Force
        Write-Log "[OK] Installed DXVK 2.4 x32 d3d9.dll."

        $conf=Join-Path $script:GameDir "dxvk.conf"
        if(Test-Path $conf){ Backup-IfPresent $conf "sr2-dxvk" }
        $confText=@"
# Universal DLSS5 Installer - SR2 DXVK compatibility test
# Conservative SR2 test settings; remove/restore with the program.
d3d9.maxFrameRate = 60
d3d9.presentInterval = 1
d3d9.numBackBuffers = 3
"@
        [IO.File]::WriteAllText($conf,$confText,[Text.UTF8Encoding]::new($false))
        Write-Log "[OK] Wrote conservative dxvk.conf (60 FPS cap, VSync interval 1, triple buffering)."

        # Move stale DXVK logs aside so runtime verification is unambiguous.
        Get-ChildItem -LiteralPath $script:GameDir -File -Filter "*d3d9.log" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $old=$_.FullName+".before-sr2-dxvk."+(Get-Date -Format "yyyyMMdd-HHmmss")+".bak"
                Move-Item -LiteralPath $_.FullName -Destination $old -Force
            } catch {}
        }

        $marker=Get-SR2DXVKMarkerPath
        $markerText="DXVK=2.4`r`nArchitecture=x32`r`nMode=SR2-Compatibility-Only`r`nInstalled="+(Get-Date -Format "o")
        [IO.File]::WriteAllText($marker,$markerText,[Text.UTF8Encoding]::new($false))

        Write-Log "[READY] Saints Row 2 DXVK compatibility path prepared."
        Write-Log "[DLSS5 BLOCKED] Do not enable DLSS5 Feed/Lumenite for this test; released feed32 Vulkan transport is not available yet."
        Write-Log "================================="
        Update-SR2IsolationButton
        return $true
    } catch {
        Write-Log "[ERROR] SR2 DXVK install failed: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show(
            "SR2 DXVK installation failed.`r`n`r`n$($_.Exception.Message)",
            "SR2 DXVK",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $false
    }
}

function Start-SR2DXVKTest {
    if(-not (Test-IsSaintsRow2) -or -not $script:GameExe -or -not $script:GameDir){ return }

    $already=Get-Process -Name "SR2_pc" -ErrorAction SilentlyContinue | Select-Object -First 1
    if($already){
        [Windows.Forms.MessageBox]::Show("Saints Row 2 is already running. Close it before starting the DXVK test.","SR2 DXVK") | Out-Null
        return
    }

    $answer=[Windows.Forms.MessageBox]::Show(
        "Install DXVK 2.4 x32 and launch Saints Row 2?`r`n`r`nThis is an experimental translator compatibility test only. It will replace the active d3d9.dll, temporarily disable local ReShade dxgi.dll, cap the test at 60 FPS, and monitor Juiced crash logs.`r`n`r`nCurrent DLSS5 Feed 32-bit Vulkan support is not released, so Neural Rendering will NOT be enabled in this mode.`r`n`r`nContinue?",
        "SR2 DXVK compatibility",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if($answer -ne [Windows.Forms.DialogResult]::Yes){ return }

    if(-not (Install-SR2DXVK24)){ return }

    try {
        $script:SR2DXVKTestStart=Get-Date
        $script:SR2DXVKExitSeen=$null
        Write-Log "===== SR2 DXVK LAUNCH TEST ====="
        Write-Log "[TEST] Launching Saints Row 2 through DXVK 2.4 x32."
        Write-Log "[WATCH] Reach the menu, then actual gameplay. Leave it running for at least 60 seconds if stable."
        Write-Log "[WATCH] Any new Juiced SR2_pc.exe.*.log will trigger automatic rollback to native D3D9."

        $proc=Start-Process -FilePath $script:GameExe -WorkingDirectory $script:GameDir -PassThru
        $script:SR2DXVKTestProcessId=$proc.Id
        $script:SR2DXVKTestActive=$true
        if($script:SR2DXVKTimer){ $script:SR2DXVKTimer.Start() }
        Write-Log "[LAUNCHED] SR2_pc.exe PID $($proc.Id)."
    } catch {
        $script:SR2DXVKTestActive=$false
        Write-Log "[ERROR] Could not launch SR2 DXVK: $($_.Exception.Message)"
        Restore-SR2NativeD3D9FromDXVK -Reason "Launch failed."
    }
}

# Override the older dgVoodoo compatibility dialog in this experimental branch.
function Show-SR2IsolationDialog {
    if(-not (Test-IsSaintsRow2)){ return }

    $dlg=New-Object Windows.Forms.Form
    $dlg.Text="Saints Row 2 - DXVK Compatibility"
    $dlg.StartPosition="CenterParent"
    $dlg.FormBorderStyle="FixedDialog"
    $dlg.MaximizeBox=$false
    $dlg.MinimizeBox=$false
    $dlg.Size=New-Object Drawing.Size(590,500)
    $dlg.BackColor=[Drawing.Color]::FromArgb(15,18,24)
    $dlg.ForeColor=[Drawing.Color]::FromArgb(240,244,248)

    $title=New-Object Windows.Forms.Label
    $title.Text="Saints Row 2 DXVK compatibility"
    $title.Font=New-Object Drawing.Font("Segoe UI Semibold",15)
    $title.AutoSize=$true
    $title.Location=New-Object Drawing.Point(24,18)
    $dlg.Controls.Add($title)

    $info=New-Object Windows.Forms.Label
    $info.Text="Saints Row 2 + Juiced was stable through DXVK while dgVoodoo repeatedly crashed at SR2_pc.exe +0x5EE9F2. DXVK 2.4 x32 is now the preferred Saints Row 2 compatibility layer: DirectX 9 -> Vulkan. DLSS5 Neural Rendering remains a separate capability check."
    $info.Font=New-Object Drawing.Font("Segoe UI",9.25)
    $info.Size=New-Object Drawing.Size(530,96)
    $info.Location=New-Object Drawing.Point(26,54)
    $dlg.Controls.Add($info)

    $state=New-Object Windows.Forms.Label
    $state.Font=New-Object Drawing.Font("Segoe UI Semibold",9.5)
    $state.AutoSize=$false
    $state.Size=New-Object Drawing.Size(530,38)
    $state.Location=New-Object Drawing.Point(26,160)
    $state.Text=if(Test-SR2DXVKMode){"Current state: DXVK test mode is installed."}else{"Current state: native/dgVoodoo test mode; DXVK marker not present."}
    $dlg.Controls.Add($state)

    $test=New-Object Windows.Forms.Button
    $test.Text="Install/Repair DXVK 2.4 x32"
    $test.Size=New-Object Drawing.Size(530,44)
    $test.Location=New-Object Drawing.Point(26,208)
    $test.FlatStyle="Flat"
    $test.BackColor=[Drawing.Color]::FromArgb(29,35,47)
    $test.ForeColor=[Drawing.Color]::FromArgb(240,244,248)
    $test.Add_Click({$dlg.Close();Install-SR2DXVK24 | Out-Null; Update-SR2IsolationButton})
    $dlg.Controls.Add($test)

    $verify=New-Object Windows.Forms.Button
    $verify.Text="Verify DXVK / Vulkan"
    $verify.Size=New-Object Drawing.Size(530,40)
    $verify.Location=New-Object Drawing.Point(26,266)
    $verify.FlatStyle="Flat"
    $verify.BackColor=[Drawing.Color]::FromArgb(29,35,47)
    $verify.ForeColor=[Drawing.Color]::FromArgb(240,244,248)
    $verify.Add_Click({$dlg.Close();Verify-Install})
    $dlg.Controls.Add($verify)

    $restore=New-Object Windows.Forms.Button
    $restore.Text="Restore native D3D9"
    $restore.Size=New-Object Drawing.Size(530,40)
    $restore.Location=New-Object Drawing.Point(26,320)
    $restore.FlatStyle="Flat"
    $restore.BackColor=[Drawing.Color]::FromArgb(29,35,47)
    $restore.ForeColor=[Drawing.Color]::FromArgb(240,244,248)
    $restore.Add_Click({$dlg.Close();Restore-SR2NativeD3D9FromDXVK -Reason "Manual restore requested."})
    $dlg.Controls.Add($restore)

    $note=New-Object Windows.Forms.Label
    $note.Text="Juiced is preserved. While DXVK is active, the old local DXGI ReShade proxy is kept out of the rendering path. dgVoodoo files may remain in the folder, but dgVoodoo is inactive because DXVK owns d3d9.dll."
    $note.Font=New-Object Drawing.Font("Segoe UI",8.75)
    $note.Size=New-Object Drawing.Size(530,58)
    $note.Location=New-Object Drawing.Point(26,376)
    $dlg.Controls.Add($note)

    $dlg.ShowDialog($form)|Out-Null
    $dlg.Dispose()
}

# Override the older SR2 button state logic for the DXVK branch.
function Update-SR2IsolationButton {
    try {
        if(-not $sr2IsolationButton){ return }
        $isSR2=Test-IsSaintsRow2
        $sr2IsolationButton.Visible=$isSR2
        $sr2IsolationButton.Enabled=($isSR2 -and $script:GameExe -and (Test-Path $script:GameExe))
        if($isSR2 -and (Test-SR2DXVKMode)){
            $sr2IsolationButton.Text="DLSS5 Neural Rendering"
        } else {
            $sr2IsolationButton.Text="DLSS5 Neural Rendering"
        }
        if($isSR2 -and $dgVoodooButton){
            $dgVoodooButton.Visible=$false
            $dgVoodooButton.Enabled=$false
        }
        Update-ActionLayout
    } catch {}
}

function Test-ReShadeNeedsRepair {
    if((Get-ReShadeRuntimeState) -ne "Loaded"){ return $false }
    if(-not $script:GameDir){ return $false }
    $log=Join-Path $script:GameDir "ReShade.log"
    try {
        $s=[IO.File]::ReadAllText($log)
        return ($s -match '(?i)limited add-on functionality|add-ons were not loaded because this build')
    } catch { return $false }
}

function Update-RepairAvailability {
    if(-not $repairButton){ return }
    try {
        $isDX9 = ($apiCombo.Text -match 'DirectX\s*9|D3D9')
        if($isDX9 -and -not (Test-DX9TranslationReady)){
            $repairButton.Enabled=$false
            $repairButton.Text="Repair ReShade (DX9 wrapper missing)"
            return
        }
        $repairButton.Enabled=$true
        $repairButton.Text="Repair ReShade"
    } catch {}
}

function Verify-Install {
    if(-not $script:GameExe){
        [Windows.Forms.MessageBox]::Show("Select a game first.","DLSS 5 Installer","OK","Information")|Out-Null
        return
    }

    $dir=$script:GameDir
    $api=[string]$apiCombo.SelectedItem
    Write-Log "----- Verification -----"

    foreach($f in @("ReShade.ini","feedkit.install.json","reshade-shaders")) {
        if(Test-Path (Join-Path $dir $f)){Write-Log "[OK] $f"}else{Write-Log "[CHECK] $f not found"}
    }

    if((Test-IsSaintsRow2) -and (Test-SR2DXVKMode)){
        
    if((Test-IsSaintsRow2) -and (Test-SR2Vulkan32Installed)){
        $v32=Get-SR2Vulkan32Status
        Write-Log "----- SR2 Vulkan32 Neural Rendering -----"
        if($v32.ReShadeVulkan){ Write-Log "[OK] ReShade is running on Vulkan." } else { Write-Log "[WAIT] ReShade Vulkan runtime not confirmed yet." }
        if($v32.AddonRegistered){ Write-Log "[OK] dlss5-feed.addon32 registered." } else { Write-Log "[BLOCKED] dlss5-feed.addon32 was not registered by ReShade." }
        if($v32.FeedShaderCompiled){ Write-Log "[OK] DLSS5_Feed.fx compiled." } else { Write-Log "[BLOCKED] DLSS5_Feed.fx was not compiled." }
        if($v32.FeedVersion){ Write-Log "[INFO] Feeder version: $($v32.FeedVersion)" }
        if($v32.SettingsUIExpected){ Write-Log "[SETTINGS] Use ReShade Add-ons -> DLSS 5 Feed; click APPLY for host NR settings." }
        if($v32.InteropResolved){ Write-Log "[OK] Vulkan external-memory/semaphore interop resolved." } else { Write-Log "[WAIT] Vulkan interop is not confirmed." }
        if($v32.SharedSetReady){ Write-Log "[OK] shared set ready (Vulkan)." } else { Write-Log "[WAIT] Vulkan shared set has not been built." }
        if($v32.VulkanFrames){ Write-Log "[OK] Frames are being delivered through the Vulkan32 transport." } else { Write-Log "[WAIT] No delivered Vulkan frames detected yet." }
        if($v32.HostFeature){ Write-Log "[OK] host64 reports feature 18 created." } else { Write-Log "[WAIT] host64 feature 18 not confirmed." }
        if($v32.HostInline){ Write-Log "[SUCCESS] host64 inline feature 18 evaluation succeeded." } else { Write-Log "[WAIT] Neural Rendering evaluation not confirmed." }
        if($v32.VulkanFrames -and $v32.HostInline){
            Write-Log "[SUCCESS] DLSS5 Neural Rendering is active end-to-end in Saints Row 2 over DXVK/Vulkan."
        } elseif($v32.VulkanFrames){
            Write-Log "[TRANSPORT PASS] Vulkan32 transport works; switch to mode=2 to test Neural Rendering."
        }
        Write-Log "------------------------------------------"
    }

Write-Log "----- Saints Row 2 Renderer Status -----"
        $d3d9=Join-Path $dir "d3d9.dll"
        $dxgiOff=Join-Path $dir "dxgi.dll.SR2_DXVK_OFF"
        $conf=Join-Path $dir "dxvk.conf"
        if(Test-Path $d3d9){ Write-Log "[FILES OK] DXVK x32 d3d9.dll is installed." } else { Write-Log "[FAILED] DXVK d3d9.dll is missing." }
        if(Test-Path $conf){ Write-Log "[FILES OK] dxvk.conf is installed." }
        if(Test-Path $dxgiOff){ Write-Log "[OK] Previous ReShade dxgi.dll is safely disabled during the Vulkan test." }

        $dxvkLog=Get-SR2DXVKRuntimeLog
        if($dxvkLog){
            Write-Log "[ACTIVE] DXVK/Vulkan runtime evidence detected: $(Split-Path $dxvkLog -Leaf)"
            Write-Log "[PASS] SR2 has initialized through the experimental D3D9 -> Vulkan translator."
        } else {
            Write-Log "[PENDING] No DXVK runtime log has been confirmed yet. Launch Saints Row 2, reach gameplay, close the game, then verify again."
        }

        Write-Log "[DLSS5 STATUS] DXVK/Vulkan is the stable SR2 renderer path. Neural Rendering is checked separately and is not assumed active."
        Write-Log "[INFO] Do not enable Lumenite or DLSS 5 Feed in this mode."
        Write-Log "----------------------------------------"
        Update-SR2IsolationButton
        Copy-GameLogsToInstaller
        return
    }

    if($api -in @("DirectX 11","DirectX 12")){
        if(Test-Path (Join-Path $dir "dxgi.dll")){Write-Log "[OK] dxgi.dll"}else{Write-Log "[CHECK] dxgi.dll not found"}
    }

    if($api -eq "DirectX 9"){
        if(Test-Path (Join-Path $dir "d3d9.dll")){Write-Log "[OK] d3d9.dll (DX9 wrapper)"}else{Write-Log "[ERROR] d3d9.dll (dgVoodoo2 DX9 wrapper) is missing. DX9 translation is incomplete; DLSS5 cannot use the translated DX11 path until this is fixed."}
        if(Test-Path (Join-Path $dir "dxgi.dll")){if($apiCombo.Text -match 'DirectX\s*9|D3D9'){
            foreach($dg in @("dgVoodoo.conf","dgVoodooCpl.exe")){
                if(Test-Path (Join-Path $script:GameDir $dg)){
                    Write-Log "[OK] $dg"
                } else {
                    Write-Log "[CHECK] $dg not found"
                }
            }
        }
        Write-Log "[OK] dxgi.dll (ReShade on translated DX11 path)"}
    }

    if($script:Architecture -like "32-bit*"){
        if(Test-Path (Join-Path $dir "host64")){Write-Log "[OK] host64"
        if($apiCombo.Text -match 'DirectX\s*9|D3D9'){
            $addon32=Join-Path $script:GameDir "dlss5-feed.addon32"
            if(Test-Path $addon32){ Write-Log "[OK] dlss5-feed.addon32" }
            else { Write-Log "[ERROR] dlss5-feed.addon32 is missing for this 32-bit DX9 game." }

            $hostExe=Join-Path $script:GameDir "host64\dlss5-feed-host64.exe"
            if(Test-Path $hostExe){ Write-Log "[OK] host64\dlss5-feed-host64.exe" }
            else { Write-Log "[ERROR] host64\dlss5-feed-host64.exe is missing." }

            foreach($hostFile in @("renodx-dlss5.addon64","nvngx_dlssnr.dll","nvngx_dlss.dll")){
                $hf=Join-Path $script:GameDir ("host64\"+$hostFile)
                if(Test-Path $hf){ Write-Log "[OK] host64\$hostFile" }
                else { Write-Log "[ERROR] host64\$hostFile is missing." }
            }
        }}else{Write-Log "[CHECK] host64 not found"}
    }

    $feedFx = Join-Path $dir "reshade-shaders\Shaders\DLSS5_Feed.fx"
    if(Test-Path $feedFx){
        Write-Log "[OK] DLSS5_Feed.fx"
    }else{
        Write-Log "[REPAIR NEEDED] DLSS5_Feed.fx is missing from reshade-shaders\Shaders."
    }

    $bridgeLog = Join-Path $dir "dlss5-dx11-bridge.log"
    if(Test-Path $bridgeLog){
        $btxt = Get-Content $bridgeLog -Raw -ErrorAction SilentlyContinue
        if($btxt -match '(?i)stopped|error|failed'){
            Write-Log "[CHECK] DX11 Bridge log contains an error/stopped state."
        }else{
            Write-Log "[OK] DX11 Bridge log has no obvious stop/error."
        }
    }

    $reshadeLog=Join-Path $dir "ReShade.log"
    if(Test-Path $reshadeLog){
        $txt=Get-Content $reshadeLog -Raw -ErrorAction SilentlyContinue
        if($txt -match '(?i)limited add-on functionality|some add-ons were not loaded'){
            Write-Log "[REPAIR NEEDED] ReShade.log reports limited add-on support."
        } else {
            $rsState=Get-ReShadeRuntimeState
    switch($rsState){
        "Loaded" {
            if(Test-ReShadeNeedsRepair){
                Write-Log "[ERROR] ReShade loaded, but the log shows limited add-on functionality. Full Add-on Support is required."
            } else {
                Write-Log "[OK] ReShade loaded at runtime and no limited-add-on warning was detected."
            }
        }
        "NotLoaded" {
            Write-Log "[ERROR] ReShade did not load into the game. The current ReShade.log is only the fallback troubleshooting placeholder."
            if($apiCombo.Text -match 'DirectX\s*9|D3D9'){
                Write-Log "[ERROR] DX9 injection chain failed before DLSS5 could attach. Verify the real rendering EXE, dgVoodoo2 d3d9.dll beside it, and 32-bit ReShade dxgi.dll."
            }
        }
        "Missing"   { Write-Log "[CHECK] ReShade.log not found. Launch the game once, close it, then verify again." }
        "Unreadable"{ Write-Log "[CHECK] ReShade.log exists but could not be read." }
        default     { Write-Log "[CHECK] ReShade.log exists, but no confirmed ReShade runtime initialization was detected." }
    }
        }
    } else {
        Write-Log "[INFO] No ReShade.log yet. Launch the game once, then Verify again."
    }

    if($apiCombo.Text -match 'DirectX\s*9|D3D9'){
        $ev=Get-DX9RuntimeEvidence
        Write-Log "----- DX9 Runtime Status -----"

        if($ev.ReShadeLoaded){
            $detail=""
            if($ev.ReShadeVersion){ $detail+=" $($ev.ReShadeVersion)" }
            if($ev.ReShadeArch){ $detail+=" ($($ev.ReShadeArch))" }
            Write-Log "[ACTIVE] ReShade runtime$detail"
        } else {
            Write-Log "[WAIT] ReShade runtime has not been confirmed from the current log."
        }

        if($ev.D3D11Translated){
            Write-Log "[ACTIVE] dgVoodoo2 DX9 -> D3D11 translation detected."
        } elseif(Test-DX9TranslationReady){
            Write-Log "[FILES OK] dgVoodoo2 wrapper is installed; launch the game to confirm DX9 -> D3D11 translation."
        } else {
            Write-Log "[FAILED] dgVoodoo2 DX9 wrapper is missing."
        }

        if($ev.FeedAddonRegistered){
            $feedDetail=if($ev.FeedAddonVersion){" v$($ev.FeedAddonVersion)"}else{""}
            Write-Log "[ACTIVE] DLSS 5 Feed add-on registered$feedDetail."
        } elseif(Test-Path (Join-Path $script:GameDir "dlss5-feed.addon32")){
            Write-Log "[FILES OK] dlss5-feed.addon32 is installed; runtime registration not yet confirmed."
        } else {
            Write-Log "[FAILED] dlss5-feed.addon32 is missing."
        }

        if($ev.FeedShaderCompiled){
            Write-Log "[ACTIVE] DLSS5_Feed.fx compiled successfully."
        } elseif(Test-Path (Join-Path $script:GameDir "reshade-shaders\Shaders\DLSS5_Feed.fx")){
            Write-Log "[FILES OK] DLSS5_Feed.fx is installed; runtime compilation not yet confirmed."
        }

        if($ev.RealSwapChain){
            Write-Log "[ACTIVE] Real game swap chain detected: $($ev.Resolution)."
        }

        $hostExe=Join-Path $script:GameDir "host64\dlss5-feed-host64.exe"
        if(Test-Path $hostExe){
            Write-Log "[FILES OK] 64-bit DLSS host is installed."
        }

        $feedState=Get-DLSS5FeedState
        Write-Log "----- DLSS5 Neural Rendering -----"
        if($feedState.LogPresent){
            if($feedState.Attached){
                $fv=if($feedState.FeedVersion){" v$($feedState.FeedVersion)"}else{""}
                Write-Log "[ACTIVE] DLSS5 Feed runtime attached$fv."
            }

            if($feedState.TechniqueMissing){
                Write-Log "[BLOCKED] DLSS 5 Feed technique was missing when the effect runtime initialized."
            }
            if($feedState.MVMissing){
                Write-Log "[BLOCKED] DLSS5_MV motion-vector texture is missing."
            }
            if($feedState.DepthMissing){
                Write-Log "[BLOCKED] DLSS5_Depth texture is missing."
            }
            if($feedState.ProviderMissing){
                $expected=if($feedState.ProviderExpected){" ($($feedState.ProviderExpected))"}else{""}
                Write-Log "[BLOCKED] Configured motion-vector provider$expected was not active/installed."
            }

            if($feedState.TechniqueMissing -or $feedState.MVMissing -or $feedState.DepthMissing -or $feedState.ProviderMissing){
                Write-Log "[SAFE TEST] Do not auto-enable both effects on launch in older DX9 games."
                Write-Log "[ACTION] Click 'Fix DLSS inputs' to prepare the provider in SAFE STAGE mode."
                Write-Log "[ACTION] Launch first, then enable LUMENITE: Kernel 2.0 manually; enable DLSS 5 Feed only after stability is confirmed."
            } elseif($feedState.ProviderEnabled){
                Write-Log "[ACTIVE] Motion-vector provider is enabled."
            }

            if($feedState.FeatureReady){
                Write-Log "[ACTIVE] DLSS DLAA feature is ready."
            }
            if($feedState.FramesDelivered){
                Write-Log "[ACTIVE] DLSS5 frames are being delivered (latest logged frame $($feedState.DeliveredFrame))."
            }
        } else {
            Write-Log "[WAIT] dlss5-feed.log has not been created yet."
        }

        if($feedState.HostLogPresent){
            Write-Log "[ACTIVE] 64-bit feeder host log exists."
        }
        if($feedState.HostFeatureCreated){
            Write-Log "[ACTIVE] Neural Rendering host created DLSS feature 18."
        }
        if($feedState.HostInlineSucceeded){
            Write-Log "[NR ACTIVE] Inline Neural Rendering evaluation succeeded."
        }

        if($ev.ReShadeLoaded -and $ev.D3D11Translated -and $ev.FeedAddonRegistered -and $ev.FeedShaderCompiled){
            Write-Log "[DX9 READY] Translation + ReShade + DLSS Feed runtime path is active."
        }
        if($feedState.FeatureReady -and $feedState.FramesDelivered -and $feedState.HostInlineSucceeded){
            Write-Log "[SUCCESS] DLSS5 Neural Rendering is active end-to-end."
        } elseif($feedState.TechniqueMissing -or $feedState.MVMissing -or $feedState.DepthMissing -or $feedState.ProviderMissing){
            Write-Log "[NR BLOCKED] Neural Rendering cannot start until the Feed technique, motion vectors, and depth are available."
        } else {
            Write-Log "[NEXT] Verify host64\dlss5-feed-host.log and host64\ReShade.log for the final NR stage."
        }
        Write-Log "----------------------------------"
        Write-Log "------------------------------"
    }

    $fatalDX9=$false
    if($apiCombo.Text -match 'DirectX\s*9|D3D9'){
        if(-not (Test-DX9TranslationReady)){ $fatalDX9=$true }
        if((Get-ReShadeRuntimeState) -eq "NotLoaded"){ $fatalDX9=$true }
        if(-not (Test-Path (Join-Path $script:GameDir "dlss5-feed.addon32"))){ $fatalDX9=$true }
        if(-not (Test-Path (Join-Path $script:GameDir "host64\dlss5-feed-host64.exe"))){ $fatalDX9=$true }

        $ev=Get-DX9RuntimeEvidence
        if($fatalDX9){
            Write-Log "[FAILED] DX9 runtime chain is incomplete. DLSS5 is not attached."
        } elseif((Get-DLSS5FeedState).TechniqueMissing -or (Get-DLSS5FeedState).MVMissing -or (Get-DLSS5FeedState).DepthMissing -or (Get-DLSS5FeedState).ProviderMissing){
            Write-Log "[BLOCKED] DX9 translation is active, but DLSS5 feed inputs are incomplete. Use 'Fix DLSS inputs'."
        } elseif((Get-DLSS5FeedState).HostInlineSucceeded -and (Get-DLSS5FeedState).FramesDelivered){
            Write-Log "[SUCCESS] DX9 DLSS5 Neural Rendering is active."
        } elseif($ev.ReShadeLoaded -and $ev.D3D11Translated -and $ev.FeedAddonRegistered){
            Write-Log "[READY] DX9 translation and DLSS5 Feed runtime are active; waiting for full host64/NR confirmation."
        } else {
            Write-Log "[PENDING] DX9 files are present. Launch the game once, close it, then Verify files to confirm runtime attachment."
        }
    }

    Update-RepairAvailability
    Write-Log "------------------------"
    Copy-GameLogsToInstaller
}

function Repair-ReShade {
    if(-not $script:GameExe){
        [Windows.Forms.MessageBox]::Show("Select a game first.","DLSS 5 Installer","OK","Information")|Out-Null
        return
    }

    if(Test-IsSaintsRow2){
        Write-Log "[INFO] Local DXGI ReShade repair is disabled while SR2 uses DXVK."
        [Windows.Forms.MessageBox]::Show("ReShade dxgi.dll is intentionally disabled while the SR2 DXVK is active. Restore native D3D9 before using the existing DXGI ReShade repair path.","SR2 DXVK")|Out-Null
        return
    }

    $api=[string]$apiCombo.SelectedItem
    if($api -eq "DirectX 10"){
        [Windows.Forms.MessageBox]::Show("Native DirectX 10 is not supported by this DLSS5 workflow.","DX10","OK","Warning")|Out-Null
        return
    }

    $answer=[Windows.Forms.MessageBox]::Show(
        "This repair reinstalls the official ReShade Full Add-on build.`r`n`r`nUse it only if Verify reports limited add-on support or ReShade is broken.`r`n`r`nContinue?",
        "Repair ReShade","YesNo","Question")
    if($answer -ne [Windows.Forms.DialogResult]::Yes){return}

    try{
        $tools=Join-Path $script:GameDir "_DLSS5_Tools"
        New-Item -ItemType Directory -Path $tools -Force|Out-Null

        $setup=Join-Path $tools "ReShade_Setup_6.8.0_Addon.exe"
        $url="https://reshade.me/downloads/ReShade_Setup_6.8.0_Addon.exe"

        $proxy=Join-Path $script:GameDir "dxgi.dll"
        $backup=Join-Path $script:GameDir ("dxgi.dll.before-repair."+((Get-Date).ToString("yyyyMMdd-HHmmss"))+".bak")
        if(Test-Path $proxy){
            Copy-Item $proxy $backup -Force
            Write-Log "[BACKUP] Existing dxgi.dll saved as $(Split-Path -Leaf $backup)"
        }

        Write-Log "Downloading ReShade Full Add-on Support..."
        Download-File $url $setup

        if($apiCombo.Text -match 'DirectX\s*9|D3D9'){
            Write-Log "Running 32-bit DX9 translated-path ReShade repair (ReShade remains dxgi.dll; dgVoodoo2 owns d3d9.dll)..."
        } else {
            Write-Log "Running ReShade repair for $($apiCombo.Text)..."
        }
        $p=Start-Process $setup -ArgumentList @("`"$($script:GameExe)`"","--api","dxgi","--headless") -Wait -PassThru
        if($p.ExitCode -ne 0){throw "ReShade setup returned exit code $($p.ExitCode)."}
        Write-Log "[OK] ReShade repair completed."
        Copy-GameLogsToInstaller -Quiet
        Verify-Install
    }catch{
        Write-Log "[ERROR] $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,"ReShade repair error","OK","Error")|Out-Null
    }
}

function Install-DLSS5 {
    if(-not $script:GameExe){
        [Windows.Forms.MessageBox]::Show("Select a game executable first.","DLSS 5 Installer","OK","Warning")|Out-Null
        return
    }
    if(Test-IsSaintsRow2){
        Write-Log "[INFO] The legacy SR2 DLSS5/dgVoodoo installation path is disabled. SR2 now uses DXVK as its stable renderer path."
        [Windows.Forms.MessageBox]::Show("This SR2 DXVK mode is a D3D9 -> Vulkan compatibility test only. The current upstream main branch now includes the 32-bit Vulkan/DXVK transport; use the Vulkan32 NR Beta action.","SR2 DXVK")|Out-Null
        return
    }

    $api=[string]$apiCombo.SelectedItem
    if([string]::IsNullOrWhiteSpace($api) -or $api -eq "Auto detect"){
        [Windows.Forms.MessageBox]::Show("Choose a renderer first.","DLSS 5 Installer","OK","Warning")|Out-Null
        return
    }

    if($api -eq "DirectX 10"){
        [Windows.Forms.MessageBox]::Show(
            "Current DLSS5-Feeder does not support native DirectX 10.`r`n`r`nIf this game offers DX11, select DirectX 11 instead.",
            "DirectX 10 not supported","OK","Warning")|Out-Null
        Write-Log "Install blocked: native DX10 is unsupported."
        return
    }

    if(-not (Require-Admin)){
        $a=[Windows.Forms.MessageBox]::Show(
            "Administrator rights are recommended for Program Files game folders.`r`n`r`nRestart as Administrator?",
            "Administrator rights","YesNo","Question")
        if($a -eq [Windows.Forms.DialogResult]::Yes){
            try {
                if(-not [string]::IsNullOrWhiteSpace($PSCommandPath)){
                    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-STA","-WindowStyle","Hidden","-File","`"$PSCommandPath`"")
                } else {
                    $selfExe=[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
                    if([string]::IsNullOrWhiteSpace($selfExe)){ throw "Could not resolve the running application path." }
                    Start-Process -FilePath $selfExe -Verb RunAs
                }
                $form.Close()
                return
            } catch {
                [Windows.Forms.MessageBox]::Show("Could not restart as Administrator.`r`n`r`n$($_.Exception.Message)","Administrator rights","OK","Error") | Out-Null
                return
            }
        }
    }

    if(Test-AntiCheat $script:GameDir){
        $a=[Windows.Forms.MessageBox]::Show(
            "An anti-cheat component appears to be present.`r`n`r`nReShade Full Add-on and DLSS5-Feeder may be blocked and are intended for single-player use.`r`n`r`nContinue?",
            "Anti-cheat warning","YesNo","Warning")
        if($a -ne [Windows.Forms.DialogResult]::Yes){return}
    }

    if($script:Profile -eq "Possible launcher"){
        $a=[Windows.Forms.MessageBox]::Show(
            "This EXE looks like a launcher. DLSS/ReShade normally needs the real rendering EXE.`r`n`r`nContinue anyway?",
            "Possible launcher","YesNo","Warning")
        if($a -ne [Windows.Forms.DialogResult]::Yes){return}
    }

    try{
        $installButton.Enabled=$false
        $tools=Join-Path $script:GameDir "_DLSS5_Tools"
        New-Item -ItemType Directory -Path $tools -Force|Out-Null
        $feedkit=Join-Path $tools "FeedKit.exe"

        Write-Log "Downloading latest FeedKit..."
        $tag=Get-LatestFeedKit $feedkit
        Write-Log "[OK] FeedKit $tag downloaded."

        if($api -eq "DirectX 9"){
            Write-Log "DX9 selected: use FeedKit's D3D9/dgVoodoo2 path."
        }elseif($api -eq "DirectX 11"){
            Write-Log "DX11 selected: native DXGI path."
        }elseif($api -eq "DirectX 12"){
            Write-Log "DX12 selected: native DXGI path."
        }

        [Windows.Forms.MessageBox]::Show(
            "FeedKit will open next.`r`n`r`nTarget:`r`n$($script:GameExe)`r`n`r`nInstall using the matching renderer option, then close FeedKit.",
            "FeedKit","OK","Information")|Out-Null

        Write-Log "Launching FeedKit..."
        Start-Process $feedkit -Wait
        Write-Log "FeedKit closed."

        $a=[Windows.Forms.MessageBox]::Show("Did FeedKit finish successfully?","FeedKit","YesNo","Question")
        if($a -ne [Windows.Forms.DialogResult]::Yes){
            Write-Log "Install workflow stopped."
            return
        }

        # IMPORTANT: v2 does NOT automatically reinstall ReShade.
        Write-Log "[OK] FeedKit installation acknowledged."
        Write-Log "Running verification. ReShade will only be repaired if you explicitly click Repair ReShade."
        Verify-Install

        [Windows.Forms.MessageBox]::Show(
            "FeedKit installation finished.`r`n`r`nLaunch the game once, then return and click Verify Files.`r`n`r`nOnly use Repair ReShade if Verify reports limited add-on support.",
            "Finished","OK","Information")|Out-Null
    }catch{
        Write-Log "[ERROR] $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,"Installation error","OK","Error")|Out-Null
    }finally{
        $installButton.Enabled=$true
    }
}


# ---------- Automatic game log collection ----------
$script:InstallerRoot = $script:AppRoot
$script:CollectedLogsRoot = Join-Path -Path $script:InstallerRoot -ChildPath "Logs"

function Get-LogSafeGameName {
    if($script:GameExe){
        $n=[IO.Path]::GetFileNameWithoutExtension($script:GameExe)
        if($n){ return ($n -replace '[<>:"/\\|?*]','_') }
    }
    return "SelectedGame"
}

function Copy-GameLogsToInstaller {
    param([switch]$Quiet)

    if(-not $script:GameDir -or -not (Test-Path $script:GameDir)){ return }

    try {
        if(-not (Test-Path $script:CollectedLogsRoot)){
            New-Item -ItemType Directory -Path $script:CollectedLogsRoot -Force | Out-Null
        }

        $gameLogDir=Join-Path $script:CollectedLogsRoot (Get-LogSafeGameName)
        if(-not (Test-Path $gameLogDir)){
            New-Item -ItemType Directory -Path $gameLogDir -Force | Out-Null
        }

        # Collect the logs that matter most for ReShade / DLSS5 troubleshooting.
        $patterns=@(
            "ReShade.log",
            "ReShade.log1",
            "ReShade.log2",
            "dlss5-dx11-bridge.log",
            "dlss5-feed.log",
            "renodx*.log",
            "nvngx*.log",
            "*d3d9.log",
            "SR2_pc.exe.*.log"
        )

        $copied=0
        foreach($pattern in $patterns){
            Get-ChildItem -LiteralPath $script:GameDir -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
                $dest=Join-Path $gameLogDir $_.Name
                try {
                    # Read+write rather than Copy-Item so an actively-open log is less likely
                    # to fail because of sharing flags.
                    $bytes=[IO.File]::ReadAllBytes($_.FullName)
                    [IO.File]::WriteAllBytes($dest,$bytes)
                    $copied++
                } catch {}
            }
        }

        # Unreal games often place logs below the actual executable folder.
        foreach($sub in @("Saved\Logs","logs","Logs")){
            $subDir=Join-Path $script:GameDir $sub
            if(Test-Path $subDir){
                Get-ChildItem -LiteralPath $subDir -Filter *.log -File -ErrorAction SilentlyContinue |
                    Where-Object {$_.Name -match '(?i)reshade|dlss|renodx|ngx|bridge'} |
                    ForEach-Object {
                        $dest=Join-Path $gameLogDir $_.Name
                        try {
                            $bytes=[IO.File]::ReadAllBytes($_.FullName)
                            [IO.File]::WriteAllBytes($dest,$bytes)
                            $copied++
                        } catch {}
                    }
            }
        }

        if(-not $Quiet -and $copied -gt 0){
            Write-Log "Collected $copied game log file(s) to: $gameLogDir"
        }
    } catch {
        if(-not $Quiet){ Write-Log "[CHECK] Log collection failed: $($_.Exception.Message)" }
    }
}

function Open-CollectedLogs {
    try {
        if(-not (Test-Path $script:CollectedLogsRoot)){
            New-Item -ItemType Directory -Path $script:CollectedLogsRoot -Force | Out-Null
        }
        Start-Process explorer.exe $script:CollectedLogsRoot
    } catch {}
}


# ---------- Game artwork ----------
function Clear-GameArtwork {
    try {
        if($gameArtBox -and $gameArtBox.Image){
            $old=$gameArtBox.Image
            $gameArtBox.Image=$null
            $old.Dispose()
        }
    } catch {}
}

function Get-GameArtwork {
    if(-not $script:GameExe -or -not (Test-Path $script:GameExe)){return $null}
    try {
        $dir=Split-Path -Parent $script:GameExe
        $base=[IO.Path]::GetFileNameWithoutExtension($script:GameExe)
        foreach($n in @("$base.png","$base.jpg","cover.png","cover.jpg","header.png","header.jpg","banner.png","banner.jpg","game.png","game.jpg")){
            $f=Join-Path $dir $n
            if(Test-Path $f){
                $bytes=[IO.File]::ReadAllBytes($f)
                $ms=New-Object IO.MemoryStream(,$bytes)
                $img=[Drawing.Image]::FromStream($ms)
                $bmp=New-Object Drawing.Bitmap($img)
                $img.Dispose();$ms.Dispose()
                return $bmp
            }
        }
    } catch {}
    try {
        $ico=[Drawing.Icon]::ExtractAssociatedIcon($script:GameExe)
        if($ico){$bmp=$ico.ToBitmap();$ico.Dispose();return $bmp}
    } catch {}
    return $null
}

function Update-GameArtwork {
    if(-not $gameArtBox){return}
    Clear-GameArtwork
    try {
        $img=Get-GameArtwork
        if($img){
            $gameArtBox.Image=$img
            $gameArtPlaceholder.Visible=$false
        } else {$gameArtPlaceholder.Visible=$true}
    } catch {$gameArtPlaceholder.Visible=$true}
}

# ---------- UI ----------
$form=New-Object Windows.Forms.Form
$form.Text="Universal DLSS 5 Installer v1.0"
$form.StartPosition="CenterScreen"
$form.Size=New-Object Drawing.Size(1180,872)
$form.MinimumSize=New-Object Drawing.Size(1080,760)
$form.Font=New-Object Drawing.Font("Segoe UI",9)
$form.AutoScaleMode="Dpi"
$form.FormBorderStyle="Sizable"
$form.MaximizeBox=$true

# ---------- Sidebar ----------
$sidebar=New-Object Windows.Forms.Panel
$sidebar.Dock="Left"
$sidebar.Width=200
$form.Controls.Add($sidebar)

$brandLabel=New-Object Windows.Forms.Label
$brandLabel.Text="DLSS 5"
$brandLabel.Font=New-Object Drawing.Font("Segoe UI Semibold",18)
$brandLabel.AutoSize=$true
$brandLabel.Location=New-Object Drawing.Point(24,28)
$sidebar.Controls.Add($brandLabel)

$versionLabel=New-Object Windows.Forms.Label
$versionLabel.Text="Universal Installer  v1.0"
$versionLabel.AutoSize=$true
$versionLabel.Location=New-Object Drawing.Point(25,58)
$sidebar.Controls.Add($versionLabel)

$installerNavButton=New-Object Windows.Forms.Button
$installerNavButton.Text="Installer"
$installerNavButton.TextAlign="MiddleLeft"
$installerNavButton.Padding=New-Object Windows.Forms.Padding(16,0,0,0)
$installerNavButton.Font=New-Object Drawing.Font("Segoe UI Semibold",10)
$installerNavButton.Size=New-Object Drawing.Size(152,40)
$installerNavButton.Location=New-Object Drawing.Point(24,108)
$sidebar.Controls.Add($installerNavButton)

$debugNavButton=New-Object Windows.Forms.Button
$debugNavButton.Text="Debug"
$debugNavButton.TextAlign="MiddleLeft"
$debugNavButton.Padding=New-Object Windows.Forms.Padding(16,0,0,0)
$debugNavButton.Font=New-Object Drawing.Font("Segoe UI Semibold",10)
$debugNavButton.Size=New-Object Drawing.Size(152,40)
$debugNavButton.Location=New-Object Drawing.Point(24,156)
$sidebar.Controls.Add($debugNavButton)

$settingsLabel=New-Object Windows.Forms.Label
$settingsLabel.Text="Settings"
$settingsLabel.AutoSize=$true
$settingsLabel.Location=New-Object Drawing.Point(40,228)
$sidebar.Controls.Add($settingsLabel)

$aboutLabel=New-Object Windows.Forms.Label
$aboutLabel.Text="About"
$aboutLabel.AutoSize=$true
$aboutLabel.Location=New-Object Drawing.Point(40,260)
$sidebar.Controls.Add($aboutLabel)

$themeCard=New-Object Windows.Forms.Panel
$themeCard.Size=New-Object Drawing.Size(152,116)
$themeCard.Location=New-Object Drawing.Point(24,554)
$themeCard.Anchor="Bottom,Left"
$sidebar.Controls.Add($themeCard)

$themeLabel=New-Object Windows.Forms.Label
$themeLabel.Text="Appearance"
$themeLabel.Font=New-Object Drawing.Font("Segoe UI Semibold",9)
$themeLabel.AutoSize=$true
$themeLabel.Location=New-Object Drawing.Point(14,12)
$themeCard.Controls.Add($themeLabel)

$darkThemeButton=New-Object Windows.Forms.Button
$darkThemeButton.Text="Dark"
$darkThemeButton.TextAlign="MiddleLeft"
$darkThemeButton.Padding=New-Object Windows.Forms.Padding(12,0,0,0)
$darkThemeButton.Size=New-Object Drawing.Size(124,31)
$darkThemeButton.Location=New-Object Drawing.Point(14,42)
$themeCard.Controls.Add($darkThemeButton)

$darkDot=New-Object Windows.Forms.Panel
$darkDot.Size=New-Object Drawing.Size(9,9)
$darkDot.Location=New-Object Drawing.Point(124,12)
$darkThemeButton.Controls.Add($darkDot)

$lightThemeButton=New-Object Windows.Forms.Button
$lightThemeButton.Text="Light"
$lightThemeButton.TextAlign="MiddleLeft"
$lightThemeButton.Padding=New-Object Windows.Forms.Padding(12,0,0,0)
$lightThemeButton.Size=New-Object Drawing.Size(124,31)
$lightThemeButton.Location=New-Object Drawing.Point(14,80)
$themeCard.Controls.Add($lightThemeButton)

$lightDot=New-Object Windows.Forms.Panel
$lightDot.Size=New-Object Drawing.Size(9,9)
$lightDot.Location=New-Object Drawing.Point(124,12)
$lightThemeButton.Controls.Add($lightDot)

$darkThemeButton.Add_Click({$script:DarkMode=$true;Apply-Theme})
$lightThemeButton.Add_Click({$script:DarkMode=$false;Apply-Theme})

$adminCard=New-Object Windows.Forms.Panel
$adminCard.Size=New-Object Drawing.Size(152,68)
$adminCard.Location=New-Object Drawing.Point(24,686)
$adminCard.Anchor="Bottom,Left"
$sidebar.Controls.Add($adminCard)

$adminLabel=New-Object Windows.Forms.Label
$adminLabel.Text="Administrator"
$adminLabel.AutoSize=$true
$adminLabel.Location=New-Object Drawing.Point(14,14)
$adminCard.Controls.Add($adminLabel)

$adminDot=New-Object Windows.Forms.Panel
$adminDot.Size=New-Object Drawing.Size(8,8)
$adminDot.Location=New-Object Drawing.Point(145,16)
$adminCard.Controls.Add($adminDot)

$adminVersionLabel=New-Object Windows.Forms.Label
$adminVersionLabel.Text="Version 1.0"
$adminVersionLabel.AutoSize=$true
$adminVersionLabel.Location=New-Object Drawing.Point(14,43)
$adminCard.Controls.Add($adminVersionLabel)

# ---------- Content ----------
$contentHost=New-Object Windows.Forms.Panel
$contentHost.Dock="Fill"
$form.Controls.Add($contentHost)
$contentHost.BringToFront()

$installerPanel=New-Object Windows.Forms.Panel
$installerPanel.Dock="Fill"
$installerPanel.BackColor=[Drawing.Color]::Transparent
$contentHost.Controls.Add($installerPanel)

$debugPanel=New-Object Windows.Forms.Panel
$debugPanel.Dock="Fill"
$debugPanel.BackColor=[Drawing.Color]::Transparent
$debugPanel.Visible=$false
$contentHost.Controls.Add($debugPanel)

$installerNavButton.Add_Click({
    $debugPanel.Visible=$false
    $installerPanel.Visible=$true
    $installerPanel.BringToFront()
    Apply-Theme
})
$debugNavButton.Add_Click({
    $installerPanel.Visible=$false
    $debugPanel.Visible=$true
    $debugPanel.BringToFront()
    Apply-Theme
    Update-DebugConsoleLayout
})

# ---------- Installer header ----------
$title=New-Object Windows.Forms.Label
$title.Text="Universal DLSS 5 Installer"
$title.Font=New-Object Drawing.Font("Segoe UI Semibold",22)
$title.AutoSize=$true
$title.Location=New-Object Drawing.Point(34,28)
$installerPanel.Controls.Add($title)

$subtitle=New-Object Windows.Forms.Label
$subtitle.Text="Detect the game, identify the renderer, install DLSS 5, and verify the result."
$subtitle.AutoSize=$true
$subtitle.Location=New-Object Drawing.Point(36,68)
$installerPanel.Controls.Add($subtitle)

# ---------- Game ----------
$gameCard=New-Object Windows.Forms.Panel
$gameCard.Location=New-Object Drawing.Point(34,108)
$gameCard.Size=New-Object Drawing.Size(900,150)
$gameCard.Anchor="Top,Left,Right"
$installerPanel.Controls.Add($gameCard)

$gameSectionTitle=New-Object Windows.Forms.Label
$gameSectionTitle.Text="Game"
$gameSectionTitle.Font=New-Object Drawing.Font("Segoe UI Semibold",11)
$gameSectionTitle.AutoSize=$true
$gameSectionTitle.Location=New-Object Drawing.Point(20,16)
$gameCard.Controls.Add($gameSectionTitle)

$selectButton=New-Object Windows.Forms.Button
$selectButton.Text="Select game EXE"
$selectButton.Size=New-Object Drawing.Size(142,36)
$selectButton.Location=New-Object Drawing.Point(20,50)
$selectButton.Add_Click({Select-Game})
$gameCard.Controls.Add($selectButton)

$gamePathBox=New-Object Windows.Forms.TextBox
$gamePathBox.ReadOnly=$true
$gamePathBox.Location=New-Object Drawing.Point(176,57)
$gamePathBox.Size=New-Object Drawing.Size(670,24)
$gamePathBox.Anchor="Top,Left,Right"
$gameCard.Controls.Add($gamePathBox)

$rendererLabel=New-Object Windows.Forms.Label
$rendererLabel.Text="Renderer"
$rendererLabel.AutoSize=$true
$rendererLabel.Location=New-Object Drawing.Point(20,137)
$gameCard.Controls.Add($rendererLabel)

$apiCombo=New-Object Windows.Forms.ComboBox
$apiCombo.DropDownStyle="DropDownList"
@("Auto detect","DirectX 9","DirectX 10","DirectX 11","DirectX 12")|ForEach-Object{[void]$apiCombo.Items.Add($_)}
$apiCombo.SelectedIndex=0
$apiCombo.Location=New-Object Drawing.Point(92,105)
$apiCombo.Size=New-Object Drawing.Size(220,28)
$gameCard.Controls.Add($apiCombo)
$apiCombo.Add_SelectedIndexChanged({Update-DgVoodooButton;Update-RepairAvailability;Update-SR2IsolationButton})

$detectButton=New-Object Windows.Forms.Button
$detectButton.Text="Re-detect"
$detectButton.Size=New-Object Drawing.Size(110,31)
$detectButton.Location=New-Object Drawing.Point(324,103)
$detectButton.Add_Click({if($script:GameExe){Update-GameDisplay}})
$gameCard.Controls.Add($detectButton)

# ---------- Detection ----------
$infoCard=New-Object Windows.Forms.Panel
$infoCard.Location=New-Object Drawing.Point(34,272)
$infoCard.Size=New-Object Drawing.Size(900,236)
$infoCard.Anchor="Top,Left,Right"
$installerPanel.Controls.Add($infoCard)

$infoSectionTitle=New-Object Windows.Forms.Label
$infoSectionTitle.Text="Detected game information"
$infoSectionTitle.Font=New-Object Drawing.Font("Segoe UI Semibold",11)
$infoSectionTitle.AutoSize=$true
$infoSectionTitle.Location=New-Object Drawing.Point(20,16)
$infoCard.Controls.Add($infoSectionTitle)

$archLabel=New-Object Windows.Forms.Label
$archLabel.Text="Architecture"
$archLabel.AutoSize=$true
$archLabel.Location=New-Object Drawing.Point(20,88)
$infoCard.Controls.Add($archLabel)
$archValue=New-Object Windows.Forms.Label
$archValue.Text="-"
$archValue.AutoSize=$true
$archValue.Location=New-Object Drawing.Point(166,88)
$infoCard.Controls.Add($archValue)

$profileLabel=New-Object Windows.Forms.Label
$profileLabel.Text="Game profile"
$profileLabel.AutoSize=$true
$profileLabel.Location=New-Object Drawing.Point(20,120)
$infoCard.Controls.Add($profileLabel)
$profileValue=New-Object Windows.Forms.Label
$profileValue.Text="-"
$profileValue.AutoSize=$true
$profileValue.Location=New-Object Drawing.Point(166,120)
$infoCard.Controls.Add($profileValue)

$detectLabel=New-Object Windows.Forms.Label
$detectLabel.Text="Renderer guess"
$detectLabel.AutoSize=$true
$detectLabel.Location=New-Object Drawing.Point(20,152)
$infoCard.Controls.Add($detectLabel)
$detectValue=New-Object Windows.Forms.Label
$detectValue.Text="-"
$detectValue.AutoSize=$true
$detectValue.Location=New-Object Drawing.Point(166,152)
$infoCard.Controls.Add($detectValue)

$reasonLabel=New-Object Windows.Forms.Label
$reasonLabel.Text="Detection reason"
$reasonLabel.AutoSize=$true
$reasonLabel.Location=New-Object Drawing.Point(20,184)
$infoCard.Controls.Add($reasonLabel)

$reasonValue=New-Object Windows.Forms.Label
$reasonValue.Text="Select a game to begin."
$reasonValue.AutoEllipsis=$true
$reasonValue.Location=New-Object Drawing.Point(166,184)
$reasonValue.Size=New-Object Drawing.Size(440,36)
$reasonValue.Anchor="Top,Left,Right"
$infoCard.Controls.Add($reasonValue)

$gameArtBox=New-Object Windows.Forms.PictureBox
$gameArtBox.Location=New-Object Drawing.Point(650,48)
$gameArtBox.Size=New-Object Drawing.Size(230,172)
$gameArtBox.SizeMode=[Windows.Forms.PictureBoxSizeMode]::Zoom
$gameArtBox.BorderStyle=[Windows.Forms.BorderStyle]::FixedSingle
$infoCard.Controls.Add($gameArtBox)

$gameNameLabel=New-Object Windows.Forms.Label
$gameNameLabel.Text="Game"
$gameNameLabel.AutoSize=$true
$gameNameLabel.Location=New-Object Drawing.Point(20,52)
$gameNameLabel.Font=New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Regular)
$infoCard.Controls.Add($gameNameLabel)

$gameNameValue=New-Object Windows.Forms.Label
$gameNameValue.Text="Not selected"
$gameNameValue.AutoSize=$false
$gameNameValue.Location=New-Object Drawing.Point(166,48)
$gameNameValue.Size=New-Object Drawing.Size(520,24)
$gameNameValue.Font=New-Object Drawing.Font("Segoe UI Semibold",11,[Drawing.FontStyle]::Bold)
$gameNameValue.AutoEllipsis=$true
$infoCard.Controls.Add($gameNameValue)


$gameArtPlaceholder=New-Object Windows.Forms.Label
$gameArtPlaceholder.Text="GAME ART`r`nSelect an executable"
$gameArtPlaceholder.TextAlign=[Drawing.ContentAlignment]::MiddleCenter
$gameArtPlaceholder.AutoSize=$false
$gameArtPlaceholder.Location=New-Object Drawing.Point(650,48)
$gameArtPlaceholder.Size=New-Object Drawing.Size(230,172)
$gameArtPlaceholder.Enabled=$false
$infoCard.Controls.Add($gameArtPlaceholder)
$gameArtPlaceholder.BringToFront()

# Keep detection text clear of the artwork panel.
$reasonValue.Size=New-Object Drawing.Size(600,20)


# ---------- Actions ----------
$actionCard=New-Object Windows.Forms.Panel
$actionCard.Location=New-Object Drawing.Point(34,522)
$actionCard.Size=New-Object Drawing.Size(900,100)
$actionCard.Anchor="Top,Left,Right"
$installerPanel.Controls.Add($actionCard)

$actionsTitle=New-Object Windows.Forms.Label
$actionsTitle.Text="Actions"
$actionsTitle.Font=New-Object Drawing.Font("Segoe UI Semibold",11)
$actionsTitle.AutoSize=$true
$actionsTitle.Location=New-Object Drawing.Point(20,15)
$actionCard.Controls.Add($actionsTitle)

$installButton=New-Object Windows.Forms.Button
$installButton.Text="Install DLSS 5"
$installButton.Font=New-Object Drawing.Font("Segoe UI Semibold",9)
$installButton.Size=New-Object Drawing.Size(118,42)
$installButton.Location=New-Object Drawing.Point(20,46)
$installButton.Add_Click({Install-DLSS5})
$actionCard.Controls.Add($installButton)

$verifyButton=New-Object Windows.Forms.Button
$verifyButton.Text="Verify files"
$verifyButton.Size=New-Object Drawing.Size(105,42)
$verifyButton.Location=New-Object Drawing.Point(162,46)
$verifyButton.Add_Click({Verify-Install})
$actionCard.Controls.Add($verifyButton)

$repairButton=New-Object Windows.Forms.Button
$repairButton.Text="Repair ReShade"
$repairButton.Size=New-Object Drawing.Size(128,42)
$repairButton.Location=New-Object Drawing.Point(294,46)

$repairButton.Add_Click({
    if(-not $script:GameDir -or -not $script:GameExe){
        [Windows.Forms.MessageBox]::Show("Select a game executable first.","ReShade Repair") | Out-Null
        return
    }

    $isDX9=($apiCombo.Text -match 'DirectX\s*9|D3D9')
    if($isDX9 -and -not (Test-DX9TranslationReady)){
        Write-Log "[BLOCKED] ReShade repair was not started because the DX9 dgVoodoo2 wrapper (d3d9.dll) is missing."
        [Windows.Forms.MessageBox]::Show(
            "This is a DirectX 9 game, but d3d9.dll (the dgVoodoo2 DX9 wrapper) is missing.`r`n`r`nReShade repair is blocked until the DX9 translation layer is installed. Re-run FeedKit's D3D9/dgVoodoo2 installation first.",
            "DX9 translation incomplete",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    $rsState=Get-ReShadeRuntimeState
    if($isDX9 -and $rsState -eq "NotLoaded"){
        Write-Log "[BLOCKED] ReShade repair was not started because ReShade is not injecting into this DX9 game."
        [Windows.Forms.MessageBox]::Show(
            "ReShade did not load into the game at runtime.`r`n`r`nThis is an injection/proxy-chain problem, not a limited-add-on problem. Repairing dxgi.dll alone is unlikely to help.`r`n`r`nVerify the actual rendering EXE and the DX9 dgVoodoo2 d3d9.dll chain first.",
            "ReShade is not injecting",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }


    if(-not (Test-ReShadeNeedsRepair)){
        $answer=[Windows.Forms.MessageBox]::Show(
            "The current ReShade.log does not show the limited add-on warning.`r`n`r`nReShade repair is normally unnecessary and replacing dxgi.dll can break a working setup.`r`n`r`nDo you still want to continue?",
            "ReShade repair not required",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if($answer -ne [Windows.Forms.DialogResult]::Yes){
            Write-Log "[INFO] ReShade repair cancelled because the current log does not indicate limited add-on support."
            return
        }
    }
Repair-ReShade})
$actionCard.Controls.Add($repairButton)


$dgVoodooButton=New-Object Windows.Forms.Button
$dgVoodooButton.Text="Install dgVoodoo2"
$dgVoodooButton.Size=New-Object Drawing.Size(128,42)
$dgVoodooButton.Location=New-Object Drawing.Point(450,46)
$dgVoodooButton.Visible=$false
$dgVoodooButton.Enabled=$false
$dgVoodooButton.Add_Click({Install-DgVoodoo2})
$actionCard.Controls.Add($dgVoodooButton)

$feedFixButton=New-Object Windows.Forms.Button
$feedFixButton.Text="Fix DLSS inputs"
$feedFixButton.Size=New-Object Drawing.Size(126,42)
$feedFixButton.Location=New-Object Drawing.Point(588,46)
$feedFixButton.Visible=$false
$feedFixButton.Enabled=$false
$feedFixButton.Add_Click({Repair-DLSS5Inputs})
$actionCard.Controls.Add($feedFixButton)

$sr2IsolationButton=New-Object Windows.Forms.Button
$sr2IsolationButton.Text="DLSS5 Neural Rendering"
$sr2IsolationButton.Size=New-Object Drawing.Size(146,42)
$sr2IsolationButton.Location=New-Object Drawing.Point(720,46)
$sr2IsolationButton.Visible=$false
$sr2IsolationButton.Enabled=$false
$sr2IsolationButton.Add_Click({Show-SR2Vulkan32Dialog})
$actionCard.Controls.Add($sr2IsolationButton)

$openButton=New-Object Windows.Forms.Button
$openButton.Text="Open game folder"
$openButton.Size=New-Object Drawing.Size(122,42)
$openButton.Location=New-Object Drawing.Point(450,46)
$openButton.Add_Click({if($script:GameDir -and (Test-Path $script:GameDir)){Start-Process explorer.exe $script:GameDir}})
$actionCard.Controls.Add($openButton)
Update-DgVoodooButton
Update-ActionLayout

# ---------- Status ----------
$statusCard=New-Object Windows.Forms.Panel
$statusCard.Location=New-Object Drawing.Point(34,636)
$statusCard.Size=New-Object Drawing.Size(900,142)
$statusCard.Anchor="Top,Left,Right"
$installerPanel.Controls.Add($statusCard)

$statusTitle=New-Object Windows.Forms.Label
$statusTitle.Text="Status"
$statusTitle.Font=New-Object Drawing.Font("Segoe UI Semibold",11)
$statusTitle.AutoSize=$true
$statusTitle.Location=New-Object Drawing.Point(20,14)
$statusCard.Controls.Add($statusTitle)

$statusLabel=New-Object Windows.Forms.Label
$statusLabel.Text="Ready."
$statusLabel.AutoEllipsis=$true
$statusLabel.Location=New-Object Drawing.Point(20,42)
$statusLabel.Size=New-Object Drawing.Size(825,18)
$statusCard.Controls.Add($statusLabel)

$warning=New-Object Windows.Forms.Label
$warning.Text="DX10 is detectable, but native D3D10 is not supported. Use DX11 when available."
$warning.AutoEllipsis=$true
$warning.Location=New-Object Drawing.Point(20,66)
$warning.Size=New-Object Drawing.Size(825,18)
$statusCard.Controls.Add($warning)

$installerMiniConsole=New-Object Windows.Forms.Label
$installerMiniConsole.Text="Waiting for installer activity..."
$installerMiniConsole.Font=New-Object Drawing.Font("Consolas",9)
$installerMiniConsole.AutoEllipsis=$true
$installerMiniConsole.AutoSize=$false
$installerMiniConsole.Location=New-Object Drawing.Point(20,92)
$installerMiniConsole.Size=New-Object Drawing.Size(850,38)
$installerMiniConsole.Anchor="Top,Left,Right"
$installerMiniConsole.TabStop=$false
$installerMiniConsole.Cursor=[Windows.Forms.Cursors]::Default
$installerMiniConsole.UseMnemonic=$false
$statusCard.Controls.Add($installerMiniConsole)

$footer=New-Object Windows.Forms.Label
$footer.Text="Compatible single-player games only. Full ReShade add-ons may conflict with anti-cheat."
$footer.AutoSize=$true
$footer.Location=New-Object Drawing.Point(36,790)
$footer.Anchor="Bottom,Left"
$installerPanel.Controls.Add($footer)

# ---------- Debug ----------
$debugTitle=New-Object Windows.Forms.Label
$debugTitle.Text="Debug Console"
$debugTitle.Font=New-Object Drawing.Font("Segoe UI Semibold",22)
$debugTitle.AutoSize=$true
$debugTitle.Location=New-Object Drawing.Point(38,30)
$debugPanel.Controls.Add($debugTitle)

$debugSubtitle=New-Object Windows.Forms.Label
$debugSubtitle.Text="Installer activity, verification results, and game logs."
$debugSubtitle.AutoSize=$true
$debugSubtitle.Location=New-Object Drawing.Point(41,71)
$debugPanel.Controls.Add($debugSubtitle)

$debugToolbar=New-Object Windows.Forms.Panel
$debugToolbar.Location=New-Object Drawing.Point(38,112)
$debugToolbar.Size=New-Object Drawing.Size(870,64)
$debugToolbar.Anchor="Top,Left,Right"
$debugPanel.Controls.Add($debugToolbar)

$copyDebugButton=New-Object Windows.Forms.Button
$copyDebugButton.Text="Copy log"
$copyDebugButton.Size=New-Object Drawing.Size(100,34)
$copyDebugButton.Location=New-Object Drawing.Point(14,15)
$debugToolbar.Controls.Add($copyDebugButton)

$saveDebugButton=New-Object Windows.Forms.Button
$saveDebugButton.Text="Save log"
$saveDebugButton.Size=New-Object Drawing.Size(100,34)
$saveDebugButton.Location=New-Object Drawing.Point(124,15)
$debugToolbar.Controls.Add($saveDebugButton)

$clearDebugButton=New-Object Windows.Forms.Button
$clearDebugButton.Text="Clear"
$clearDebugButton.Size=New-Object Drawing.Size(82,34)
$clearDebugButton.Location=New-Object Drawing.Point(234,15)
$debugToolbar.Controls.Add($clearDebugButton)

$loadGameLogsButton=New-Object Windows.Forms.Button
$loadGameLogsButton.Text="Load game logs"
$loadGameLogsButton.Size=New-Object Drawing.Size(130,34)
$loadGameLogsButton.Location=New-Object Drawing.Point(326,15)
$debugToolbar.Controls.Add($loadGameLogsButton)

$openCollectedLogsButton=New-Object Windows.Forms.Button
$openCollectedLogsButton.Text="Open collected logs"
$openCollectedLogsButton.Size=New-Object Drawing.Size(145,34)
$openCollectedLogsButton.Location=New-Object Drawing.Point(466,15)
$openCollectedLogsButton.Add_Click({
    Copy-GameLogsToInstaller
    Open-CollectedLogs
})
$debugToolbar.Controls.Add($openCollectedLogsButton)

$smallerLogButton=New-Object Windows.Forms.Button
$smallerLogButton.Text="A-"
$smallerLogButton.Size=New-Object Drawing.Size(46,34)
$smallerLogButton.Location=New-Object Drawing.Point(622,15)
$smallerLogButton.Add_Click({
    $newSize=[Math]::Max(8,[Math]::Round($logBox.Font.Size-1,0))
    $logBox.Font=New-Object Drawing.Font("Consolas",$newSize)
})
$debugToolbar.Controls.Add($smallerLogButton)

$largerLogButton=New-Object Windows.Forms.Button
$largerLogButton.Text="A+"
$largerLogButton.Size=New-Object Drawing.Size(46,34)
$largerLogButton.Location=New-Object Drawing.Point(678,15)
$largerLogButton.Add_Click({
    $newSize=[Math]::Min(16,[Math]::Round($logBox.Font.Size+1,0))
    $logBox.Font=New-Object Drawing.Font("Consolas",$newSize)
})
$debugToolbar.Controls.Add($largerLogButton)

$logLabel=New-Object Windows.Forms.Label
$logLabel.Text="Live log"
$logLabel.Font=New-Object Drawing.Font("Segoe UI Semibold",10)
$logLabel.AutoSize=$true
$logLabel.Location=New-Object Drawing.Point(39,194)
$debugPanel.Controls.Add($logLabel)

$logBox=New-Object Windows.Forms.TextBox
$logBox.Multiline=$true
$logBox.ReadOnly=$true
$logBox.ScrollBars="Both"
$logBox.WordWrap=$false
$logBox.Font=New-Object Drawing.Font("Consolas",10)
$logBox.Location=New-Object Drawing.Point(38,222)
$logBox.Size=New-Object Drawing.Size(870,460)
$logBox.Anchor="Top,Bottom,Left,Right"
$debugPanel.Controls.Add($logBox)


function Update-DebugConsoleLayout {
    try {
        if(-not $debugPanel -or -not $logBox){ return }

        $left=38
        $right=26
        $top=222
        $bottom=26

        $w=[Math]::Max(420, $debugPanel.ClientSize.Width - $left - $right)
        $h=[Math]::Max(220, $debugPanel.ClientSize.Height - $top - $bottom)

        $logBox.Location=New-Object Drawing.Point($left,$top)
        $logBox.Size=New-Object Drawing.Size($w,$h)

        # Keep the toolbar inside the visible client area too.
        if($debugToolbar){
            $toolbarW=[Math]::Max(420, $debugPanel.ClientSize.Width - 76)
            $debugToolbar.Size=New-Object Drawing.Size($toolbarW,64)
        }
    } catch {}
}

$copyDebugButton.Add_Click({
    if($logBox.TextLength -gt 0){
        [Windows.Forms.Clipboard]::SetText($logBox.Text)
        $statusLabel.Text="Debug log copied to clipboard."
    }
})

$saveDebugButton.Add_Click({
    $dlg=New-Object Windows.Forms.SaveFileDialog
    $dlg.Filter="Text log (*.txt)|*.txt"
    $dlg.FileName="UniversalDLSS5Installer-Debug-$((Get-Date).ToString('yyyyMMdd-HHmmss')).txt"
    if($dlg.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){
        [IO.File]::WriteAllText($dlg.FileName,$logBox.Text,[Text.Encoding]::UTF8)
        $statusLabel.Text="Debug log saved."
    }
})

$clearDebugButton.Add_Click({
    $logBox.Clear()
    $statusLabel.Text="Debug log cleared."
})

$loadGameLogsButton.Add_Click({
    Copy-GameLogsToInstaller -Quiet
    if(-not $script:GameDir){
        [Windows.Forms.MessageBox]::Show("Select a game first.","Debug","OK","Information")|Out-Null
        return
    }
    Write-Log "===== GAME LOG SNAPSHOT ====="
    foreach($name in @("ReShade.log","dlss5-dx11-bridge.log")){
        $path=Join-Path $script:GameDir $name
        Write-Log "--- $name ---"
        if(Test-Path $path){
            try{
                Get-Content -LiteralPath $path -ErrorAction Stop | Select-Object -Last 150 | ForEach-Object {
                    $logBox.AppendText("$_`r`n")
                }
            }catch{
                Write-Log "[ERROR] Could not read ${name}: $($_.Exception.Message)"
            }
        }else{
            Write-Log "[INFO] $name not found."
        }
    }
    Write-Log "===== END GAME LOG SNAPSHOT ====="
})


# SR2 safe dgVoodoo test monitor.
$script:SR2SafeTestActive=$false
$script:SR2SafeTestProcessId=$null
$script:SR2SafeTestStart=$null
$script:SR2SafeTestExitSeen=$null
$script:SR2SafeTestProfile=$null

$script:SR2SafeTimer=New-Object Windows.Forms.Timer
$script:SR2SafeTimer.Interval=1000
$script:SR2SafeTimer.Add_Tick({
    if(-not $script:SR2SafeTestActive){ return }

    $running=$false
    try {
        $p=Get-Process -Id $script:SR2SafeTestProcessId -ErrorAction Stop
        if($p){ $running=$true }
    } catch {}

    if($running){
        $script:SR2SafeTestExitSeen=$null
        return
    }

    if(-not $script:SR2SafeTestExitSeen){
        $script:SR2SafeTestExitSeen=Get-Date
        return
    }

    # Give Juiced's exception handler a moment to finish writing the crash log.
    if(((Get-Date)-$script:SR2SafeTestExitSeen).TotalSeconds -lt 2){ return }

    try { $script:SR2SafeTimer.Stop() } catch {}
    $script:SR2SafeTestActive=$false

    $knownCrash=Get-SR2KnownCrashSince -Since $script:SR2SafeTestStart
    if($knownCrash){
        Write-Log "[DETECTED] Known SR2 +0x5EE9F2 crash signature: $(Split-Path $knownCrash -Leaf)"
        Rollback-SR2ToNativeD3D9 -Reason "SR2_pc.exe +0x5EE9F2 occurred during compatibility Profile $($script:SR2SafeTestProfile)."

        [Windows.Forms.MessageBox]::Show(
            "The known Saints Row 2 dgVoodoo crash (+0x5EE9F2) was detected.`r`n`r`nd3d9.dll has been disabled automatically, so the next launch will use native DirectX 9.`r`n`r`nYou can try another profile from SR2 compatibility.",
            "SR2 automatic rollback",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    } else {
        Write-Log "[SR2 TEST] SR2 exited without the known +0x5EE9F2 crash signature."
        Write-Log "[SR2 TEST] If you reached the menu/gameplay normally, Profile $($script:SR2SafeTestProfile) passed the startup test."
        Write-Log "[NEXT] Re-open SR2 compatibility or click Verify files for runtime evidence."
    }
})


# SR2 DXVK launch monitor.
$script:SR2DXVKTestActive=$false
$script:SR2DXVKTestProcessId=$null
$script:SR2DXVKTestStart=$null
$script:SR2DXVKExitSeen=$null

$script:SR2DXVKTimer=New-Object Windows.Forms.Timer
$script:SR2DXVKTimer.Interval=1000
$script:SR2DXVKTimer.Add_Tick({
    if(-not $script:SR2DXVKTestActive){ return }

    $running=$false
    try {
        $p=Get-Process -Id $script:SR2DXVKTestProcessId -ErrorAction Stop
        if($p){ $running=$true }
    } catch {}

    if($running){
        $script:SR2DXVKExitSeen=$null
        return
    }

    if(-not $script:SR2DXVKExitSeen){
        $script:SR2DXVKExitSeen=Get-Date
        return
    }

    # Allow Juiced/DXVK logs to flush after process exit.
    if(((Get-Date)-$script:SR2DXVKExitSeen).TotalSeconds -lt 2){ return }

    try { $script:SR2DXVKTimer.Stop() } catch {}
    $script:SR2DXVKTestActive=$false

    $crash=Get-SR2CrashSince -Since $script:SR2DXVKTestStart
    $dxvkLog=Get-SR2DXVKRuntimeLog -Since $script:SR2DXVKTestStart

    if($crash){
        Write-Log "[DXVK CRASH] New Juiced crash log detected: $(Split-Path $crash -Leaf)"
        Restore-SR2NativeD3D9FromDXVK -Reason "SR2 crashed during the DXVK test."
        [Windows.Forms.MessageBox]::Show(
            "Saints Row 2 generated a new Juiced crash log during the DXVK test.`r`n`r`nDXVK has been disabled automatically and native DirectX 9 restored for the next launch.`r`n`r`nSend the new crash log and DXVK d3d9 log if one was created.",
            "SR2 DXVK automatic rollback",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    } elseif($dxvkLog){
        Write-Log "[DXVK PASS] Runtime evidence detected: $(Split-Path $dxvkLog -Leaf)"
        Write-Log "[DXVK PASS] SR2 exited without a new Juiced crash log. If you reached gameplay, the DXVK translation test passed."
        Write-Log "[IMPORTANT] DLSS5 remains blocked in this mode until feed32 Vulkan transport is released/testable."
        [Windows.Forms.MessageBox]::Show(
            "DXVK runtime evidence was detected and no new Juiced crash log was created.`r`n`r`nIf you reached actual gameplay, the SR2 + Juiced DXVK compatibility test passed.`r`n`r`nDLSS5 Neural Rendering is still not enabled in this mode.",
            "SR2 DXVK result",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } else {
        Write-Log "[DXVK CHECK] SR2 exited without a Juiced crash log, but no fresh DXVK runtime log was detected."
        Write-Log "[DXVK CHECK] Use Verify DXVK Runtime or send the Status/Debug output before changing anything else."
    }
    Copy-GameLogsToInstaller -Quiet
})

# Mirror ReShade/DLSS logs into the installer folder while this app is running.
$logMirrorTimer=New-Object Windows.Forms.Timer
$logMirrorTimer.Interval=3000
$logMirrorTimer.Add_Tick({
    if($script:GameDir){ Copy-GameLogsToInstaller -Quiet }
})
$logMirrorTimer.Start()

$form.Add_FormClosed({
    try{$logMirrorTimer.Stop()}catch{}
    try{$script:SR2SafeTimer.Stop()}catch{}
    try{$script:SR2DXVKTimer.Stop()}catch{}
    try{Clear-GameArtwork}catch{}
})

$form.Add_Resize({Apply-RoundedLayout;Update-DebugConsoleLayout})
$form.Add_Shown({
    try { $installerNavButton.PerformClick() } catch {}
try{Set-WindowsBackdrop}catch{};try{Apply-RoundedLayout}catch{};try{Update-DebugConsoleLayout}catch{}})

# Always start in Dark mode.
$script:DarkMode=$true
Apply-Theme
Write-Log "Ready."
Write-Log "[APP] Runtime root: $script:AppRoot"
Write-Log "Game logs are automatically mirrored into the Logs folder beside this installer while it is running."
Write-Log "v1.0: SR2 DXVK/Vulkan + DLSS5 Neural Rendering path; current feeder settings use ReShade Add-ons UI."
Write-Log "If detection is uncertain, launch once and click Re-detect. Runtime ReShade.log evidence takes priority."

[void]$form.ShowDialog()
