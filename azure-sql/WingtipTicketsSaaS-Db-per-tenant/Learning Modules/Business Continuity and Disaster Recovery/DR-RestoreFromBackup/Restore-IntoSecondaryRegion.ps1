<#
.SYNOPSIS
  Restores the Wingtip SaaS app environment into a secondary region 

.DESCRIPTION
  This script recovers the Wingtip SaaS app environment (apps, databases, servers e.t.c) into a secondary recovery region.
  It uses Azure ARM templates in addition to the geo-restore capability of SQL databases to recover tenant and app resources for the Wingtip SaaS app.

.PARAMETER NoEcho
  This stops the output of the signed in user to prevent double echo of subscription details

.PARAMETER StatusCheckTimeInterval
  This determines how often the script will check on the status of background recovery jobs. The script will wait the provided time in seconds before checking the status again.

.EXAMPLE
  [PS] C:\>.\Restore-IntoSecondaryRegion.ps1
#>
[cmdletbinding()]
param (
    
    # NoEcho stops the output of the signed in user to prevent double echo  
    [parameter(Mandatory=$false)]
    [switch] $NoEcho,

    [parameter(Mandatory=$false)]
    [Int] $StatusCheckTimeInterval = 10
)

#----------------------------------------------------------[Initialization]----------------------------------------------------------

Import-Module $PSScriptRoot\..\..\Common\CatalogAndDatabaseManagement -Force
Import-Module $PSScriptRoot\..\..\Common\FormatJobOutput -Force
Import-Module $PSScriptRoot\..\..\WtpConfig -Force
Import-Module $PSScriptRoot\..\..\UserConfig -Force

# Get deployment configuration  
$wtpUser = Get-UserConfig
$config = Get-Configuration

# Get Azure credentials if not already logged on
$credentialLoad = Import-AzureRmContext -Path "$env:TEMP\profile.json"
if (!$credentialLoad)
{
    Initialize-Subscription -NoEcho:$NoEcho.IsPresent
}
else
{
  $AzureContext = Get-AzureRmContext
  $subscriptionId = Get-SubscriptionId
  $subscriptionName = Get-SubscriptionName
  Write-Output "Signed-in as $($AzureContext.Account), Subscription '$($subscriptionId)' '$($subscriptionName)'"    
}

# Get location of primary region
$primaryLocation = (Get-AzureRmResourceGroup -ResourceGroupName $wtpUser.ResourceGroupName).Location

# Use paired Azure region as recovery region (more info: https://docs.microsoft.com/azure/best-practices-availability-paired-regions)
# Note: An optimization that can be applied here would be to instead pass in a priority list of regions. This will allow recovery to continue if the paired region does not have enough capacity.
$content = Get-Content "$PSScriptRoot\..\..\Utilities\AzurePairedRegions.txt" | Out-String
$regionPairs = Invoke-Expression $content
$recoveryLocation = $regionPairs.Item($primaryLocation)
$currentSubscriptionId = Get-SubscriptionId
$recoveryResourceGroupName = $wtpUser.ResourceGroupName + $config.RecoveryRoleSuffix
$recoveryCatalogServerName = $config.CatalogServerNameStem + $wtpUser.Name + $config.RecoveryRoleSuffix 
$originCatalogServerName = $config.CatalogServerNameStem + $wtpUser.Name

#-------------------------------------------------------[Main Script]------------------------------------------------------------

$startTime = Get-Date

Write-Output "Original region: $primaryLocation,  Recovery region: $recoveryLocation"

# Disable traffic manager web app endpoint in primary region (idempotent)
Write-Output "Disabling Traffic Manager endpoint in origin region ..."
$profileName = $config.EventsAppNameStem + $wtpUser.Name
$webAppEndpoint = $config.EventsAppNameStem + $primaryLocation + '-' + $wtpUser.name
Disable-AzureRmTrafficManagerEndpoint -Name $webAppEndpoint -Type AzureEndpoints -ProfileName $profileName -ResourceGroupName $wtpUser.ResourceGroupName -Force -ErrorAction SilentlyContinue > $null

try
{
  # Get catalog database if it exists in the recovery region
  $catalogDatabase = Get-AzureRmSqlDatabase `
                        -ResourceGroupName $recoveryResourceGroupName `
                        -ServerName $recoveryCatalogServerName `
                        -DatabaseName $config.CatalogDatabaseName `
                        -ErrorAction Stop   
  
  Write-Output "Catalog database already restored in recovery region..." 

  # Check if catalog database in recovery region is a replica
  $replicationLink = Get-AzureRmSqlDatabaseReplicationLink `
                        -ResourceGroupName $recoveryResourceGroupName `
                        -ServerName $recoveryCatalogServerName `
                        -DatabaseName $config.CatalogDatabaseName `
                        -PartnerResourceGroupName $wtpUser.ResourceGroupName `
                        -ErrorAction SilentlyContinue
  if ($replicationLink -and ($replicationLink.Role -eq "Secondary"))
  {
    Write-Output "Catalog database is detected to be a replica. Failing over catalog database to recovery region..."
    $catalogFailoverGroupName = $config.CatalogFailoverGroupNameStem + $wtpUser.Name
      
    # Failover catalog database to recovery region
    Switch-AzureRmSqlDatabaseFailoverGroup `
      -ResourceGroupName $recoveryResourceGroupName `
      -ServerName $recoveryCatalogServerName `
      -FailoverGroupName $catalogFailoverGroupName `
      -AllowDataLoss `
      >$null    
  }                  
}
catch
{
  # Create recovery region resource group
  $recoveryResourceGroup = New-AzureRmResourceGroup -Name $recoveryResourceGroupName -Location $recoveryLocation -Force

  $catalogDatabaseId = "/subscriptions/$currentSubscriptionId/resourceGroups/$($wtpUser.ResourceGroupName)/providers/Microsoft.Sql/servers/$originCatalogServerName/recoverabledatabases/$($config.CatalogDatabaseName)"
  $catalogServerConfig = @{
    CatalogServerName = "$recoveryCatalogServerName"
    AdminLogin = "$($config.CatalogAdminUserName)"
    AdminPassword = "$($config.CatalogAdminPassword)"
  }

  # Geo-restore the catalog database in a resource group in the recovery region. The ARM template also creates the catalog server if required 
  Write-Output "Geo-restoring catalog database to recovery region.  This step may take several minutes..."
  $deployment = New-AzureRmResourceGroupDeployment `
                  -Name "CatalogRecovery" `
                  -ResourceGroupName $recoveryResourceGroup.ResourceGroupName `
                  -TemplateFile ("$PSScriptRoot\RecoveryTemplates\" + $config.CatalogRecoveryTemplate) `
                  -RecoveryCatalogServerConfiguration $catalogServerConfig `
                  -CatalogDatabaseName $config.CatalogDatabaseName `
                  -SourceDatabaseId $catalogDatabaseId `
                  -ServiceObjectiveName "S1" `
                  -ErrorAction Stop
}

# Get DNS alias for catalog server 
$catalogAliasName = $config.ActiveCatalogAliasStem + $wtpUser.Name
$fullyQualifiedCatalogAlias = $catalogAliasName + ".database.windows.net"
$activeCatalogServerName = Get-ServerNameFromAlias $fullyQualifiedCatalogAlias -ErrorAction Stop  

# Update catalog alias to point to catalog database in recovery region if needed
if ($activeCatalogServerName -ne $recoveryCatalogServerName)
{
  Write-Output "Updating catalog alias to point to recovery region instance..."
  Set-DnsAlias `
    -ResourceGroupName $recoveryResourceGroupName `
    -ServerName $recoveryCatalogServerName `
    -ServerDNSAlias $catalogAliasName `
    -OldResourceGroupName $wtpUser.ResourceGroupName `
    -OldServerName $activeCatalogServerName `
    -PollDnsUpdate  
}

# Get catalog object
$tenantCatalog = Get-Catalog -ResourceGroupName $recoveryResourceGroupName -WtpUser $wtpUser.Name
Write-Output "Acquired tenant catalog in recovery region..."


# Initalize Azure context for background scripts  
$scriptPath= $PSScriptRoot
Save-AzureRmContext -Path "$env:TEMP\profile.json" -Force -ErrorAction Stop

# Start background process to sync tenant server, pool, and database configuration info into the catalog 
$runningScripts = (Get-WmiObject -Class Win32_Process -Filter "Name='PowerShell.exe'").CommandLine
if (!($runningScripts -like "*Sync-TenantConfiguration*"))
{
  Start-Process powershell.exe -ArgumentList "-NoExit &'$PSScriptRoot\Sync-TenantConfiguration.ps1'"
}

# Get list of tenants registered in catalog
$tenantList = Get-Tenants -Catalog $tenantCatalog -ErrorAction Stop

# Mark all non-recovered tenants as unavailable in the recovery catalog
Write-Output "Marking non-recovered tenants offline in the catalog..."
foreach ($tenant in $tenantList)
{
  $tenantStatus = (Get-ExtendedTenant -Catalog $tenantCatalog -TenantKey $tenant.Key).TenantRecoveryState

  if ($tenantStatus -NotIn 'OnlineInRecovery')
  {
    Set-TenantOffline -Catalog $tenantCatalog -TenantKey $tenant.Key -ErrorAction Stop
  }
}

Write-Output "---`nRecovering '$($wtpUser.ResourceGroupName)' deployment into '$recoveryLocation' region"

# Construct the name of the server that will be used to store tenants who join the Wingtip platform in the recovery region 
$serverList = Get-ExtendedServer -Catalog $tenantCatalog | Where-Object {($_.ServerName -NotMatch "$($config.RecoveryRoleSuffix)$")}
$latestServerIndex = $serverList | Select-String -Pattern "tenants(\d+)-.+" | %{$_.matches[0].Groups[1].value -as [int]} | sort | select -last 1
$newTenantServerName = "tenants" + ($latestServerIndex + 1) + "-dpt-$($wtpUser.Name)" + $config.RecoveryRoleSuffix

# Start background job to deploy recovery instance of Wingtip application into recovery region 
$appRecoveryJob = Start-Job -Name "AppRestore" -FilePath "$PSScriptRoot\RecoveryJobs\Restore-WingtipSaaSAppToRecoveryRegion.ps1" -ArgumentList @($recoveryResourceGroupName)

# Start background job to create new server and elastic pool that will be used to provision new tenant databases 
$newTenantProvisioningJob = Start-Job -Name "NewTenantProvisioning" -FilePath "$PSScriptRoot\RecoveryJobs\New-TenantResources.ps1" -ArgumentList @($recoveryResourceGroupName,$newTenantServerName)

# Start background job to create recovery tenant SQL Servers 
$serverRecoveryJob = Start-Job -Name "ServerRestore" -FilePath "$PSScriptRoot\RecoveryJobs\Restore-TenantServersToRecoveryRegion.ps1" -ArgumentList @($recoveryResourceGroupName)

# Start background job to create recovery tenant pools  
$poolRecoveryJob = Start-Job -Name "PoolRestore" -FilePath "$PSScriptRoot\RecoveryJobs\Restore-TenantElasticPoolsToRecoveryRegion.ps1" -ArgumentList @($recoveryResourceGroupName)

# Start background job to geo-restore tenant databases
$databaseRecoveryJob = Start-Job -Name "DatabaseRestore" -FilePath "$PSScriptRoot\RecoveryJobs\Restore-TenantDatabasesToRecoveryRegion.ps1" -ArgumentList @($recoveryResourceGroupName)

# Start background job to mark tenants online when all required resources have been restored 
$tenantRecoveryJob = Start-Job -Name "TenantRecovery" -FilePath "$PSScriptRoot\RecoveryJobs\Enable-TenantsAfterRecoveryOperation.ps1" -ArgumentList @($recoveryResourceGroupName)

# Monitor state of all recovery jobs 
while ($true)
{
  # Get state of all recovery jobs. Stop recovery if there is an error with any job
  $appRecoveryStatus = Receive-Job -Job $appRecoveryJob -Keep -ErrorAction Stop
  $newTenantProvisioningStatus = Receive-Job -Job $newTenantProvisioningJob -Keep -ErrorAction Stop
  $serverRecoveryStatus = Receive-Job -Job $serverRecoveryJob -Keep -ErrorAction Stop
  $poolRecoveryStatus = Receive-Job -Job $poolRecoveryJob -Keep -ErrorAction Stop 
  $databaseRecoveryStatus = Receive-Job -Job $databaseRecoveryJob -Keep -ErrorAction Stop
  $tenantRecoveryStatus = Receive-Job -Job $tenantRecoveryJob -Keep -ErrorAction Stop 

  # Enable traffic manager endpoint in recovery region if resources have been created for new tenants 
  # This signals that the app is ready to receive traffic and can process new tenant registrations while recovery operations are underway
  $appAvailable = $false
  if (($newTenantProvisioningJob.State -eq "Completed") -and ($appRecoveryJob.State -eq "Completed") -and ($serverRecoveryJob.State -eq "Completed"))
  {
    $profileName = $config.EventsAppNameStem + $wtpUser.Name
    $endpointName = $config.EventsAppNameStem + $recoveryLocation + '-' + $wtpUser.Name
    $appAvailable = $true

    $webAppEndpoint = Get-AzureRmTrafficManagerEndpoint -Name $endpointName -Type AzureEndpoints -ProfileName $profileName -ResourceGroupName $wtpUser.ResourceGroupName
    
    if ($webAppEndpoint.EndpointStatus -ne 'Enabled')
    {
      Write-Output "Enabling traffic manager endpoint for Wingtip events app in recovery region..."
      Enable-AzureRmTrafficManagerEndpoint -Name $endpointName -Type AzureEndpoints -ProfileName $profileName -ResourceGroupName $wtpUser.ResourceGroupName -ErrorAction Stop > $null

      # Update tenant provisioning server alias to point to newly created tenant resources
      $newTenantAlias = $config.NewTenantAliasStem + $wtpUser.Name
      $fullyQualifiedNewTenantAlias = $newTenantAlias + ".database.windows.net"
      $currentProvisioningServerName = Get-ServerNameFromAlias $fullyQualifiedNewTenantAlias
      Set-DnsAlias `
        -ResourceGroupName $recoveryResourceGroupName `
        -ServerName $newTenantServerName `
        -ServerDNSAlias $newTenantAlias `
        -OldResourceGroupName $wtpUser.ResourceGroupName `
        -OldServerName $currentProvisioningServerName `
        -PollDnsUpdate `
        >$null
    }
  }

  # Initialize and format output for recovery jobs 
  $appRecoveryStatus = Format-JobOutput $appRecoveryStatus
  $serverRecoveryStatus = Format-JobOutput $serverRecoveryStatus
  $poolRecoveryStatus = Format-JobOutput $poolRecoveryStatus
  $databaseRecoveryStatus = Format-JobOutput $databaseRecoveryStatus
  $newTenantProvisioningStatus = Format-JobOutput $newTenantProvisioningStatus 
  $tenantRecoveryStatus = Format-JobOutput $tenantRecoveryStatus
 
  if ($newTenantProvisioningStatus -eq "Done")
  {
    $newTenantServerRecoveryStatus = "100% (1 of 1)"
    $newTenantPoolRecoveryStatus = "100% (1 of 1)"
  }
  else
  {
    $newTenantServerRecoveryStatus = "0% (0 of 1)"
    $newTenantPoolRecoveryStatus = "0% (0 of 1)" 
  }

  if ($appAvailable)
  {
    $appRecoveryStatus = "Online"
  }
  elseif ($appRecoveryStatus -eq "Done")
  {
    $appRecoveryStatus = "Deployed (offline)"
  }

  # Output status of recovery jobs to console
  [PSCustomObject] @{
    "Catalog Server & Database" = "Available"
    "Wingtip App" = $appRecoveryStatus    
    "New Tenant Server" = $newTenantServerRecoveryStatus
    "New Tenant Pool" = $newTenantPoolRecoveryStatus
    "Tenant Servers" = $serverRecoveryStatus
    "Tenant Pools" = $poolRecoveryStatus 
    "Tenant Databases" =  $databaseRecoveryStatus
    "Tenants Online" = $tenantRecoveryStatus 
  } | Format-List
  

  # Exit recovery if all tenant databases have been recovered 
  if (($appRecoveryJob.State -eq "Completed") -and ($databaseRecoveryJob.State -eq "Completed") -and ($poolRecoveryJob.State -eq "Completed") -and ($serverRecoveryJob.State -eq "Completed") -and ($newTenantProvisioningJob.State -eq "Completed") -and ($tenantRecoveryJob.State -eq "Completed"))
  {
    Remove-Item -Path "$env:TEMP\profile.json" -ErrorAction SilentlyContinue   
    break
  }
  else
  {
    Write-Output "---`nRefreshing recovery status in $StatusCheckTimeInterval seconds..."
    Start-Sleep $StatusCheckTimeInterval
    $elapsedTime = (Get-Date) - $startTime
  }          
}

Write-Output "'$($wtpUser.ResourceGroupName)' deployment recovered into '$recoveryLocation' region in $([math]::Round($elapsedTime.TotalMinutes,2)) minutes."

