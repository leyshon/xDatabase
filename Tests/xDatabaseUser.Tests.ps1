$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$leaf = Split-Path -Leaf $MyInvocation.MyCommand.Path
$source = "..\DSCResources\$($leaf.Split(".")[0])\$($leaf -replace ".Tests.ps1$",".psm1")"
$common = "..\DSCResources\xDatabase_Common\"

$testParameter = @{
    Ensure = "Present"
    UserName = "TestUser"
    DatabaseName = "TestDb"
    SqlServer = "TestSvr"
}

Describe "Testing xDatabaseUser resource execution" {
    New-Item TestDrive:\xDatabaseUser -Type Directory
    Copy-Item -Path "$here\$source" -Destination TestDrive:\xDatabaseUser\script.ps1
    Copy-Item -Path "$here\$common" -Recurse -Destination TestDrive:\

    Mock -CommandName Export-ModuleMember -MockWith {return $true}
    . TestDrive:\xDatabaseUser\script.ps1

    Mock -CommandName ReturnSqlQuery -MockWith {return $QueryResult}
    Mock -CommandName ExecuteSqlQuery -MockWith {return $true}
    
    $QueryResult = 1
    It "Get-TargetResource should return [Hashtable]" {
        (Get-TargetResource @testParameter).GetType()  -as [String] | Should Be "hashtable"
    }
    Context "user does not exist" {

        $QueryResult = 0
        It "Test-TargetResource should return false" {
            Test-TargetResource @testParameter | Should Be $false
        }
    }
    Context "user does exist" {

        $QueryResult = 1
        It "Test-TargetResource should return true" {
            Test-TargetResource @testParameter | Should Be $true
        }
    }
}
