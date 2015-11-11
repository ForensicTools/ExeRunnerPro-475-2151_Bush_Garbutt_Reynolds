param (
[switch]$finder = $false,
[string]$artifacts
)

if ($true) {
    write-host "Starting powershot 1..."
    ($shot1,$shot1_reg) = get-PowerShot
    #$shot1 = get-powershot
    write-host "shot finished, Please install the program"
    $outFile = Read-Host "Please enter program name"
    $outFile = '.\' + $outfile
    #pause
    write-host "Has the program been installed?"
    pause
    ($shot2,$shot2_reg) = get-PowerShot
    #$shot2 = get-powershot
    $artifacts = get-PowerArtifact $shot1 $shot2
    $artifacts | export-clixml -path "$outfile.xml"
    $artifacts = get-PowerArtifact $shot1_reg $shot2_reg
    $artifacts | export-clixml -path ($outfile + "_reg.xml")

    $art1 = import-clixml -path "$outfile.xml"
    $shot3 = get-powershot
    $results = artifact-finder -Artifacts $art1 -Machine $shot3


    }

<#
write-host "Getting system forensicshot..."
$forensicShot = "shot" #get-PowerShot | out-null
write-host "forensicShot complete"
pause
write-host "Importing Artifact list"
$shot2 = get-content $artifacts
write-host "searching for artifacts"
$matches = "MATCH!" #get-PowerShot | Out-Null
echo $matches

function Power-FakeRunnerInstallerMax {
    param($dir,$first,$second,$third)
    $first = Get-PowerShot -getReg $false
    $neverthesame                      = "$dir\neverthesame.txt"
    $MadeAfter1SnapDeletedAfter2ndSnap = "$dir\MadeAfter1SnapDeletedAfter2ndSnap.txt"
    $AddedAfter2ndSnap                 = "$dir\AddedAfter2ndSnap.txt"
    Get-Date | Out-File $neverthesame  #add a change for debugging
    Get-Date | Out-File $MadeAfter1SnapDeletedAfter2ndSnap     #add a change for debugging
    sleep -Seconds 1
    $second = Get-PowerShot   -getReg $false
    rm $MadeAfter1SnapDeletedAfter2ndSnap
    Get-Date | Out-File $AddedAfter2ndSnap     #add a change for debugging
    Get-Date | Out-File $neverthesame  #add a change for debugging
    sleep -Seconds 1
    $third = Get-PowerShot  -getReg $false
    rm $AddedAfter2ndSnap
    return($first,$second,$third)
}

#>
