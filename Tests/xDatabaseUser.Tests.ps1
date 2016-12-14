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
    
    
    It "Get-TargetResource should return [Hashtable]" {
        $QueryResult = 1
        (Get-TargetResource @testParameter).GetType()  -as [String] | Should Be "hashtable"
    }
    Context "user does not exist" {       
        It "Test-TargetResource should return false" {
            $QueryResult = 0
            Test-TargetResource @testParameter | Should Be $false
        }
    }
    Context "user does exist" {      
        It "Test-TargetResource should return true" {
            $QueryResult = 1
            Test-TargetResource @testParameter | Should Be $true
        }
    }
    Context "Set-TargetResource with Ensure = Present" {
        Mock -CommandName ExecuteSqlQuery -MockWith {return $true} -ParameterFilter {$SqlQuery -like "*CREATE USER TestUser*"} -Verifiable 
        It "should execute create user sql query" {
            Set-TargetResource @testParameter 
            Assert-VerifiableMocks
        }
    }
    Context "Set-TargetResource with Ensure = Absent" {
        Mock -CommandName ExecuteSqlQuery -MockWith {return $true} -ParameterFilter {$SqlQuery -like "*DROP USER TestUser*"} -Verifiable
        $testParameter.Ensure = "Absent"
        It "should execute drop user sql query" {
            Set-TargetResource @testParameter
            Assert-VerifiableMocks
        } 
    }
}
