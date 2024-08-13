<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'IBM'
	[string]$appName = 'I Access Client Solutions'
	[string]$appVersion = '1.1.9.6'
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.1.0'
	[string]$appScriptDate = '8/13/2024'
	[string]$appScriptAuthor = ''
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps 'acslaunch_win-64' -AllowDeferCloseApps -DeferTimes 3 -PersistPrompt -MinimizeWindows $false

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>
		#Get-ChildItem -Path $dirFiles -Recurse | ForEach-Object { Unblock-File $_.FullName }
		#kill off open handle to acsnative.dll
		$RundllProcs = Get-CimInstance Win32_Process -Filter "name = 'rundll32.exe'" | select CommandLine, ProcessId
		foreach($RundllProc in $RundllProcs)
		{
			If ($RundllProc -like '*acsnative.dll*')
			{
			Stop-Process -id $RundllProc.ProcessId -Force
			}
		} 

        ##Clean up rogue installs of IBM ACS

        Remove-Folder -Path "$env:PUBLIC\IBM\ClientSolutions" -ContinueOnError $true
        Remove-Folder -Path "C:\ProgramData\IBM_ACS" -ContinueOnError $true
        
        [string[]]$ProfilePaths = Get-UserProfiles | Select-Object -ExpandProperty 'ProfilePath'
        ForEach ($PP in $ProfilePaths)
        {
        Remove-Folder -Path "$PP\IBM\ClientSolutions" -ContinueOnError $true
        Remove-File -Path "$PP\Desktop\Access Client Solutions.lnk" -ContinueOnError $true
        Remove-File -Path "$PP\Desktop\ACS Session Mgr.lnk" -ContinueOnError $true
        }




		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
		# You don't need to include all the files from the IBM package, here's the bare minimum folder structure:
		# Files
		# - Start_Programs
		# -- Windows_x86-64
		# --- acslaunch_win-64.exe
		# --- acsnative.dll
		# --- acspcoc.exe
		# - acsbundle.jar
		# - AcsConfig.properties
		Copy-File -Path "$dirFiles\*" -Destination "$env:PUBLIC\IBM\ClientSolutions\" -Recurse -ContinueFileCopyOnError $true

		# Create shortcuts
		New-Shortcut -Path "$env:ProgramData\Microsoft\Windows\Start Menu\IBM i Access Client Solutions\Access Client Solutions.lnk" -TargetPath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Description "IBM i Access Client Solutions" -Hotkey "CTRL+ALT+SHIFT+A" -IconLocation "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -IconIndex "0" -WorkingDirectory "$env:PUBLIC\IBM\ClientSolutions\"
		New-Shortcut -Path "$env:ProgramData\Microsoft\Windows\Start Menu\IBM i Access Client Solutions\ACS Session Mgr.lnk" -TargetPath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Arguments "/plugin=sm" -Description "IBM i Access Client Solutions - Session Manager" -Hotkey "CTRL+ALT+SHIFT+B" -IconLocation "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -IconIndex "5" -WorkingDirectory "$env:PUBLIC\IBM\ClientSolutions\"
        New-Shortcut -Path "$env:ProgramData\Microsoft\Windows\Start Menu\IBM i Access Client Solutions\RegisterAssociations.lnk" -TargetPath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Arguments "-Dcom.ibm.iaccess.AcceptEndUserLicenseAgreement=true /PLUGIN=fileassoc dttx dtfx hod bchx ws" -Description "Repair file associations IBM i Client Access Solutions" -IconLocation "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -IconIndex "1" -WorkingDirectory "$env:PUBLIC\IBM\ClientSolutions\"
        #New-Shortcut -Path "$env:PUBLIC\Public Desktop\Cardinal FCB.lnk" -TargetPath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Arguments "$env:PUBLIC\IBM\ClientSolutions\fcbt.hod" -Description "IBM i Access Client Solutions - Session Manager" -Hotkey "CTRL+ALT+SHIFT+B" -IconLocation "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -IconIndex "0" -WorkingDirectory "$env:PUBLIC\IBM\ClientSolutions\"
        
        $ACSInstallDate = '{0:yyyyMMdd}' -f (get-date)
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'Comments' -Value $appName -Type String
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'DisplayIcon' -Value "C:\Users\Public\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe,0" -Type String		
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'DisplayName' -Value $appName -Type String
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'DisplayVersion' -Value $appVersion -Type String
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'EstimatedSize' -Value 140000 -Type DWord
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'HelpLink' -Value "https://www.ibm.com/support/pages/ibm-i-access-acs-updates" -Type String
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'InstallDate' -Value $ACSInstallDate -Type String
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'InstallLocation' -Value "$env:PUBLIC\IBM\ClientSolutions\" -Type String
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'InstallSource' -Value $PSScriptRoot -Type String
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'Language' -Value 409 -Type DWord
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'NoModify' -Value 1 -Type DWord
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'NoRepair' -Value 1 -Type DWord
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'Publisher' -Value $appVendor -Type String
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'UninstallString' -Value '"C:\WINDOWS\CCM\ClientUX\SCClient.exe" softwarecenter:' -Type String
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'URLUpdateInfo' -Value "https://www.ibm.com/support/pages/ibm-i-access-acs-updates" -Type String

        ##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
        
        # Accept EULA
        #Execute-Process -Path "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Parameters "-Dcom.ibm.iaccess.AcceptEndUserLicenseAgreement=true /PLUGIN=fileassoc dttx dtfx hod bchx ws" -Wait
       	# Register file associations
		Execute-ProcessAsUser -Path "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Parameters "-Dcom.ibm.iaccess.AcceptEndUserLicenseAgreement=true /PLUGIN=fileassoc dttx dtfx hod bchx ws" -Wait

        #Lock down preferences
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'ids_prgid' -Value '0.5159636125800808' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'cfg' -Value 'u' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'sm' -Value 'u' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'pm5250' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'vcp' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'console' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'consoleprobe' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'hmcprobe' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'hmi1' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'hmi2' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'asmi' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'csmi' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'db2mirror' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'dcm' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'dshmc' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'hmc' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'ivm' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'specctrl' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'tapemgmt1' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'httpadmin' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'tapemgmt2' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'are' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'db2webquery' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'keyman' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'dtgui' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'upload' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'download' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'cldownload' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'l1c' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'rmtcmd' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'splf' -Value 'u' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'rss' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'db2tools' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'db2' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'sysdbg' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'ifs' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'checkupdates' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'installupdates' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'ssh' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'osssetup' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'httpproxyui' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'restrictview' -Value 'r' -Type String
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name '5250' -Value 'u' -Type String

		#Set Use Legacy Console to avoid Windows Terminal popping up when you run the application
		$LoggedOnuser = Get-LoggedOnUser
		If ($LoggedOnuser.IsConsoleSession)
		{
		Set-RegistryKey -Key 'HKCU\Console' -Name 'ForceV2' -Value 0 -Type DWord -SID $LoggedOnuser.SID 
		}
		
		                 

		## Display a message at the end of the install
		#If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'acslaunch_win-64' -AllowDeferCloseApps -DeferTimes 3 -PersistPrompt -MinimizeWindows $false

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>
		# Unregister file associations
		Execute-ProcessAsUser -Path "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Parameters "-norecurse /PLUGIN=fileassoc dttx dtfx hod bchx ws /c" -Wait
		#kill off open handle to acsnative.dll
		$RundllProcs = Get-CimInstance Win32_Process -Filter "name = 'rundll32.exe'" | select CommandLine, ProcessId
		foreach($RundllProc in $RundllProcs)
		{
			If ($RundllProc -like '*acsnative.dll*')
			{
			Stop-Process -id $RundllProc.ProcessId -Force
			}
		} 
		#Remove folder
		Remove-Folder -Path "$env:PUBLIC\IBM\ClientSolutions" -ContinueOnError $true
        
		#Remove shortcuts
		Remove-Folder -Path "$env:ProgramData\Microsoft\Windows\Start Menu\IBM i Access Client Solutions" -ContinueOnError $true

        Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions'
        Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions'

		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
