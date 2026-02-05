<#

.SYNOPSIS
PSAppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION
- The script is provided as a template to perform an install, uninstall, or repair of an application(s).
- The script either performs an "Install", "Uninstall", or "Repair" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

PSAppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2025 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham, Muhammad Mashwani, Mitch Richters, Dan Gough).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType
The type of deployment to perform.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive (shows dialogs), Silent (no dialogs), or NonInteractive (dialogs without prompts) mode.

NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru
Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -AllowRebootPassThru

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Invoke-AppDeployToolkit.ps1, and Invoke-AppDeployToolkit.exe
- 69000 - 69999: Recommended for user customized exit codes in Invoke-AppDeployToolkit.ps1
- 70000 - 79999: Recommended for user customized exit codes in PSAppDeployToolkit.Extensions module.

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [PSDefaultValue(Help = 'Install', Value = 'Install')]
    [System.String]$DeploymentType,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [PSDefaultValue(Help = 'Interactive', Value = 'Interactive')]
    [System.String]$DeployMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AllowRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor = 'IBM'
    AppName = 'i Access Client Solutions'
    AppVersion = '1.1.9.8'
    AppArch = ''
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppScriptVersion = '1.0.0'
    AppScriptDate = '2025-4-17'
    AppScriptAuthor = 'Dennis Abbottt'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ''
    InstallTitle = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptVersion = '4.0.6'
    DeployAppScriptParameters = $PSBoundParameters
}

function Install-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt.
Show-ADTInstallationWelcome -CloseProcesses @{ Name = 'javaw' }, @{ Name = 'java' },  @{ Name = 'acslaunch_win-64' } -PersistPrompt

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Installation tasks here>
		$RundllProcs = Get-CimInstance Win32_Process -Filter "name = 'rundll32.exe'" | select CommandLine, ProcessId
		foreach($RundllProc in $RundllProcs)
		{
			If ($RundllProc -like '*acsnative.dll*')
			{
			Stop-Process -id $RundllProc.ProcessId -Force
			}
		} 

        ##Clean up rogue installs of IBM ACS

        Remove-ADTFolder -Path "$env:PUBLIC\IBM\ClientSolutions" -ErrorAction SilentlyContinue 
        Remove-ADTFolder -Path "C:\ProgramData\IBM_ACS" -ErrorAction SilentlyContinue 
        
        [string[]]$ProfilePaths = Get-ADTUserProfiles | Select-Object -ExpandProperty 'ProfilePath'
        ForEach ($PP in $ProfilePaths)
        {
        Remove-ADTFolder -Path "$PP\IBM\ClientSolutions" -ErrorAction SilentlyContinue 
        Remove-ADTFile -Path "$PP\Desktop\Access Client Solutions.lnk" -ErrorAction SilentlyContinue 
        Remove-ADTFile -Path "$PP\Desktop\ACS Session Mgr.lnk" -ErrorAction SilentlyContinue 
        }


    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI installations.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
        if ($adtSession.DefaultMspFiles)
        {
            $adtSession.DefaultMspFiles | Start-ADTMsiProcess -Action Patch
        }
    }

    ## <Perform Installation tasks here>
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
		Copy-ADTFile -Path "$PsScriptRoot\Files\*" -Destination "$env:PUBLIC\IBM\ClientSolutions\" -Recurse -ErrorAction SilentlyContinue 

		# Create shortcuts
		New-ADTShortcut -Path "$env:ProgramData\Microsoft\Windows\Start Menu\IBM i Access Client Solutions\Access Client Solutions.lnk" -TargetPath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Description "IBM i Access Client Solutions" -Hotkey "CTRL+ALT+SHIFT+A" -IconLocation "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -IconIndex "0" -WorkingDirectory "$env:PUBLIC\IBM\ClientSolutions\"
		New-ADTShortcut -Path "$env:ProgramData\Microsoft\Windows\Start Menu\IBM i Access Client Solutions\ACS Session Mgr.lnk" -TargetPath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Arguments "/plugin=sm" -Description "IBM i Access Client Solutions - Session Manager" -Hotkey "CTRL+ALT+SHIFT+B" -IconLocation "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -IconIndex "5" -WorkingDirectory "$env:PUBLIC\IBM\ClientSolutions\"
        New-ADTShortcut -Path "$env:ProgramData\Microsoft\Windows\Start Menu\IBM i Access Client Solutions\RegisterAssociations.lnk" -TargetPath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Arguments "-Dcom.ibm.iaccess.AcceptEndUserLicenseAgreement=true /PLUGIN=fileassoc dttx dtfx hod bchx ws" -Description "Repair file associations IBM i Client Access Solutions" -IconLocation "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -IconIndex "1" -WorkingDirectory "$env:PUBLIC\IBM\ClientSolutions\"
        #New-Shortcut -Path "$env:PUBLIC\Public Desktop\Cardinal FCB.lnk" -TargetPath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Arguments "$env:PUBLIC\IBM\ClientSolutions\fcbt.hod" -Description "IBM i Access Client Solutions - Session Manager" -Hotkey "CTRL+ALT+SHIFT+B" -IconLocation "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -IconIndex "0" -WorkingDirectory "$env:PUBLIC\IBM\ClientSolutions\"
        
        $ACSInstallDate = '{0:yyyyMMdd}' -f (get-date)
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'Comments' -Value $adtSession.AppName -Type String
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'DisplayIcon' -Value "C:\Users\Public\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe,0" -Type String		
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'DisplayName' -Value $adtSession.AppName -Type String
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'DisplayVersion' -Value $adtSession.appVersion -Type String
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'EstimatedSize' -Value 140000 -Type DWord
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'HelpLink' -Value "https://farmcreditbank.service-now.com/sp" -Type String
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'InstallDate' -Value $ACSInstallDate -Type String
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'InstallLocation' -Value "$env:PUBLIC\IBM\ClientSolutions\" -Type String
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'InstallSource' -Value $PSScriptRoot -Type String
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'Language' -Value 409 -Type DWord
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'NoModify' -Value 1 -Type DWord
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'NoRepair' -Value 1 -Type DWord
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'Publisher' -Value $adtSession.appVendor -Type String
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'UninstallString' -Value '"C:\WINDOWS\CCM\ClientUX\SCClient.exe" softwarecenter:' -Type String
		Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -Name 'URLUpdateInfo' -Value "https://www.ibm.com/support/pages/ibm-i-access-acs-updates" -Type String


    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>
 # Accept EULA
        #Execute-Process -Path "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -Parameters "-Dcom.ibm.iaccess.AcceptEndUserLicenseAgreement=true /PLUGIN=fileassoc dttx dtfx hod bchx ws" -Wait
       	# Register file associations
		Start-ADTProcessAsUser -FilePath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -ArgumentList "-Dcom.ibm.iaccess.AcceptEndUserLicenseAgreement=true /PLUGIN=fileassoc dttx dtfx hod bchx ws" -Wait

        #Lock down preferences
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'ids_prgid' -Value '0.5159636125800808' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'cfg' -Value 'u' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'sm' -Value 'u' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'pm5250' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'vcp' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'console' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'consoleprobe' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'hmcprobe' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'hmi1' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'hmi2' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'asmi' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'csmi' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'db2mirror' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'dcm' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'dshmc' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'hmc' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'ivm' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'specctrl' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'tapemgmt1' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'httpadmin' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'tapemgmt2' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'are' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'db2webquery' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'keyman' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'dtgui' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'upload' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'download' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'cldownload' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'l1c' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'rmtcmd' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'splf' -Value 'u' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'rss' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'db2tools' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'db2' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'sysdbg' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'ifs' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'checkupdates' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'installupdates' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'ssh' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'osssetup' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'httpproxyui' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name 'restrictview' -Value 'r' -Type String
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -Name '5250' -Value 'u' -Type String

		#Set Use Legacy Console to avoid Windows Terminal popping up when you run the application
		$LoggedOnuser = Get-ADTLoggedOnUser
		If ($LoggedOnuser.IsConsoleSession)
		{
		Set-ADTRegistryKey -Key 'HKCU\Console' -Name 'ForceV2' -Value 0 -Type DWord -SID $LoggedOnuser.SID 
		}

    ## Display a message at the end of the install.
    if (!$adtSession.UseDefaultMsi)
    {
        Show-ADTInstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait
    }
}

function Uninstall-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    Show-ADTInstallationWelcome -CloseProcesses iexplore -CloseProcessesCountdown 60

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Uninstallation tasks here>


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI uninstallations.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Uninstallation tasks here>
	# Unregister file associations
		Start-ADTProcessAsUser -FilePath "$env:PUBLIC\IBM\ClientSolutions\Start_Programs\Windows_x86-64\acslaunch_win-64.exe" -ArgumentList "-norecurse /PLUGIN=fileassoc dttx dtfx hod bchx ws /c" -Wait
		Start-Sleep -Seconds 10
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
		Remove-ADTFolder -Path "$env:PUBLIC\IBM\ClientSolutions" -ErrorAction SilentlyContinue 
        
		#Remove shortcuts
		Remove-ADTFolder -Path "$env:ProgramData\Microsoft\Windows\Start Menu\IBM i Access Client Solutions" -ErrorAction SilentlyContinue 

        Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IBMIAccessClientSolutions' -ErrorAction SilentlyContinue 
        Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\JavaSoft\prefs\com\ibm\iaccess\base\restrictions' -ErrorAction SilentlyContinue 

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>
}

function Repair-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    Show-ADTInstallationWelcome -CloseProcesses iexplore -CloseProcessesCountdown 60

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Repair tasks here>


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI repairs.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Repair tasks here>


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    $moduleName = if ([System.IO.File]::Exists("$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"))
    {
        Get-ChildItem -LiteralPath $PSScriptRoot\PSAppDeployToolkit -Recurse -File | Unblock-File -ErrorAction Ignore
        "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
    }
    else
    {
        'PSAppDeployToolkit'
    }
    Import-Module -FullyQualifiedName @{ ModuleName = $moduleName; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.6' } -Force
    try
    {
        $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
        $adtSession = Open-ADTSession -SessionState $ExecutionContext.SessionState @adtSession @iadtParams -PassThru
    }
    catch
    {
        Remove-Module -Name PSAppDeployToolkit* -Force
        throw
    }
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

try
{
    Get-Item -Path $PSScriptRoot\PSAppDeployToolkit.* | & {
        process
        {
            Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
            Import-Module -Name $_.FullName -Force
        }
    }
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    Write-ADTLogEntry -Message ($mainErrorMessage = Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3
    Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop | Out-Null
    Close-ADTSession -ExitCode 60001
}
finally
{
    Remove-Module -Name PSAppDeployToolkit* -Force
}

