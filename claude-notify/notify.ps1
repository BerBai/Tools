param(
    [string]$Event = "Stop"
)

# Force UTF-8 to correctly read Chinese and other unicode from Claude Code
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =========================
# Toast Settings
# =========================
$toastIcon  = $null
$toastTitle = "ClaudeCode"

# Check icon exists
if (-not (Test-Path $toastIcon)) {
    $toastIcon = $null
}

# =========================
# Read stdin JSON
# =========================
$inputLines = @()
while ($null -ne ($line = [Console]::In.ReadLine())) {
    $inputLines += $line
}
$rawJson = $inputLines -join "`n"

$data = $null
if ($rawJson.Trim() -ne "") {
    try {
        $data = $rawJson | ConvertFrom-Json
    } catch {
        # JSON parse failed, use defaults
    }
}

# =========================
# Default values
# =========================
$title = $toastTitle
$body = ""

# =========================
# Event Logic
# =========================
if ($Event -eq "Stop") {

    $projectName = ""

    if ($data -and $data.cwd) {
        $projectName = Split-Path $data.cwd -Leaf
    }

    if ($projectName -ne "") {
        $title = "$toastTitle - $projectName"
    }

    if ($data -and $data.transcript_path -and $data.transcript_path -ne "" -and (Test-Path $data.transcript_path)) {
        try {
            $lines = Get-Content $data.transcript_path -Tail 30 -Encoding UTF8

            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                $entry = $null
                try {
                    $entry = $lines[$i] | ConvertFrom-Json
                } catch {
                    continue
                }

                if ($entry -and $entry.message -and $entry.message.role -eq "assistant") {
                    $content = $entry.message.content

                    if ($content -is [string]) {
                        $body = $content
                    }
                    elseif ($content -is [array]) {
                        $textBlock = $content | Where-Object { $_.type -eq "text" } | Select-Object -First 1
                        if ($textBlock) {
                            $body = $textBlock.text
                        }
                    }

                    if ($body.Trim() -ne "") {
                        break
                    }
                }
            }

        } catch {
            # transcript read failed
        }
    }

    if ($body.Trim() -eq "") {
        $body = "Task completed, please review results."
    }
    elseif ($body.Length -gt 150) {
        $body = $body.Substring(0, 147) + "..."
    }

}
elseif ($Event -eq "Notification") {

    $title = "$toastTitle - Needs Attention"

    if ($data -and $data.message -and $data.message.Trim() -ne "") {
        $body = $data.message

        if ($body.Length -gt 150) {
            $body = $body.Substring(0, 147) + "..."
        }
    }
    else {
        $body = "Claude is waiting for your input or approval."
    }

}
else {
    $title = $toastTitle
    $body = "Event received: $Event"
}

# =========================
# BurntToast
# =========================
function Send-ToastViaBurntToast {
    param($t, $b)

    Import-Module BurntToast -ErrorAction Stop

    if ($toastIcon) {
        New-BurntToastNotification -AppLogo $toastIcon -Text $t, $b -Sound Default
    }
    else {
        New-BurntToastNotification -Text $t, $b -Sound Default
    }
}

# =========================
# WinRT Toast
# =========================
function Send-ToastViaWinRT {
    param($t, $b)

    [Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument,Windows.Data.Xml.Dom,ContentType=WindowsRuntime] | Out-Null

    $appId = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

    $safeTitle = [System.Security.SecurityElement]::Escape($t)
    $safeBody  = [System.Security.SecurityElement]::Escape($b)

    if ($toastIcon) {
        $iconUri = "file:///" + ($toastIcon -replace "\\","/")
        $xml = @"
<toast>
    <visual>
        <binding template='ToastGeneric'>
            <image placement='appLogoOverride' src='$iconUri'/>
            <text>$safeTitle</text>
            <text>$safeBody</text>
        </binding>
    </visual>
    <audio src='ms-winsoundevent:Notification.Default'/>
</toast>
"@
    }
    else {
        $xml = @"
<toast>
    <visual>
        <binding template='ToastGeneric'>
            <text>$safeTitle</text>
            <text>$safeBody</text>
        </binding>
    </visual>
    <audio src='ms-winsoundevent:Notification.Default'/>
</toast>
"@
    }

    $toastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $toastXml.LoadXml($xml)

    $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
}

# =========================
# Balloon Fallback
# =========================
function Send-ToastViaBalloon {
    param($t, $b)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $notify = New-Object System.Windows.Forms.NotifyIcon

    if ($toastIcon) {
        $notify.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($toastIcon)
    }
    else {
        $notify.Icon = [System.Drawing.SystemIcons]::Information
    }

    $notify.Visible = $true
    $notify.ShowBalloonTip(8000, $t, $b, [System.Windows.Forms.ToolTipIcon]::Info)

    Start-Sleep -Seconds 3
    $notify.Dispose()
}

# =========================
# Send Notification
# =========================
try {
    Send-ToastViaBurntToast $title $body
}
catch {
    try {
        Send-ToastViaWinRT $title $body
    }
    catch {
        Send-ToastViaBalloon $title $body
    }
}