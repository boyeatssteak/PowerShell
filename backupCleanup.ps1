# Created by @boyEatsSteak
# letterx.co
# 2018.Nov.13
# DESC: Deletes files that meet a certain age requirement, or size and age requirement and saves a log file.

# Settings
$targetFolder = "C:\TestFiles" # script will be confined to files contained in this folder, or its sub-folders
$logFileFolder = "~\Desktop\backupCleanupLogs" # default "~\Desktop\backupCleanupLogs" to save to current user desktop
$targetFileExtension = "*.txt" # script will only remove files matching this extension
$smallFileDaysToKeep = 7
$largeFileThreshold = "4mb"
$largeFileDaysToKeep = 4

# If no target folder exists, exit
if(!(Test-Path $targetFolder)) {
  Write-Host "Target folder not found - exiting." -BackgroundColor Black -ForegroundColor Red
  Write-Host ""
  exit
}

# Info Gathering
$allFiles = Get-ChildItem -Path $targetFolder -Recurse -File
$beforeFiles = Get-ChildItem -Path $targetFolder -Include $targetFileExtension -Recurse -File
$beforeSize = [math]::Round(($beforeFiles | Measure-Object Length -s).Sum /1GB, 5)
$today = Get-Date
$logFileName = "backupCleanupLog_$($today.ToString('yyyyMMdd-HHmm')).log"
$smallFileExpiration = $today.AddDays(-$smallFileDaysToKeep)
$largeFileExpiration = $today.AddDays(-$largeFileDaysToKeep)
$ignoredFiles = Get-ChildItem -Path $targetFolder -Exclude $targetFileExtension -Recurse -File

# Begin Logging
$logFileFullPath = $logFileFolder + "\" + $logFileName
if(!(Test-Path $logFileFolder)) {
  mkdir $logFileFolder
}
Add-Content -Path $logFileFullPath Get-Date
Add-Content -Path $logFileFullPath "Ignoring $($ignoredFiles.count) non $targetFileExtension files"
Add-Content -Path $logFileFullPath "Found $($beforeFiles.count) $targetFileExtension files ( $beforeSize GB )"

Write-Host ""
Write-Host "Ignoring $($ignoredFiles.count) non $targetFileExtension file(s)"
Write-Host "Found $($beforeFiles.count) $targetFileExtension files ( $beforeSize GB ) in $targetFolder"
Write-Host "Which setting should be used?" -BackgroundColor White -ForegroundColor Black
Write-Host ""

$normalRunFiles = Get-ChildItem -Path $targetFolder -Recurse -Include $targetFileExtension -File | where {(($_.Length -lt $largeFileThreshold) -And ($_.LastWriteTime -lt $smallFileExpiration)) -or (($_.Length -gt $largeFileThreshold) -And ($_.LastWriteTime -lt $largeFileExpiration))}
$normalRunSize = [math]::Round(($normalRunFiles | Measure-Object Length -s).Sum /1GB, 5)
Write-Host "NORMAL:" -BackgroundColor White -ForegroundColor Black
Write-Host "If a file is larger than $largeFileThreshold, only keep files from the last $largeFileDaysToKeep days."
Write-Host "For files smaller than $largeFileThreshold, keep files from the last $smallFileDaysToKeep days."
Write-Host "Will remove $($normalRunFiles.count) files ( $normalRunSize GB )"
Write-Host ""

$relaxedRunFiles = Get-ChildItem -Path $targetFolder -Recurse -Include $targetFileExtension -File | where LastWriteTime -lt $smallFileExpiration
$relaxedRunSize = [math]::Round(($relaxedRunFiles | Measure-Object Length -s).Sum /1GB, 5)
Write-Host "RELAXED:" -BackgroundColor White -ForegroundColor Black
Write-Host "Only delete files older than $smallFileDaysToKeep days, regardless of size."
Write-Host "Will remove $($relaxedRunFiles.count) files ( $relaxedRunSize GB )"
Write-Host ""

$filesToUse = ""

$askSetting = {
  $setting = Read-Host "(N)ormal | (R)elaxed | (A)bort"
  if ($setting -eq "a") {
    Add-Content -Path $logFileFullPath "User aborted task at $(Get-Date). Nothing changed."
    Write-Host ""
    Write-Host "Aborting task, nothing changed"
    Write-Host ""
    exit
  } elseif ($setting -eq "n") {
    Add-Content -Path $logFileFullPath "User selected NORMAL run: If over $largeFileThreshold keep $largeFileDaysToKeep days, if under $largeFileThreshold, keep $smallFileDaysToKeep days"
    $script:filesToUse = $normalRunFiles
    Write-Host "Proceeding with NORMAL setting" -BackgroundColor White -ForegroundColor Black
    Write-Host ""
  } elseif ($setting -eq "r") {
    Add-Content -Path $logFileFullPath "User selected RELAXED run: Delete files over $smallFileDaysToKeep days old, regardless of size."
    $script:filesToUse = $relaxedRunFiles
    Write-Host "Proceeding with RELAXED setting" -BackgroundColor White -ForegroundColor Black
    Write-Host ""
  } else {
    Write-Host ""
    Write-Host "Please choose from the available options"
    .$askSetting
  }
}
&$askSetting

# $test = "Test"
# Write-Host $test
# $changeTest = {
#   $script:test = "Test Updated"
#   Write-Host $script:test
# }
# &$changeTest
# Write-Host $test

# Show Ignored Files
Write-Host "FILES IGNORED:" -BackgroundColor Yellow -ForegroundColor Black
if(!($ignoredFiles.count -eq 0)) {
  Compare-Object -ReferenceObject $allFiles -DifferenceObject $ignoredFiles -IncludeEqual -Property FullName, LastWriteTime, Length, Name | where {$_.SideIndicator -eq "=="} | ForEach-Object {
    $filesize = [math]::Round(($_.Length / 1MB), 2)
    Add-Content -Path $logFileFullPath "IGNORED $($_.FullName) ( Mod $($_.LastWriteTime) | Size $filesize MB )"
    Write-Host "$($_.Name) ( Mod $($_.LastWriteTime) | Size $filesize MB )" -BackgroundColor Black -ForegroundColor Yellow
  }
}
$ignoredSize = [math]::Round(($ignoredFiles | Measure-Object Length -s).Sum /1GB, 5)
Write-Host "TOTAL: $($ignoredFiles.count) files, $ignoredSize GB" -BackgroundColor Black -ForegroundColor Yellow
Write-Host ""

# Show Kept Files
Write-Host "FILES KEPT:" -BackgroundColor Green -ForegroundColor Black
Compare-Object -ReferenceObject $allFiles -DifferenceObject $filesToUse -IncludeEqual -Property FullName, LastWriteTime, Length, Name | where {$_.SideIndicator -eq "<="} | ForEach-Object {
  $filesize = [math]::Round(($_.Length / 1MB), 2)
  Add-Content -Path $logFileFullPath "KEEP $($_.FullName) ( Mod $($_.LastWriteTime) | Size $filesize MB )"
  Write-Host "$($_.Name) ( Mod $($_.LastWriteTime) | Size $filesize MB )" -BackgroundColor Black -ForegroundColor Green
}
$deletedSize = [math]::Round(($filesToUse | Measure-Object Length -s).Sum /1GB, 5)
$keptSize = $beforeSize - $deletedSize
$keptFiles = $beforeFiles.count - $filesToUse.count
Write-Host "TOTAL: $keptFiles files, $keptSize GB" -BackgroundColor Black -ForegroundColor Green
Write-Host ""

# Show Deleted Files
Write-Host "FILES DELETED:" -BackgroundColor Red -ForegroundColor Black
Compare-Object -ReferenceObject $allFiles -DifferenceObject $filesToUse -IncludeEqual -Property FullName, LastWriteTime, Length, Name | where {$_.SideIndicator -eq "=="} | ForEach-Object {
  $filesize = [math]::Round(($_.Length / 1MB), 2)
  Add-Content -Path $logFileFullPath "DELETE $($_.FullName) ( Mod $($_.LastWriteTime) | Size $filesize MB )"
  Write-Host "$($_.Name) ( Mod $($_.LastWriteTime) | Size $filesize MB )" -BackgroundColor Black -ForegroundColor Red
}
Write-Host "TOTAL: $($filesToUse.count) files, $deletedSize GB" -BackgroundColor Black -ForegroundColor Red
Write-Host ""

# Delete Files
foreach ($file in $filesToUse) {
  $file.Delete()
}

# Wrapup
Add-Content -Path $logFileFullPath "TOTAL IGNORED: $($ignoredFiles.count) files, $ignoredSize GB"
Add-Content -Path $logFileFullPath "TOTAL KEPT: $keptFiles files, $keptSize GB"
Add-Content -Path $logFileFullPath "TOTAL DELETED: $($filesToUse.count) files, $deletedSize GB"
Add-Content -Path $logFileFullPath "SCRIPT COMPLETED at $(Get-Date)"
Write-Host "Log of activity saved to $logFileFullPath"
Write-Host ""