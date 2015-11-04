Function Get-RecentFiles

{

 Param([string[]]$path,
       [int]$numberDays,
       [ref]$touchedFiles)

 $cutOffDate = (Get-Date).AddDays(-$numberDays)

 write-host "Enumerating through " -nonewline
 write-host $path -foregroundcolor green

 foreach ($file in (Get-ChildItem -Path $path -recurse | Where-Object {$_.LastAccessTime -ge $cutOffDate})) {$touchedFiles.value += $file.FullName } 

}
cls

$touchedFiles = @()

$drives = ([System.IO.DriveInfo]::getdrives()).name
foreach($drive in $drives) Get-RecentFiles -numberDays 1 -touchedFiles ([ref]$touchedFiles) -path "C:\Users\Student" 

$registryFolders = (Get-ChildItem -Path Registry::*).Name
foreach($regFolder in $registryFolders) {Get-RecentFiles -numberDays 1 -touchedFiles ([ref]$touchedFiles)  -path ("Registry::" + $regFolder)}
