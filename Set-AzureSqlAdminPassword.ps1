Function Set-AzureSqlAdminPassword {
    <#
		.SYNOPSIS
		Change all Azure SQL Server Admin (sa) accounts passwords to a random 30 character password.
	
		.DESCRIPTION
        The function will loop through all Azure SQL instances in a subscription and change the sa account password to a random 30Character scrambled password.
        This function can be added to an automation account runbook to automate Azure SQL Admin password change and rotation.
        The goal of the function is to only rotate the password and prevent usage of the sa account. (NOTE: No passwords are stored).
        Each SQL instance password is generated uniquely and no passwords are re-used.
        In a break glass situation if sa access is required to a sql instance the password can be manually changed or set by a privileged user/admin.     
	
		.PARAMETER SubscriptionId
		Loops through a single subscription and change all Azure SQL Server Admin (sa) passwords to a random 30Character password for all Azure SQL instances contained within the subscription.
    
        .PARAMETER ExcludedResourceGroups
        Optional parameter of type Array to have the ability to exclude specified ResourceGroups from being parsed by the function.
        
		.EXAMPLE
		Set-AzureSqlAdminPassword -subscription <SubscriptionId> -Verbose
        Runs through all Azure SQL instances in the specified subscription and changes any Azure SQL (sa) passwords to random password (30 Characters).
        
        .EXAMPLE
		Get-AzureRmSubscription | Set-AzureSqlAdminPassword -verbose
		Runs through all Azure SQL instances in the entire tenant (all subscriptions) and changes any Azure SQL (sa) passwords to random password (30 Characters).

        .EXAMPLE
		$RGtoExclude = Get-AzureRmResourceGroup | Select-Object ResourceGroupName -ExpandProperty ResourceGroupname | where-object {($_.ResourceGroupName -like "*RGEast*") -or ($_.ResourceGroupName -like "*RGWest*")} 
		Get-AzureRmSubscription | Where-Object {$_.Name -like "*MySubscr*"}  | Set-AzureSqlAdminPassword -ExcludedResourceGroups $RGtoExclude -Verbose 
        Runs through all Azure SQL instances contained in the Subscription filter but excludes certain Resource Groups that have name variants of "RGEast" or "RGWest".
        
		.NOTES
		Author: Paperclips (pwd9000@hotmail.co.uk).
		PSVersion: 5.1.
		Date Created: 09/07/2019.
		Updated: 11/07/2019
		Verbose output is displayed using verbose parameter. (-Verbose).
	#>
	
    [CmdletBinding(SupportsShouldProcess)]
    Param(	
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$SubscriptionId,

        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [Array]$ExcludedResourceGroups
    )

    # Loop through all Azure SQL instances in subscription.
    If (Get-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue) {
        $null = Set-AzureRmContext -Subscription $SubscriptionId
        Write-Verbose "Connecting to Subscription: [$((Get-AzureRmContext).Subscription.Name)]"

        Get-AzureRmResourceGroup | Select-Object ResourceGroupName | Where-Object {$_.ResourceGroupName -notin $ExcludedResourceGroups} |
        ForEach-Object {
            Get-AzureRmSqlServer -ResourceGroupName $_.ResourceGroupName |
            ForEach-Object {
                $null = [Reflection.Assembly]::LoadWithPartialName(“System.Web”)
                $newPassword = [System.Web.Security.Membership]::GeneratePassword(30,0)
                $secureString = ConvertTo-SecureString $newPassword -AsPlainText -Force
                $null = Set-AzureRmSqlServer -ResourceGroupName $_.ResourceGroupName -ServerName $_.ServerName -SqlAdministratorPassword $secureString
                Write-Verbose "Changing Server Admin password Azure SQL Instance: [$($_.ServerName)]"
            }
        }
    }   
    Else {
        Throw "The provided Subscription ID: [$SubscriptionId] could not be found or does not exist. Please provide a valid Subscription ID."
    }
}