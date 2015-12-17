Function Get-PowerShot {
	
param([string]$rootDir , #Folder to recurcivly serach
      [bool]$getReg )	#Set to true to also get registry information
    
    #Initilze vars to be returned
    $regresults = @{} #Array to hold the results of getting data on files/folders
    $results    = @{} #Array to hold the results of getting data on files/folders

    if($getReg) { #only do the registry items if specified
        $registryFolders = (Get-ChildItem -Path Registry::*).Name  #get all registry hives
        $iReg = 1 #Seed value for foreach loop
    
        foreach ($regFolder in $registryFolders[0]) {  #debug Should not be index 0, should be entire array
	        Write-Progress -Id 0 -Activity "Registry Snapshot" -Status "Exporting $regFolder" -PercentComplete ($iReg / $registryFolders.count * 100);$iReg++ #Update Progressbar
            regedit /e ./$regFolder.reg "$regFolder" | out-null #Export Hive
            $reg = Get-Content ./$regFolder.reg | Select -skip 2
            $finalitem = ""
            $key = ""
            $iItems=0
            foreach ($item in $reg){
                Write-Progress -Id 1 -ParentId 0 -Activity "Registry Snapshot" -Status "Comparing $item" -PercentComplete ($iItems / $reg.TotalCount * 100);$iItems++ #Update Progressbar

                if ($item -notmatch '\[HKEY' -and $item -notmatch "`n`r"){
                        $finalitem += $item
                }
                elseif($item -notmatch '\[HKEY'){
                    $object = New-Object –TypeName PSObject
                    $object | Add-Member –MemberType NoteProperty –Name VALUE –Value $finalitem
                    $regresults.Add($key, $object)
                }
                elseif($item -match '\[HKEY'){
                    $key = $item 
                    $finalitem = ""
                }
            }
        }
    }
	

    #Numerate through folders and files
    $iFolder = 0 #Seed value for foreach loop
    $rootItems = Get-ChildItem $rootDir  #All files and folders in the top level directory given
	foreach ($rootItem in $rootItems) {   #Iterate through all items (files and folders) in given root directory 
        Write-Progress -Id 0 -Activity "Filesystem Snapshot" -Status "Processing $rootItem" -PercentComplete ($iFolder /$rootItems.count * 100); $iFolder++ #Update Progressbar
        foreach ($file in (Get-ChildItem -Path $rootItem.FullName -recurse )) {
            Write-Progress -Id 1 -ParentId 0 -Activity "Filesystem Snapshot" -Status "Processing $file"; #Update Progressbar
            $object = New-Object –TypeName PSObject  #Object to hold information on file/folder
            #$object | Add-Member –MemberType NoteProperty –Name FullPath –Value $file.FullName
            $object | Add-Member –MemberType NoteProperty –Name SHA256          –Value (Get-FileHash $file.FullName -Algorithm SHA256).hash
            $object | Add-Member –MemberType NoteProperty –Name MD5             –Value (Get-FileHash $file.FullName -Algorithm md5   ).hash
            $object | Add-Member –MemberType NoteProperty –Name TimeModifiedUTC –Value $file.LastWriteTimeUtc
            $object | Add-Member –MemberType NoteProperty –Name TimeAccessedUTC –Value $file.LastAccessTimeUtc
            $object | Add-Member –MemberType NoteProperty –Name TimeCreatedUTC  –Value $file.CreationTimeUtc
            $results.Add($file.FullName, $object)
        }
    }

	return ($results,$regresults)
}

function Retrieve-NonMACMetrics {
    param($hash)  #hashtable that contains objects
    return @((($hash.Values[0] | Get-Member -MemberType NoteProperty).name) | Where-Object {$_ -NotLike "Time*"})  #Only get non-time related metrics
}

function Retrieve-MACMetrics {
    param($hash)  #hashtable that contains objects
    return @((($hash.Values[0] | Get-Member -MemberType NoteProperty).name) | Where-Object {$_ -Like "Time*"})  #Only get non-time related metrics
}

function Get-PowerArtifact {
#Diffs hash tabless of snpapshots
    param([hashtable]$hash1, [hashtable]$hash2)	#Hash1 is for the first (before) snapshot. Hash2 is for the second (after) snapshot
    $results = @{}          #Hashtable to hold whats different. Key is the full path, value is an object with only what changed

    $keys=@()  #array to hold all the possible key values
    $keys+=$hash1.Keys
    $keys+=$hash2.Keys
    $keys = $keys | Sort | Get-Unique  #Make it so the array only has one copy of each key 

    #Get all the metrics being recorded. This is done dynamically here for scalability
    $metricNames = Retrieve-NonMACMetrics -hash $hash1  #Only get non-time related metrics

    #Compare
    foreach ($key in $keys) {  #Iterate through all keys
        if($hash1[$key] -notmatch $hash2[$key]) {           
            $object = New-Object –TypeName PSObject  #Object to hold different items
            foreach($metric in $metricNames) {       #Iterate through all the recorded metrics                  

                #Get Metric Values
                $hash1Value = ($hash1[$key]).$metric #Get Hash1's value
                $hash2Value = ($hash2[$key]).$metric #Get Hash2's value

                #Compare Metric Data and save it to the  object
                if($hash1Value -cne $hash2Value) { 
                    #$object | Add-Member –MemberType NoteProperty -name ($metric+'_Before') -value $hash1Value   #The before value. Commented out as this functionality is not needed
                    $object | Add-Member –MemberType NoteProperty -name ($metric)  -value $hash2Value             #The after value
                }
            }
            #Save the results
            $results.Add($key, $object)
        }
    }
    return $results
}


function Artifact-Finder {
    param($Artifacts, $Machine)	
    $results = @{}          #Hashtable to hold whats different. Key is the full path, value is an object with only what changed

    $keys=@()  #array to hold all the possible key values
    $keys+=$Artifacts.Keys
    $keys+=$Machine.Keys
    $keys = $keys | Sort | Get-Unique  #Make it so the array only has one copy of each key 

    #Get all the metrics being recorded. This is done dynamically here for scalability
    $metricNames = Retrieve-NonMACMetrics -hash $Machine #Only get non-time related metrics because a program's MAC time will change for every installation

    #Compare
    foreach ($key in $Artifacts.Keys) {           #Iterate through all keys
        $object = New-Object –TypeName PSObject   #Object to hold found artifacts
        foreach($metric in $metricNames) {        #Iterate through all the recorded metrics not related to MAC Times                 

            #Get Metric Values
            $object | Add-Member –MemberType NoteProperty -name ($metric+'_Artifact') -value ($Artifacts[$key]).$metric
            $object | Add-Member –MemberType NoteProperty -name ($metric+'_Machine')  -value ($Machine[$key]).$metric
        }
        #Add MAC times for Machine
        foreach($metric in (Retrieve-MACMetrics -hash $Machine)) { $object | Add-Member –MemberType NoteProperty -name ($metric+'_Machine')  -value ($Machine[$key]).$metric}

        #Save the results
        $results.Add($key, $object)
    }
    return $results
}

function Get-YesNo {

    param([string]$prompt, [bool]$default)

    $result = $default

    $ans = read-host $prompt
    if($ans.ToUpper() -eq "NO"  -or $ans.ToUpper() -eq "N"){$result = $false}
    if($ans.ToUpper() -eq "YES" -or $ans.ToUpper() -eq "Y"){$result = $true}

    return $result

}


#### MAIN ########

$programName = "EXERunnerPro - PowerShot"
do {
    [string]$choice = -1
    #Prompt user for choice
    Write-Host "Welcome to $programName`n"
    Write-Host "1 - Determine Artifacts for a Program"
    Write-Host "2 - Test for Artifacts on Machine"
    Write-Host "0 - Exit"
    while ($choice -ne 1 -and $choice -ne 2  -and $choice -ne 0  ) { [string]$choice = [string](Read-host "`nPlease enter a 1, 2, or 0") }   #keep asking until user enters a 1, 2 or 0

    $startTime = Get-Date #Debug

    if($choice -eq '1') {  #Take snapshot, install program, take 2nd snapshot, dif snapshots, save the dif
    
        #Prompt user for the name of the progam that will be installed
        $outFile = Read-Host "Please enter program name you will be identifying artifacts for (ex: chrome_ver0.2.149)"

        #Prompt user if he would like to snapshot the registry as well
        $getReg = Get-YesNo -default $false -prompt 'Detect registry changes? (Beta) yes or no [no]'

        #Prompt user for the root dir to being the snapshot on
        $rootDir = Read-Host ('Please enter the top level folder to being the search on [' + ((Get-ChildItem env:homedrive).value) + '\]')
        if ($rootDir -eq "" ) { $rootDir = ((Get-ChildItem env:homedrive).value + '\') }
    
        #Take first snapshot
        Write-Host "DO NOT INSTALL PROGRAM UNTIL SNAPSHOT IS COMPLETE" -ForegroundColor White -BackgroundColor Red 
        ($shot1,$shot1_reg) = Get-PowerShot -rootDir $rootDir -getReg $getReg

        #Prompt user to install the program and to press enter when the program is installed
        Write-Host "`nSnapshot finished, please install $outfile then press enter to continue"; pause
    
        #Get second snapshot for after the program has been installed
        ($shot2,$shot2_reg) = Get-PowerShot -rootDir $rootDir -getReg $getReg

        #Diff the snapshots and save the diffs
        if(!(Test-Path '.\artifacts')) { mkdir '.\artifacts' |Out-Null}
        $artifacts = Get-PowerArtifact -hash1 $shot1 -hash2 $shot2
        $exportPath = ('.\artifacts\' + $outfile + '.xml')
        Write-Host "Exporting to $exportPath"
        $artifacts | Export-Clixml -path $exportPath
        
        #Diff the snapshots for the registries and save the diff
        if ($getReg) {
            $artifacts = Get-PowerArtifact -hash1 $shot1_reg -hash2 $shot2_reg
            $exportPathReg = ('.\artifacts\' + $outfile + "_reg.xml")
            Write-Host "Exporting to $exportPathReg"
            $artifacts | export-clixml -path 
        }
    }

    elseif ($choice -eq 2) {  #Compare Artifact Database to Machine
    
        #Prompt user if he would like to see a list of all xmls he has
        $ans = Get-YesNo -default $false -prompt 'Show available XMLs? [no]'
        if ($ans) {write-host ''; (Get-ChildItem -Path ".\artifacts\*.xml").Name | Format-Table}

        #Get name of program to search for
        $program = Read-Host "`nPlease enter name of program as it appears in the name of the xml file (ex: chrome_ver46.0.2490)"

        #remove extension if user added it
        if($program -like '*.xml') {$artifacts = $artifacts.SubString( 0, ($artifacts.Length-4))}

        #Read in artifact file(s)
        $artifacts    #Initializing variable
        $artifactsReg #Initializing variable
        if( Test-Path ('.\artifacts\' + $artifacts + '.xml' ))     { $artifacts    = Import-Clixml -Path ('.\artifacts\' + $Artifacts + '.xml' )     }
        if( Test-Path ('.\artifacts\' + $artifacts + '_reg.xml' )) { $artifactsReg = Import-Clixml -Path ('.\artifacts\' + $Artifacts + '_reg.xml' ) }

        #Snapshot machine as is
        $getReg = ( Test-Path ('.\artifacts\' + $artifact + '_reg.xml' ))                 #Set the getreg file according to if the reg artifact file ewxists
        ($shot1,$shot1_reg) = get-PowerShot -rootDir $rootDir -getReg $getReg

        #Checks for artifacts on machine. Saves results
        $exportPathBase = ('.\' + $env:computername + '_')
        Artifact-Finder -Artifacts $artifacts -Machine $shot1                        | Export-Clixml -path ($exportPathBase + "_$program" + '.xml')
        if ($getReg) { Artifact-Finder -Artifacts $artifactsReg -Machine $shot1_reg  | Export-Clixml -path ($exportPathBase + "_$program" + '_reg.xml') } 
    }
 

    #Pause at the end to allow user to read
    $endTime = Get-Date #debug
    Write-Host ($endTime - $startTime) #debug
    Write-Host 'Finished'
    pause
    Write-Host "`n"
} while ($choice -ne 0)
