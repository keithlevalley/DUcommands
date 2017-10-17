<#
.Synopsis
   Sets the SCCM Provisioning Mode to on or off
.DESCRIPTION
   SCCM Provisioning Mode is turned on when changes are made to SCCM, during this time SCCM will not work.  Occassionally SCCM will get stuck in Provisioning mode on the local machine, causing deployments to not go through.  To resolve this you can use this command to manually switch provisioning mode off.
.EXAMPLE
   Set-DUProvisioningMode -Set Start -ComputerName TestPC

   The above command will start provisioning mode for remote machine "TestPC"
.EXAMPLE
   Set-DUProvisioningMode -Set Stop -ComputerName TestPC

   The above command will stop provisioning mode for remote machine "TestPC"
.EXAMPLE
   Set-DUProvisioningMode -Set Stop

   The above command will stop provisioning mode for the local machine
#>
function Set-DUProvisioningMode
{
    Param
    (
        # Defines what action to run
        [Parameter(Mandatory=$true,
                    Position=0)]
        [ValidateSet("Start","Stop")]
        [String]$Set,

        # Name of the machine to run the command on.  Default option is local machine
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [String[]]
        $ComputerName="localhost"
    )

    [bool]$run

    if ($Set -eq "Start"){$run = $true}
    elseif ($Set -eq "Stop"){$run = $false}
    else {throw [Exception]("Set variable is outside if validation set: $Set")}

    Invoke-WmiMethod -Namespace "root\ccm" -Class "SMS_Client" -Name "SetClientProvisioningMode" -ComputerName $ComputerName -ArgumentList $run
}

<#
.Synopsis
   Returns basic computer information from a remote machine
.DESCRIPTION
   Uses Invoke-Command to gather information from a remote machine and returns it as a custom PS object.
.EXAMPLE
   Get-DUComputerInfo -ComputerName TestPC

   The above command will return basic information for remote machine "TestPC"
.EXAMPLE
   Get-DUComputerInfo -ComputerName TestPC

   The above command will return basic information for the local machine
#>
function Get-DUComputerInfo
{
    Param
    (
        # Name of the machine to run the command on.  Default option is local machine
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [String[]]
        $ComputerName="localhost"
    )

        return Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        $wmiObjectBios = Get-WmiObject -Class win32_bios
        $wmiObjectPC = Get-WmiObject -Class win32_computersystem
        $wmiObjectNetwork = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.Ipaddress.length -gt 1}
        $wmiObjectOS = Get-WmiObject win32_OperatingSystem
        $wmiObjectHD = Get-WmiObject win32_logicaldisk | Where-Object {$_.DeviceID -eq "C:"}

        $value = New-Object System.Object
        $value | Add-Member -type NoteProperty -name ComputerName -value $env:COMPUTERNAME
        $value | Add-Member -type NoteProperty -name SerialNumber -value $wmiObjectBios.SerialNumber
        $value | Add-Member -type NoteProperty -name BiosVersion -value  $wmiObjectBios.Version
        $value | Add-Member -type NoteProperty -name Domain -value $wmiObjectPC.Domain
        $value | Add-Member -type NoteProperty -name Ipv4 -Value ($wmiObjectNetwork.IPAddress[0])
        $value | Add-Member -type NoteProperty -name MACAddress -Value ($wmiObjectNetwork.MACAddress)
        $value | Add-Member -type NoteProperty -name OSVersion -Value ($wmiObjectOS.Version)
        $value | Add-Member -type NoteProperty -name HDCapacity -Value (([int]($wmiObjectHD.Size / 1073741824)).ToString() + "GB")
        $value | Add-Member -type NoteProperty -name HDFreeSpace -Value (([int]($wmiObjectHD.FreeSpace / 1073741824)).ToString() + "GB")
        return $value
        
    } | Select-Object -Property ComputerName, SerialNumber, BiosVersion, Domain, Ipv4, MACAddress, OSVersion, HDCapacity, `
            HDFreeSpace
}

<#
.Synopsis
   Starts the requested SCCM task on the remote machine
.DESCRIPTION
   Uses the WMI Method to invoke the requested SCCM task on a remote machine.
.EXAMPLE
   Start-DUSCCMTask -Task ApplicationDeploymentEvaluationCycle -ComputerName TestPC

   The above command will start the "ApplicationDeploymentEvaluationCycle" on remote PC TestPC
.EXAMPLE
   Start-DUSCCMTask -Task ApplicationDeploymentEvaluationCycle

   The above command will start the "ApplicationDeploymentEvaluationCycle" on the local machine
#>
function Start-DUSCCMTask
{
    Param
    (
        # Name of the task to run
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$false,
                   Position=0)]
        [ValidateSet("ApplicationDeploymentEvaluationCycle",
                        "DiscoveryDataCollectionCycle",
                        "FileCollectionCycle",
                        "HardwareInventoryCycle",
                        "MachinePolicyRetrievalCycle",
                        "MachinePolicyEvaluationCycle",
                        "SoftwareInventoryCycle",
                        "SoftwareMeteringUsageReportCycle",
                        "SoftwareUpdateDeploymentEvaluationCycle",
                        "SoftwareUpdateScanCycle",
                        "StateMessageRefresh",
                        "UserPolicyEvaluationCycle",
                        "WindowsInstallersSourceListUpdateCycle")]
        [String]
        $Task,

        # Name of the PC to run the command on, default is localhost
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [String[]]
        $ComputerName="localhost"
    )

    $BinaryCMD = ""

    switch ($Task)
    {
        "ApplicationDeploymentEvaluationCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000121}"}
        "DiscoveryDataCollectionCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000003}"}
        "FileCollectionCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000010}"}
        "HardwareInventoryCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000001"}
        "MachinePolicyRetrievalCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000021}"}
        "MachinePolicyEvaluationCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000022}"}
        "SoftwareInventoryCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000002}"}
        "SoftwareMeteringUsageReportCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000031}"}
        "SoftwareUpdateDeploymentEvaluationCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000114}"}
        "SoftwareUpdateScanCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000113}"}
        "StateMessageRefresh" {$BinaryCMD = "{00000000-0000-0000-0000-000000000111}"}
        "UserPolicyEvaluationCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000027}"}
        "WindowsInstallersSourceListUpdateCycle" {$BinaryCMD = "{00000000-0000-0000-0000-000000000032}"}
        Default {throw [Exception]("$Task : logic fell through switch statement")}
    }

    Invoke-WMIMethod -ComputerName $ComputerName -Namespace root\ccm -Class SMS_CLIENT `
        -Name TriggerSchedule $BinaryCMD
}
