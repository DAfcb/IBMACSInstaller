# IBMACSInstaller
A scripted managed installer for IBM Access Client Solutions
This is a script built with the PowerShell Application Deployment Toolkit. You'll need to get that product seperately. You'll also need to download the IBM ACS install package as a zip file. This script only provides an install for Windows systems. It will copy the ACS files locally to the system and then create all the various registry keys so that the product is populated into Programs and Features where most RMM products will grab inventory.

Step 1 - Copy over your basic PSADT folders/file structure. Go read up on PSADT if you have never used it.
  AppdeployToolkit
  Files
  Deploy-Application.exe
  Deploy-Application.exe.config
  Deploy-Application.ps1  <- this is the file that we will replace with the script

Step 2 - Copy the IBM folders/files into the above listed "Files" folder
  Documentation
  Icons
  Start_Programs
  Windows_Application
  acsbundle.jar
  AcsConfig.properties
  QuickStartGuide.html

Step 3 - copy the script posted in this repository as your Deploy-Application.ps1, edit as needed

Step 4- Run Deploy-Application.exe as your install command
