$connection = "localhost:19000"
$timeToRun = 5
$maxStabilizationTimeSecs = 20
$concurrentFaults = 3
$waitTimeBetweenIterationsSec = 1
$waitTimeBetweenFaultsSec = 5

Connect-ServiceFabricCluster $connection

$events = @{}
$now = [System.DateTime]::UtcNow

Start-ServiceFabricChaos -TimeToRunMinute $timeToRun -MaxConcurrentFaults $concurrentFaults -MaxClusterStabilizationTimeoutSec $maxStabilizationTimeSecs -EnableMoveReplicaFaults -WaitTimeBetweenIterationsSec $waitTimeBetweenIterationsSec -WaitTimeBetweenFaultsSec $waitTimeBetweenFaultsSec 

while($true)
{
    $webResponse = $null;

    $stopped = $false
    $report = Get-ServiceFabricChaosReport -StartTimeUtc $now -EndTimeUtc ([System.DateTime]::MaxValue)

    foreach ($e in $report.History) {

        if(-Not ($events.Contains($e.TimeStampUtc.Ticks)))
        {
            $events.Add($e.TimeStampUtc.Ticks, $e)
            if($e -is [System.Fabric.Chaos.DataStructures.ValidationFailedEvent])
            {
                Write-Host -BackgroundColor White -ForegroundColor Red $e
            }
            else
            {
                if($e -is [System.Fabric.Chaos.DataStructures.StoppedEvent])
                {
                    $stopped = $true
                }

                Write-Host $e
            }
        }
    }

    if($stopped -eq $true)
    {
        break
    }
    #test response, for example from web api three:
    #using the reverse proxy
    $webUri = "http://localhost:19081/PortSharingApplication/WebApiThree/api/values?PartitionKey=1&PartitionKind=Int64Range"
    $webResponse = Invoke-RestMethod -Uri $webUri -TimeoutSec 60
    if (!$webResponse) 
    {
        Write-Host "Test Failed!"
        Start-Sleep -Seconds 1
        break;
    }
    $webUri = "http://localhost:19081/PortSharingApplication/WebApiThree/api/values?PartitionKey=-1&PartitionKind=Int64Range"
    $webResponse = Invoke-RestMethod -Uri $webUri -TimeoutSec 60
    if (!$webResponse) 
    {
        Write-Host "Test Failed!"
        Start-Sleep -Seconds 1
        break;
    }
    Write-Host "Test OK"
    Start-Sleep -Seconds 1
}

Stop-ServiceFabricChaos
Write-Host "Test Done"