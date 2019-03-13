# Created by @boyEatsSteak
# letterx.co
# 2018.Nov.13
# DESC: Deletes files that meet a certain age requirement, or size and age requirement and saves a log file.

# Settings
$targetFolder = "C:\TestFiles" # script will be confined to files contained in this folder, or its sub-folders
$logFileFolder = "~\Desktop\backupCleanupLogs" # default "~\Desktop\backupCleanupLogs" to save to current user desktop
$targetFileExtension = ".txt" # script will only remove files matching this extension
$smallFileDaysToKeep = 7
$largeFileThreshold = 5000000 # in bytes
$largeFileDaysToKeep = 4

# Info Gathering
$allFiles = Get-ChildItem -Path $targetFolder -Recurse -File
$beforeSize = [math]::Round(($allFiles | Measure-Object Length -s).Sum /1GB, 5)
$today = Get-Date
$logFileName = "backupCleanupLog_$($today.ToString('yyyyMMdd-HHmm')).log"
$smallFileExpiration = $today.AddDays(-$smallFileDaysToKeep)
$largeFileExpiration = $today.AddDays(-$largeFileDaysToKeep)
$ignoredFiles = 0
if(!(Test-Path $logFileFolder)) {
  mkdir $logFileFolder
}

Add-Content -Path $logFileFolder"\"$logFileName $today
Add-Content -Path $logFileFolder"\"$logFileName "Found $($allFiles.count) files ($beforeSize GB )"
Write-Host "Found $($allFiles.count) files ($beforeSize GB )" -BackgroundColor White -ForegroundColor Black

# Deleting Old Files
Foreach ($file in $allFiles) {
  $filesize = [math]::Round(($file | Measure-Object Length -s).Sum /1MB, 2)
  if ($file.Extension -ne $targetFileExtension) {
    Add-Content -Path $logFileFolder"\"$logFileName "IGNORING $($file.FullName)"
    Write-Host "IGNORING $($file.Name)" -BackgroundColor Black -ForegroundColor Yellow
    $ignoredFiles++
  } elseif ($file.LastWriteTime -lt $smallFileExpiration) {
    Add-Content -Path $logFileFolder"\"$logFileName "DELETE $($file.FullName) ( Modified $($file.LastWriteTime) | Size $filesize MB )"
    Write-Host "DELETE $($file.Name) ( Modified $($file.LastWriteTime) | Size $filesize MB )" -BackgroundColor Black -ForegroundColor DarkRed
    $file.Delete()
  } elseif ($file.LastWriteTime -lt $largeFileExpiration -And $file.Length -gt $largeFileThreshold) {
    Add-Content -Path $logFileFolder"\"$logFileName "DELETE $($file.FullName) ( Modified $($file.LastWriteTime) | Size $filesize MB )"
    Write-Host "DELETE $($file.Name) ( Modified $($file.LastWriteTime) | Size $filesize MB )" -BackgroundColor Black -ForegroundColor DarkRed
    $file.Delete()
  } else {
    Add-Content -Path $logFileFolder"\"$logFileName -Value "KEEP $($file.FullName) ( Modified $($file.LastWriteTime) | Size $filesize MB )"
    Write-Host "KEEP $($file.Name) ( Modified $($file.LastWriteTime) | Size $filesize MB )" -BackgroundColor Black -ForegroundColor Green
  }
}

# Post Wrapup
$afterFiles = Get-ChildItem -Path $targetFolder -Recurse -File
$afterSize = [math]::Round(($afterFiles | Measure-Object Length -s).Sum /1GB, 5)
Add-Content -Path $logFileFolder"\"$logFileName "Found $($allFiles.count) files ( $beforeSize GB )"
Add-Content -Path $logFileFolder"\"$logFileName "Kept $($afterFiles.count) files ( $afterSize GB )"
Add-Content -Path $logFileFolder"\"$logFileName "Ignored $ignoredFiles non '$targetFileExtension' file(s)"
Write-Host "Found $($allFiles.count) files ( $beforeSize GB )" -BackgroundColor White -ForegroundColor Black
Write-Host "Kept $($afterFiles.count) files ( $afterSize GB ) [ $($allFiles.count - $afterFiles.count - $ignoredFiles ) files removed ]" -BackgroundColor White -ForegroundColor Black
Write-Host "Ignored $ignoredFiles non '$targetFileExtension' file(s)" -BackgroundColor White -ForegroundColor Black
Write-Host "Log of activity saved to $logFileFolder\$logFileName"
Write-Host ""
Add-Content -Path $logFileFolder"\"$logFileName "SCRIPT COMPLETED"