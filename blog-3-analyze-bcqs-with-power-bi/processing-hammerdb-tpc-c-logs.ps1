<#
Title:          Blog Post 3 - Processing HammerDB TPC-C log files
Author:         Bill Ramos, DB Best Technologies
Published:      01/14/2019
Description:
    This script performs a series of pre-processing steps for HammerDB TPC-C
    log files that used the Log Timestamps option without the Time Profile option.
    HammerDB places the unique files for each virtual user run in the C:\TEMP
    directory.

    The end result for this script is a CSV file that is Power BI friendly for
    correlating performance counter data with the HammerDB run.
#>

#######################################
# 1. Define functions for parsing lines
#######################################
Function Get-HammerDB-DateTime{
<#
This function takes the Timestamp line format to create a date time format that matches the
Performance Counters format.
The function returns the date time value as a string.
#>
Param (
[string]$TimeStampLine    # Ex. Timestamp 2 @ Tue Jan 07 12:29:20 PST 2020
)
# End parameters for Get-HammerDB-DateTime
Process{
    $LineParts = $TimeStampLine.Split(" ")
    $LocalTime = [DateTime]"$($LineParts[4]) $($LineParts[5]) $($LineParts[8]) $($LineParts[6])"
    Return( 
         "$($LocalTime.ToUniversalTime().ToString('d')) $( $LocalTime.ToUniversalTime().ToString('T'))"
#        $LocalTime.ToUniversalTime()
    )
    } # End of Process for Get-HammerDB-DateTime
}

# Quick test
$qt = Get-HammerDB-DateTime("Timestamp 1 @ Tue Jan 07 12:01:32 PST 2020")
Write-Host $qt
# Expected result with UTC time zone: "1/7/2020 8:01:32 PM"

Function Get-HammerDB-Results{
<#
This function takes two parameters that represent the lines at the end of the TPC-C HammerDB log files
for Active Virtual Users configured and the System achieved results for TPM and NOPM.
The function returns an array of three values for Virtual Users, TPM, NOPM values.
#>
    Param (
    [string]$VuserLine,     # Ex. "Vuser 1:144 Active Virtual Users configured"
    [string]$TPMLine        # Ex. "Vuser 1:TEST RESULT : System achieved 78844 SQL Server TPM at 16637 NOPM"
    ) # End parameters for Get-HammerDB-Results
    Process{
        # Extract the Virtual Users
        $ColonSplit = $VuserLine.Split(":")             # After the split with ":", [1] = "144 Active Virtual Users configured"
        $VirtualUsers = $ColonSplit[1].Split(" ")[0]    # After the split with " ", [0] = "144"

        # Extract the TPM and NOPM values
        $Words = $TPMLine.Split(":")[2].Split(" ")  # After split with ":",
                                                    # [2] = " System achieved 78844 SQL Server TPM at 16637 NOPM"
        $TPM  = $Words[3]                           # After split with " ", [3] = "78844"
        $NOPM = $Words[8]                           # and                   [8] = "16637"
        $Results = @( $VirtualUsers, $TPM, $NOPM )  # Create the results array with the three values
        Return( $Results  )
    } # End of Process for Get-HammerDB-Results
} # End of Function for Get-HammerDB-Results

# Quick test
    $vUser = "Vuser 1:144 Active Virtual Users configured"
    $TPML = "Vuser 1:TEST RESULT : System achieved 78844 SQL Server TPM at 16637 NOPM"
    $TPMResultsArray = Get-HammerDB-Results -VuserLine $vUser -TPMLine $TPML
    Write-Host $TPMResultsArray      # Expect 144 78844 16637

##############################################
# 2. Setup the global variables for the script
##############################################
Write-Host "Process the HammerDB Log files for TPCC"
$mode = "TPCC"                                          # Name of the benchmark
$path = "C:\Temp"                                       # The typical location for the temp directory
$Task = "Blog-B1"
$FinalResult = "C:\Temp\FinalResult-$mode-$Task.csv"    # Name of the result file used with Power BI

######################################################################
# 3. Gather the lines of text for the Virtual users, end time, and TPM
######################################################################
$searchWords = 'Active Virtual Users configured'           
Foreach ($sw in $searchWords)
{
    Get-Childitem -Path $path -Recurse -include "*.log" | 
    Select-String -Pattern "$sw" -Context 1,2 | 
    ForEach-Object { 
        @([pscustomobject] @{
            "Task" = $Task
            "FileName" = $_.Path
            "Mode" = $mode
            "VirtualUser" = $_.Line
            "TPM" = $_.Context.PostContext[1]
            "EndTime" = Get-HammerDB-DateTime($_.Context.PreContext[0])
        } )
    } | Export-Csv -Path $path\HammerDBResults_1.csv -NoTypeInformation 
}
$searchWords = 'Vuser 1:Beginning rampup time'
Foreach ($sw in $searchWords)
{
    Get-Childitem -Path $path -Recurse -include "*.log" | 
    Select-String -Pattern "$sw" -Context 1,0 |
    ForEach-Object { 
        @([pscustomobject] @{
            "FileName" = $_.Path   
            "StartTime" = Get-HammerDB-DateTime($_.Context.PreContext[0])
        } ) 
    } | Export-Csv -Path $path\HammerDBResults_2.csv -NoTypeInformation 
}
$searchWords = 'Vuser 1:Rampup complete, Taking start Transaction Count'
Foreach ($sw in $searchWords)
{
    Get-Childitem -Path $path -Recurse -include "*.log" | 
    Select-String -Pattern "$sw" -Context 1,0 |
    ForEach-Object { 
        @([pscustomobject] @{
            "FileName" = $_.Path   
            "TranStartTime" = Get-HammerDB-DateTime($_.Context.PreContext[0])
        } ) 
    } | Export-Csv -Path $path\HammerDBResults_3.csv -NoTypeInformation 
}
$CSV1 = Import-Csv -Path 'C:\Temp\HammerDBResults_1.csv' -Delimiter ','
$CSV2 = Import-Csv -Path 'C:\Temp\HammerDBResults_2.csv' -Delimiter ','

$InterResult = Foreach($Item1 in $CSV1){
    Foreach($item2 in $CSV2){ 
        If($Item1.FileName -eq $item2.FileName){
            @([PSCustomObject] @{
                "Task" = $Item1.Task
		        "FileName" = $Item1.FileName
		        "Mode" = $Item1.Mode
                "RampupStartTime" = $Item2.StartTime
		        "TranEndTime" = $Item1.EndTime
		        "VirtualUser" = $Item1.VirtualUser
		        "TPM" = $Item1.TPM
            } )
	    } 
    }
}
$InterResult | Export-Csv -Path 'C:\Temp\InterResult.csv' -NoTypeInformation 

$CSV3 = Import-Csv -Path 'C:\Temp\HammerDBResults_3.csv' -Delimiter ','
$CSV4 = Import-Csv -Path 'C:\Temp\InterResult.csv' -Delimiter ','

$Result = Foreach($Item1 in $CSV4){
    Foreach($Item2 in $CSV3){ 
        If($Item1.FileName -eq $item2.FileName){
            $Result_Values = Get-HammerDB-Results -VuserLine $Item1.VirtualUser -TPMLine $Item1.TPM
            @([PSCustomObject]@{
                "Task" = $Item1.Task
		        "Mode" = $Item1.Mode
                "Rampup Start Time" = $item1.RampupStartTime
                "Transaction Start Time" = $item2.TranStartTime
		        "Transaction End Time" = $Item1.TranEndTime
		        "Virtual Users" = $Result_Values[0]
                "TPM" = $Result_Values[1]
                "NOPM" = $Result_Values[2]
            } )
	    } 
    }
}
$Result | Export-Csv -Path $FinalResult -NoTypeInformation 

