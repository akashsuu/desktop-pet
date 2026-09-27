# check_audio.ps1
# Detect if media is playing using Windows SMTC (System Media Transport Controls)
# Works with Spotify, browsers, VLC, and any app that uses Windows media controls.

Add-Type -AssemblyName System.Runtime.WindowsRuntime

[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime] | Out-Null

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

try {
    $asyncOp = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()
    $asTask = $asTaskGeneric.MakeGenericMethod([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
    $task = $asTask.Invoke($null, @($asyncOp))
    $task.Wait()
    $mgr = $task.Result

    $sessions = $mgr.GetSessions()
    foreach ($s in $sessions) {
        $pi = $s.GetPlaybackInfo()
        if ($pi.PlaybackStatus -eq 4) {  # 4 = Playing
            Write-Output "1"
            exit
        }
    }
} catch {}

Write-Output "0"
