#requires -version 6.2
<#
    .SYNOPSIS
        This command will generate a CSV file containing the names of all the Azure Sentinel
        Analytic rules and queries that reference CommonSecurityLog in the KQL code
    .DESCRIPTION
        This command will generate a CSV file containing the names of all the Azure Sentinel
        Analytic rules and queries that reference CommonSecurityLog in the KQL code
    .PARAMETER WorkSpaceName
        Enter the Log Analytics workspace name, this is a required parameter
    .PARAMETER ResourceGroupName
        Enter the Log Analytics workspace name, this is a required parameter
    .PARAMETER FileName
        Enter the file name to use.  Defaults to "ruleswithCommonSecurityLog"  ".csv" will be appended to all filenames
    .NOTES
        AUTHOR: Gary Bushey
        LASTEDIT: 17 JAn 2023
    .EXAMPLE
        Export-AzSentinelObjectsWithCommonSecurityLogs "workspacename" -ResourceGroupName "rgname"
        In this example you will get the file named "ruleswithCommonSecurityLog.csv" generated containing all the rule templates
    .EXAMPLE
        Export-AzSentinelObjectsWithCommonSecurityLogs -WorkspaceName "workspacename" -ResourceGroupName "rgname" -fileName "test"
        In this example you will get the file named "test.csv" generated containing all the rule templates
   
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$WorkSpaceName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [string]$FileName = "ActiveSentinelRules.csv"

    [Parameter(Mandatory = $true)]
    [string]$Table,

)
Function Export-AzSentinelObjects ($workspaceName, $resourceGroupName, $fileName) {

    $outputObject = New-Object system.Data.DataTable
    [void]$outputObject.Columns.Add('Name', [string]::empty.GetType() )
    [void]$outputObject.Columns.Add('Category', [string]::empty.GetType() )

    $newRow = $outputObject.NewRow()
    $newRow.Name = "***Analytic Rules***"
    [void]$outputObject.Rows.Add( $newRow )

    #Setup the Authentication header needed for the REST calls
    $context = Get-AzContext
    $profile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($profile)
    $token = $profileClient.AcquireAccessToken($context.Subscription.TenantId)
    $authHeader = @{
        'Content-Type'  = 'application/json' 
        'Authorization' = 'Bearer ' + $token.AccessToken 
    }
    
    $SubscriptionId = (Get-AzContext).Subscription.Id

    #Load the rules so that we search for the information we need
    $url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($resourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($workspaceName)/providers/Microsoft.SecurityInsights/alertrules?api-version=2022-12-01-preview"
    $results = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

    foreach ($singleRule in ($results.properties | Where-Object -Property "Query" -Like "*$Table*")) {
        $newRow = $outputObject.NewRow()
        $newRow.Name = $singleRule.displayName
        $newRow.Category =""
        [void]$outputObject.Rows.Add( $newRow )
    }
    
    $newRow = $outputObject.NewRow()
    $newRow.Name = ""
    [void]$outputObject.Rows.Add( $newRow )

    $newRow = $outputObject.NewRow()
    $newRow.Name = "***KQL Queries***"
    [void]$outputObject.Rows.Add( $newRow )

     #Load the queries so that we search for the information we need
     $url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($workspaceName)/savedSearches/?api-version=2017-03-03-preview"
     $results = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

     foreach ($singleQuery in ($results.properties | Where-Object -Property "Query" -Like "*$Table*")) {
        $newRow = $outputObject.NewRow()
        $newRow.Name = $singleQuery.displayName
        $newRow.Category = $singleQuery.Category
        [void]$outputObject.Rows.Add( $newRow )
     }
     
     $outputObject |  Export-Csv -QuoteFields "Name" -Path $fileName -Append
}


#Execute the code
if (! $Filename.EndsWith(".csv")) {
    $FileName += ".csv"
}
Export-AzSentinelObjects $WorkSpaceName $ResourceGroupName $FileName 
