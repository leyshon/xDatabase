data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
    CreateDatabaseLoginError=Failed to create SQL User '{0}'.
    TestDatabaseLoginError=Failed to test SQL User '{0}'.
    CreateDatabaseLoginSuccess=Success: SQL User '{0}' either already existed or has been successfully created.
    RemoveDatabaseLoginError=Failed to remove SQL User '{0}'.
    RemoveDatabaseLoginSuccess=Success: SQL User '{0}' either does not existed or has been successfully removed.
'@
}

Import-Module $PSScriptRoot\..\xDatabase_Common

function Get-TargetResource 
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",
        
        [parameter(Mandatory = $true)]
        [System.String]
        $UserName,

        [System.Management.Automation.PSCredential]
        $Password,

        [System.String]
        $LoginName,

        [parameter(Mandatory = $true)]
        [System.String]
        $DatabaseName,

        [System.Management.Automation.PSCredential]
        $SqlConnectionCredentials,
       
        [parameter(Mandatory = $true)]
        [System.String]
        $SqlServer

    )

    if($PSBoundParameters.ContainsKey('SqlConnectionCredentials'))
    {
        $ConnectionString = Construct-ConnectionString -sqlServer $SqlServer -credentials $SqlConnectionCredentials
    }
    else
    {
        $ConnectionString = Construct-ConnectionString -sqlServer $SqlServer
    }

    $ConnectionString = "$ConnectionString database=$DatabaseName"

    [string]$SqlQuery = "SELECT * FROM sys.database_principals WHERE name='$UserName'"

    $PresentValue = $false

    if((ReturnSqlQuery -sqlConnection $connectionString -SqlQuery $SqlQuery)[0] -gt 0)
    {
        $PresentValue = $true
    }


    $returnValue = @{
        Ensure = $PresentValue
        UserName = $UserName
        SqlServer = $SqlServer
        Database = $DatabaseName
    }

    $returnValue

}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [parameter(Mandatory = $true)]
        [System.String]
        $UserName,

        [System.Management.Automation.PSCredential]
        $Password,

        [System.String]
        $LoginName,

        [parameter(Mandatory = $true)]
        [System.String]
        $DatabaseName,
        
        [System.Management.Automation.PSCredential]
        $SqlConnectionCredentials,
        
        [parameter(Mandatory = $true)]
        [System.String]
        $SqlServer
    )
    
    if($PSBoundParameters.ContainsKey('SqlConnectionCredentials'))
    {
        $ConnectionString = Construct-ConnectionString -sqlServer $SqlServer -credentials $SqlConnectionCredentials
    }
    else
    {
        $ConnectionString = Construct-ConnectionString -sqlServer $SqlServer
    }

    if($PSBoundParameters.ContainsKey('Password'))
    {
        [string]$Password = $Password.GetNetworkCredential().Password
    }

    $ConnectionString = "$ConnectionString database=$DatabaseName"

    if($Ensure -eq "Present")
    {
        try
        {
            # Create User if it does not already exist. If no login is supplied create a contianed database user
            if (!$LoginName) 
            {
                [string]$SqlQuery = "IF NOT EXISTS(SELECT name FROM sys.database_principals WHERE name='$UserName') BEGIN CREATE USER $UserName WITH PASSWORD = '$Password' END"
            }
            else 
            {
                [string]$SqlQuery = "IF NOT EXISTS(SELECT name FROM sys.database_principals WHERE name='$UserName') BEGIN CREATE USER $UserName FROM LOGIN $LoginName END"
            }

            $supressReturn = ExecuteSqlQuery -sqlConnection $connectionString -SqlQuery $SqlQuery

            Write-Verbose $($LocalizedData.CreateDatabaseLoginSuccess -f ${UserName})
        
        }
        catch
        {
            $errorId = "CreateDatabaseLogin";
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult
            $errorMessage = $($LocalizedData.CreateDatabaseLoginError -f ${UserName})
            $exception = New-Object System.InvalidOperationException $errorMessage 
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

            $PSCmdlet.ThrowTerminatingError($errorRecord);
        }
    }
    else # Ensure is absent so remove user.
    {
        try
        {
            # Drop user if it already exists
            [string]$SqlQuery = "IF EXISTS(SELECT name FROM sys.database_principals WHERE name='$UserName') BEGIN DROP USER $UserName END"

            $supressReturn = ExecuteSqlQuery -sqlConnection $connectionString -SqlQuery $SqlQuery

            Write-Verbose $($LocalizedData.RemoveDatabaseLoginSuccess -f ${UserName})
        }
        catch
        {
            $errorId = "RemoveDatabaseLogin";
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult
            $errorMessage = $($LocalizedData.RemoveDatabaseLoginError -f ${LoginName})
            $exception = New-Object System.InvalidOperationException $errorMessage 
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

            $PSCmdlet.ThrowTerminatingError($errorRecord);
        }
    }
}


function Test-TargetResource 
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [parameter(Mandatory = $true)]
        [System.String]
        $UserName,

        [System.Management.Automation.PSCredential]
        $Password,

        [System.String]
        $LoginName,

        [parameter(Mandatory = $true)]
        [System.String]
        $DatabaseName,

        [System.Management.Automation.PSCredential]
        $SqlConnectionCredentials,
       
        [parameter(Mandatory = $true)]
        [System.String]
        $SqlServer
    )

    try
    {
        if($PSBoundParameters.ContainsKey('SqlConnectionCredentials'))
        {
            $ConnectionString = Construct-ConnectionString -sqlServer $SqlServer -credentials $SqlConnectionCredentials
        }
        else
        {
            $ConnectionString = Construct-ConnectionString -sqlServer $SqlServer
        }
        
        $ConnectionString = "$ConnectionString database=$DatabaseName"

        [string]$SqlQuery = "SELECT * from sys.database_principals where name='$UserName'"
        
        $LoginsReturnedByQuery = (ReturnSqlQuery -sqlConnection $connectionString -SqlQuery $SqlQuery)[0]

        if((($LoginsReturnedByQuery -gt 0) -and ($Ensure -eq "Present")) -or (($LoginsReturnedByQuery -eq 0) -and ($Ensure -eq "absent")))
        {
            $result = $true
        }
        else
        {
            $result = $false
        }

        return $result

    }
    catch
    {
        $errorId = "TestDatabaseLogin";
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult
        $errorMessage = $($LocalizedData.TestDatabaseLoginError -f ${UserName})
        $exception = New-Object System.InvalidOperationException $errorMessage 
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord);
    }

}

Export-ModuleMember -Function *-TargetResource




