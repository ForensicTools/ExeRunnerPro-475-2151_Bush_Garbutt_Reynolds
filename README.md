# ExeRunnerPro-475-2151_Bush_Garbutt_Reynolds

What EXERunnerPro does:

1) Determine what all artifacts are that left by any program when you install or run it. 
2) Search a computer for that artifacts to determine if and when a program was likely installed/ran.

Workflow:

1) Run the script EXERunnerPro.ps1
2) It takes the first snapshot and saves it to the same directory as the script.
  2a) This is to snapshot exactly what the target computer was like at the time.
  2b) The program will perform an MD5 and SHA1 hash on all files as well as record their MAC times.
  2c) It backs up the registry completely 
2) You install/run a program
  2a) The program will ask you what the name of the program is at this point.
3) It takes the second snapshot and saves it to the same directory as the script.
  3a) For the files and registry this is exactly the same
4) It finds the differences between the two snapshots and saves the differences to the same directory as the script.
  4a) This information will only include what has changed.
  4b) [FUTURE FEATURE] For registries it will add the MAC times as well to help determine a timeline.
5) [FUTURE FEATURE] The output of the program can be visualized showing the data in a more human friendly format

Goals:
1) Be able to use this program to create files which contain all the artifacts of any program
2) Be able to upload these files for a community to use and expand upon
3) Be able to download the artifact file for a program and use it to scan a machine to see if that program was ever on it and if so when.

Technical notes:
* As of 11/13/2015 the registry backup this is done through regedit then read into a custom PS Object
* The file/folder snapshots and the diffs are made using the Export-Clixml and imported using Import-Clixml.
* What is being exported and imported is hashtable whose key is the full path to the file/folder and the value is a custom PS Object of the recorded metrics. 
* As of 11/13/2015 metrics recorded are MD5 Hash, SHA1 Hash, Last Accessed Time, Last Modified Time, Creation Time
* The MAC times are saved in ticks
