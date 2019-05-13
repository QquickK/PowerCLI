# DISCLAIMER: Use this script only on Prod, DEV and BOYDDEV.LOCAL..... See Chuck for Access to BGCDEV.LOCAL ...SKYPE ID : CHARLESWALKER@BOYDGAMING.COM

###############################################################################################################################################
# This script with do the Following:
# Spin up a VM from Templates on the Las Vegas DataCenter:
# Template Clone to VM
# Custom Configuration of the VM: HD, NIC, anyou ad AD Scripting
# Assumption is that you are running this from the Jump Server (LVVDSH001.BOYD.LOCAL)
########################################################## END NOTE ###########################################################################

########################################################## YOUR TARGETS #######################################################################
# ------vCenter Targeting Var & and Conn Commands Below------
# PowerCLI PowerShell Module Will be Loaded
# All Console output.
Get-Module -ListAvailable VMware* | Import-Module


# ------vSphere Target Var tracked below------
$vCenterInstance = "VCENTER FQDN HERE"
$vCenterUser = "VCENTER USER ACCOUNT HERE"
$vCenterPass = "VCENTER PASSWORD HERE"

# This section logs on to the defined vCenter instance above
Connect-VIServer $vCenterInstance -User $vCenterUser -Password $vCenterPass -WarningAction SilentlyContinue 
########################################################### END TARGETING ######################################################################

#############################################-User-Define/Var###################################################################################

# ------Virtual Machine Targeting Variables tracked below------

# define the names of the virtual machines upon deployment, target cluster and the source template
#----------VM Deploy----------
$DomainControllerVMName = "Domain Controller (LV,PGC,DEV,FPP or BOYDDEV)"
$FSVMName = "FS NAME HERE"
$TargetCluster = Get-Cluster -Name "vCenter Cluster Name"
$SourceVMTemplate = Get-Template -Name "SOURCE TEMPLATE IN VCENTER"
$SourceCustomSpec = Get-OSCustomizationSpec -Name "SOURCE CUSTOMIZATION SPEC IN VCENTER"
### (Chuck - Reminder to Self...Speak to DEVOPS to see what other info you need to add....) ###


# ------This section contains commands for def IP/Network settings for new vm's------ 

$DCNetworkSettings = 'netsh interface ip set address "Ethernet0" static x.x.x.x 255.255.255.0 x.x.x.x'
###-Change to suit the ENV. All Boyd Env are /23 where vm's are pushed to-###

### IP/SUB/GTWY ###
$FSNetworkSettings = 'netsh interface ip set address "Ethernet0" static x.x.x.x 255.255.255.0 x.x.x.x'
$FSDNSSettings = 'netsh interface ip set dnsservers name="Ethernet0" static x.x.x.x primary'


# ------Creds for NON Domain VM's------
# 4/21/19 - NOTE: Create a seperate Script for NON Domain... See meeting notes for Refresher

$DCLocalUser = "$DomainControllerVMName\DC LOCAL USER NAME HERE"
$DCLocalPWord = ConvertTo-SecureString -String "DC LOCAL PASSWORD HERE*" -AsPlainText -Force
$DCLocalCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DCLocalUser, $DCLocalPWord

# File Server 
$FSLocalUser = "$FSVMName\FS LOCAL USER NAME HERE"
$FSLocalPWord = ConvertTo-SecureString -String "FS LOCAL PASSWORD HERE" -AsPlainText -Force
$FSLocalCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $FSLocalUser, $FSLocalPWord
$DomainUser = "TESTDOMAIN\administrator"
$DomainPWord = ConvertTo-SecureString -String "Password01" -AsPlainText -Force
$DomainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainUser, $DomainPWord 

# Note: Chuck - Check with Team and have them test this. Not sure if this is right 4/27...
####################################################### END #########################################################################

################################################## Script Execution #################################################################
# ------This Section Contains the Scripts to be executed against new VMs Regardless of Role

# Add new VMs to the domain (domain creds)Add-Computer
$JoinNewDomain = '$DomainUser = "TESTDOMAIN\Administrator";
                  $DomainPWord = ConvertTo-SecureString -String "Password01" -AsPlainText -Force;
                  $DomainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainUser, $DomainPWord;
                  Add-Computer -DomainName TestDomain.lcl -Credential $DomainCredential;
                  Start-Sleep -Seconds 20;
                  Shutdown /r /t 0'

# ------Exe on New DC------

# AD Role Install 
$InstallADRole = 'Install-WindowsFeature -Name "AD-Domain-Services" -Restart'

$ConfigureNewDomain = 'Write-Verbose -Message "Configuring Active Directory" -Verbose;
                       $DomainMode = "Win2016";
                       $ForestMode = "Win2016";
                       $DomainName = "BOYD.LOCAL";
                       $DSRMPWord = ConvertTo-SecureString -String "Password01" -AsPlainText -Force;
                       Install-ADDSForest -ForestMode $ForestMode -DomainMode $DomainMode -DomainName $DomainName -InstallDns -SafeModeAdministratorPassword $DSRMPWord -Force'

#################################################### END ############################################################################


#################################################### Script Execution ###############################################################

# ------New VM(s) using a pre-built template w/customization------
###### 5/2/19 This section I found on VMWARE Flings ----- Need to taylor it a bit more ------------------------------######
# Write-Verbose -Message "Deploying Virtual Machine with Name: [$DomainControllerVMName] using Template: [$SourceVMTemplate] and Customization # Specification: [$SourceCustomSpec] on Cluster: [$TargetCluster] and waiting for completion" -Verbose

# New-VM -Name $DomainControllerVMName -Template $SourceVMTemplate -ResourcePool $TargetCluster -OSCustomizationSpec $SourceCustomSpec

# Write-Verbose -Message "Virtual Machine $DomainControllerVMName Deployed. Powering On" -Verbose

# Start-VM -VM $DomainControllerVMName

# Write-Verbose -Message "Deploying Virtual Machine with Name: [$FSVMName] using Template: [$SourceVMTemplate] and Customization Specification: [$SourceCustomSpec] on Cluster: [$TargetCluster] and waiting for completion" -Verbose

# New-VM -Name $FSVMName -Template $SourceVMTemplate -ResourcePool $TargetCluster -OSCustomizationSpec $SourceCustomSpec

# Write-Verbose -Message "Virtual Machine $FSVMName Deployed. Powering On" -Verbose

# Start-VM -VM $FSVMName
################# Research this. Something is erroring out 5/4/19 #################


##################################################### DOMAIN CONTROLLERS #####################################################################
# ------This Section Targets and Executes the Scripts on the New Domain Controller Guest VM------

#-----------First verify that the guest customization has finished.---------------
Write-Verbose -Message "Verifying that Customization for VM $DomainControllerVMName has started ..." -Verbose
	while($True)
	{
		$DCvmEvents = Get-VIEvent -Entity $DomainControllerVMName 
		$DCstartedEvent = $DCvmEvents | Where { $_.GetType().Name -eq "CustomizationStartedEvent" }
 
		if ($DCstartedEvent)
		{
			break	
		}

		else 	
		{
			Start-Sleep -Seconds 5
		}
	}

Write-Verbose -Message "Customization of VM $DomainControllerVMName has started. Checking for Completed Status......." -Verbose
	while($True)
	{
		$DCvmEvents = Get-VIEvent -Entity $DomainControllerVMName 
		$DCSucceededEvent = $DCvmEvents | Where { $_.GetType().Name -eq "CustomizationSucceeded" }
        $DCFailureEvent = $DCvmEvents | Where { $_.GetType().Name -eq "CustomizationFailed" }
 
		if ($DCFailureEvent)
		{
			Write-Warning -Message "Customization of VM $DomainControllerVMName failed" -Verbose
            return $False	
		}

		if ($DCSucceededEvent) 	
		{
            break
		}
        Start-Sleep -Seconds 5
	}
Write-Verbose -Message "Customization of VM $DomainControllerVMName Completed Successfully!" -Verbose

# NOTE - The below Sleep command is to help prevent situations where the post customization reboot is delayed slightly causing

Start-Sleep -Seconds 30

Write-Verbose -Message "Waiting for VM $DomainControllerVMName to complete post-customization reboot." -Verbose

Wait-Tools -VM $DomainControllerVMName -TimeoutSeconds 300

# NOTE - Another short sleep here to make sure that other services have time to come up after VMware Tools are ready. 
Start-Sleep -Seconds 30


# NOTE - The Below Sleep Command is due to it taking a few seconds for VMware Tools to read the IP Change so that we can return the below output. 
# This is strctly informational and can be commented out if needed, but it's helpful when you want to verify that the settings defined above have been 
# applied successfully within the VM. We use the Get-VM command to return the reported IP information from Tools at the Hypervisor Layer. 
Start-Sleep 30
$DCEffectiveAddress = (Get-VM $DomainControllerVMName).guest.ipaddress[0]
Write-Verbose -Message "Assigned IP for VM [$DomainControllerVMName] is [$DCEffectiveAddress]" -Verbose

# Install the AD Role and configure the new domain
Write-Verbose -Message "Getting Ready to Install Active Directory Services on $DomainControllerVMName" -Verbose

Invoke-VMScript -ScriptText $InstallADRole -VM $DomainControllerVMName -GuestCredential $DCLocalCredential

Write-Verbose -Message "Configuring New AD Forest on $DomainControllerVMName" -Verbose

Invoke-VMScript -ScriptText $ConfigureNewDomain -VM $DomainControllerVMName -GuestCredential $DCLocalCredential

Start-Sleep -Seconds 60

Wait-Tools -VM $DomainControllerVMName -TimeoutSeconds 300

Write-Verbose -Message "Installation of Domain Services and Forest Provisioning on $DomainControllerVMName Complete" -Verbose

Write-Verbose -Message "Adding new administative user account to domain" -Verbose

Invoke-VMScript -ScriptText $NewAdminUser -VM $DomainControllerVMName -GuestCredential $DomainCredential

# ------This Section Targets and Executes the Scripts on the New FS VM.

# Just like the DC VM, we have to first modify the IP Settings of the VM
Write-Verbose -Message "Getting ready to change IP Settings on VM $FSVMName." -Verbose
Invoke-VMScript -ScriptText $FSNetworkSettings -VM $FSVMName -GuestCredential $FSLocalCredential
Invoke-VMScript -ScriptText $FSDNSSettings -VM $FSVMName -GuestCredential $FSLocalCredential

# NOTE - The Below Sleep Command is due to it taking a few seconds for VMware Tools to read the IP Change so that we can return the below output. 
###### 5/10/2019 Chuck - Test to see if this is nessesary. VRA is not liking this #########

Start-Sleep 30
$FSEffectiveAddress = (Get-VM $FSVMName).guest.ipaddress[0]
Write-Verbose -Message "Assigned IP for VM [$FSVMName] is [$FSEffectiveAddress]" -Verbose 

# The Below Cmdlets actually add the VM to the newly deployed domain. 
Invoke-VMScript -ScriptText $JoinNewDomain -VM $FSVMName -GuestCredential $FSLocalCredential

# Below sleep command is in place as the reboot needed from the above command doesn't always happen before the wait-tools command is run
Start-Sleep -Seconds 60

Wait-Tools -VM $FSVMName -TimeoutSeconds 300

Write-Verbose -Message "VM $FSVMName Added to Domain and Successfully Rebooted." -Verbose

Write-Verbose -Message "Installing File Server Role and Creating File Share on $FSVMName." -Verbose

# The below commands actually execute the script blocks defined above to install the file server role and then configure the new file share. 
Invoke-VMScript -ScriptText $InstallFSRole -VM $FSVMName -GuestCredential $DomainCredential

Invoke-VMScript -ScriptText $NewFileShare -VM $FSVMName -GuestCredential $DomainCredential

Write-Verbose -Message "Environment Setup Complete" -Verbose

####################################################### END SCRIPT #############################################################

### 5/10/19 ############################################### NOTES: #############################################################
### Note to Self: We need to add custom deployment of the different Golden Templates for server 2016/2019. 
###               You also need to work on scripts to do clean up of falied VM's and Add Domain authentication with Ad Groups
###               To prevent unauthorized usage of this script. 
########################################################End NOTES ##############################################################
# End of Script