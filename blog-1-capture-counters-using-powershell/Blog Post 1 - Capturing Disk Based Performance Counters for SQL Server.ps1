<#
Title:          Blog Post 1 - Capturing Disk Based Performance Counters for SQL Server
Author:         Bill Ramos, DB Best Technologies
Published:      01/09/2019
Description:
                This script captures disk system based performance counters that provide data used to understand the 
                current performance of a SQL Server instance needed to optimize EBS volumes for similar performance
                with lower storage costs.

                You can use this script to run for a specific length of time or wait for a semephore file in an S3 bucket
                to complete the processing of the performance counter data.
#>

####################################
# 1. Setup the variables for the run
####################################
$Task = "Trial_1"   # Unique identifier for the test run. Used as part of the output file name for the results.
$perfmon_outfile = "C:\Temp\Task-$($Task)-PerfMon-Capture.csv"  # Name for the output file.

# Specify the number of seconds to colect the data and how often to check
$Timeout = 600      # Defines the number of seconds to capture the counters. Ex. 600 = 10 mins, 3600 = 1 hr, 28800 = 8 hr
$CheckEvery = 60    # Defines the number of seconds to wait before checking again

########################################################
# 2. Create an array of the counters you want to collect
########################################################
$Counters = @(

# Processor
  "\Processor(_Total)\% Processor Time"     # CPU usage provides a good way to identify patterns to investigate.
, "\Processor(*)\% Processor Time"          # This is helpful to see what is going on with individual vCPU trends.
, "\Processor(_total)\% Privileged Time"    # % time on kernal operations. If value is high, check AWS for EC2 driver patches.
, "\Processor(_total)\% User Time"          # % time spent on applications like SQL Server.

# \SQLServer:Workload Group Stats
, "\SQLServer:Workload Group Stats(*)\CPU usage %"  # % time SQL Server is spending on a specific Workload Group like default.

# Memory Counter Categories

# - Memory
, "\Memory\Available Kbytes"    # The Kbytes counter aligns nicely woth SQL Server's (KB) scale.
, "\Memory\Committed Bytes"     # If Committed bytes is greater than physical memory, then more RAM will help.

# - Paging File
, "\Paging File(_Total)\% Usage"    # This is not really a Memory counter. A high value for the % Usage would indicate memory pressure.

# - SQL Server:Memory Manager
, "\SQLServer:Memory Manager\Database Cache Memory (KB)"# This is basically the buffer pool.
, "\SQLServer:Memory Manager\Free Memory (KB)"          # Represents the amount of memory SQL Server has available to use
, "\SQLServer:Memory Manager\Target Server Memory (KB)" # The amount of memory that SQL Server thinks it needs at the time
, "\SQLServer:Memory Manager\Total Server Memory (KB)"  # An approximation of how much the database engine is using.


# Disk Counter Categories

# IOPS counters - Reported as the average of the interval where the interval is greater than 1 second.
, "\LogicalDisk(_Total)\Disk Reads/sec"          # Read operations where SQL Server has to load data into buffer pool
, "\LogicalDisk(_Total)\Disk Writes/sec"         # Write operations where SQL Server has to harden data to disk
, "\LogicalDisk(_Total)\Disk Transfers/sec"      # Tranfers (AKA IOPS) is approximately the sum of the Read/sec and Writes/sec

# Throughput counters - Bytes/sec - Reported as the average of the interval where the interval is greater than 1 second.
, "\LogicalDisk(_Total)\Disk Read Bytes/sec"     # Read throughput
, "\LogicalDisk(_Total)\Disk Write Bytes/sec"    # Write throughput
, "\LogicalDisk(_Total)\Disk Bytes/sec"          # Total throughput

# Block sizes for IO - Reported as an average for the interval. These are useful to look at over time
* to see the block sizes SQL Server is using.
, "\LogicalDisk(_Total)\Avg. Disk Bytes/Read"    # Read IO block size
, "\LogicalDisk(_Total)\Avg. Disk Bytes/Write"   # Write IO block size
, "\LogicalDisk(_Total)\Avg. Disk Bytes/Transfer"# Raed + Write IO block size

# Latency counter - Avg. Disk sec/Transfer represents IO latency.
# This really isn't needed for the optimization, but it does verify volume configuration.
, "\LogicalDisk(_Total)\Avg. Disk sec/Transfer" # For gp2 drives, this value is generally around .001 sec (1 ms) or less.
                                                # SQL Seerver sys.dm_io_virtual_file_stats calls this io_stall_read/write

# Physical counters - We collect the same counters as the LogicalDisk, but the values are reported
# by drive letter. Same comments above apply.
, "\PhysicalDisk(* *)\Disk Reads/sec"
, "\PhysicalDisk(* *)\Disk Writes/sec"
, "\PhysicalDisk(* *)\Disk Transfers/sec"
, "\PhysicalDisk(* *)\Disk Read Bytes/sec"
, "\PhysicalDisk(* *)\Disk Write Bytes/sec"
, "\PhysicalDisk(* *)\Disk Bytes/sec"
, "\PhysicalDisk(* *)\Avg. Disk Bytes/Read"
, "\PhysicalDisk(* *)\Avg. Disk Bytes/Write"
, "\PhysicalDisk(* *)\Avg. Disk Bytes/Transfer"
, "\PhysicalDisk(* *)\Avg. Disk sec/Transfer"

# SQL Server:Databases - We can collect specific counters for the log operations if we want to later
#                        move the database log files to another volume.
, "\SQLServer:Databases(*)\Log Flushes/sec"          # Shows Write IOPS for all database log files.
, "\SQLServer:Databases(*)\Log Bytes Flushed/sec"    # Shows Write Bytes/sec for all database log files.

)

######################################################
# 3. Get the first sample before starting the workload
######################################################
Get-Counter -Counter $Counters | ForEach-Object {   # Loops thru each performance counter in $Counters
    $_.CounterSamples | ForEach-Object {            # Take the array of CounterSamples to build a custom object
        [pscustomobject]@{                          # Define the [pscustomobject] as follows:
            "Task ID" = $Task                       # Task ID using the $task in step 1
             "Event Date Time (UTC)" = $_.TimeStamp # Event Date Time (UTC) using the TimeStamp for the collection
             "Performance Counter" = $_.Path        # Performance Counter using the counter path
             Value = $_.CookedValue                 # Value using the CookedValue based on the counter type.
        }
    }
} | `
Export-Csv -Path "$perfmon_outfile" -NoTypeInformation # Create the result CSV file from the data.

##############################################
# 4. Start the time and then collect counters.
##############################################

# Start the timer using the Stopwatch Class within the .NET Framework
# https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8
$timersql = [Diagnostics.Stopwatch]::StartNew()

while ( $timersql.Elapsed.TotalSeconds -lt $Timeout )  # Loop while time remains
{
    Write-Host "Time remaining = $( $Timeout - $timersql.Elapsed.TotalSeconds )"
    # Time to sleep based on the value for $CheckEvery in seconds.
    # The wait is done here to make sure that the inital performance counters are captured.
    Start-Sleep -Seconds $CheckEvery

    # The wait is over, get the next set of performance counters
    Get-Counter -Counter $Counters | ForEach-Object {
        $_.CounterSamples | ForEach-Object {
            [pscustomobject]@{
                "Task ID" = $Task
                "Event Date Time (UTC)" = $_.TimeStamp
                "Performance Counter" = $_.Path
                Value = $_.CookedValue
            }
        }
    } | Export-Csv -Path "$perfmon_outfile" -NoTypeInformation -Append  # Results are appended to the CSV file

}

# That's it!
Write-Host "Go to the file $($perfmon_outfile) to see the results."