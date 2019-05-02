function Get-CMUpdatesPending{
    <#
    .SYNOPSIS
    Get-CybCMUpdatesPending will query one or more computers for pending updates via Configuration Manager.
    .DESCRIPTION
    Get-CybCMUpdatesPending uses Get-CimInstance to query the CCM_SoftwareUpdate class for pending updates. It opens a CimSession and will first try to query over Wsman protocol and then over Dcom protocol if Wsman fails.
    .PARAMETER ComputerName
    Computer or computers to query.
    .PARAMETER ErrorLogFilePath
    Full path to where an optional error log should be stored.
    .EXAMPLE
    PS> Get-CybCMUpdatesPending -ComputerName SRV1
    Query one computer and only show/return the updates (if any).
    .EXAMPLE
    PS> Get-CybCMUpdatesPending -ComputerName SRV1 -ErrorLogFilePath C:\Temp\Errorlog.txt -Verbose
    Query one computer and store an error log under c:\temp\errorlog.txt with connection errors(if any). Using the '-verbose' to get a progression update from the script.
    .EXAMPLE
    PS> Get-CybCMUpdatesPending -ComputerName SRV1,SRV2,SRV3 -ErrorLogFilePath C:\Temp\Errorlog.txt -Verbose
    Query three computer and store an error log under c:\temp\errorlog.txt with connection errors(if any). Using the '-verbose' to get a progression update from the script.
    .EXAMPLE
    PS> Get-CybCMUpdatesPending -ComputerName (Get-Content C:\Temp\Servers.txt) -ErrorLogFilePath C:\Temp\Errorlog.txt -Verbose
    Using Get-Content to query a list of computers from a .txt file.
    .NOTES
    #>

    param(
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True)]
        [Alias('CN','Name','MachineName')]
        [string[]]$ComputerName,

        [string]$ErrorLogFilePath
    )

    BEGIN{
        function Convert-EvaluationStateValueToName{
            param(
                [Parameter(Mandatory=$true)]
                [int]$ResultCode
            )

            $Result = $ResultCode
                switch($ResultCode){
                    0
                        {
                        $Result = "None(0)"
                        }
                    1
                        {
                        $Result = "Available"
                        }
                    2
                        {
                        $Result = "Submitted"
                        }
                    3
                        {
                        $Result = "Detecting"
                        }
                    4
                        {
                        $Result = "PreDownload"
                        }
                    5
                        {
                        $Result = "Downloading"
                        }
                    6
                        {
                        $Result = "Wait Install"
                        }
                    7
                        {
                        $Result = "Installing"
                        }
                    8
                        {
                        $Result = "Pending Soft Reboot"
                        }
                    9
                        {
                        $Result = "Pending Hard Reboot"
                        }
                    10
                        {
                        $Result = "Wait Reboot"
                        }
                    11
                        {
                        $Result = "Verifying"
                        }
                    12
                        {
                        $Result = "Install Complete"
                        }
                    13
                        {
                        $Result = "Error"
                        }
                    14
                        {
                        $Result = "Wait Service Window"
                        }
                    15
                        {
                        $Result = "Wait User Logon"
                        }
                    16
                        {
                        $Result = "Wait User Logoff"
                        }
                    17
                        {
                        $Result = "Wait Job User Logon"
                        }
                    18
                        {
                        $Result = "Wait User Reconnect"
                        }
                    19
                        {
                        $Result = "Pending User Logoff"
                        }
                    20
                        {
                        $Result = "Pending Update"
                        }
                    21
                        {
                        $Result = "Waiting Retry"
                        }
                    22
                        {
                        $Result = "Wait Pres Mode Off"
                        }
                    23
                        {
                        $Result = "Wait For Orchestration"
                        }

                } #Switch
                return $Result
            
        } #Function

        #Check if we can use pending_update_log function or use verbose
        $LogVariable = Get-Command pending_update_log -ErrorAction SilentlyContinue

        #Set variable for incrementing foreach number
        [int]$number = 0

    } #Begin

    PROCESS{
        foreach ($computer in $ComputerName){
            #Add additional information to get a sens of progress status
            $number = $number+1
            if($LogVariable){
                pending_update_log -cat "space"
                pending_update_log -cat "Info" -t "***** $computer is object $number of $($ComputerName.Count)" -fgc "white"
            } else{           
                Write-Verbose "***** $computer is object $number of $($ComputerName.Count)"
            } #else
            
            #Set our prefered start protocol, if this is changed it will break the foreach computer+do loop.
            $Protocol = 'Wsman'

            Do{
                try{
                    #Establish session protocol
                    if ($Protocol -eq 'Dcom'){
                        $option = New-CimSessionOption -Protocol Dcom
                    } else {
                        $option = New-CimSessionOption -Protocol Wsman
                    } #else
                
                    #Open session to computer
                    if($LogVariable){
                        pending_update_log -cat "Info" -t "Connecting to $computer over $Protocol."
                    } else{
                        Write-Verbose "Connecting to $computer over $Protocol."
                    } # else
                    $session = New-CimSession -ComputerName $computer -SessionOption $option -ErrorAction Stop -ErrorVariable ErrorSession

                    #Query data
                    $ciminstance_parameters = @{'Namespace'='root\ccm\clientsdk'
                                                'ClassName'='CCM_SoftwareUpdate'
                                                'CimSession'=$session
                                                'ErrorAction'='Stop'
                                                'ErrorVariable'='ErrorInstance'}
                    
                    if($LogVariable){
                        pending_update_log -cat "Info" -t "Querying data from $computer."
                    } else {
                        Write-Verbose "Querying data from $computer."
                    } #else
                    $AllUpdates = Get-CimInstance @ciminstance_parameters
                
                    #Create an object for each update found and convert evaluationstatevalue to readable result
                    if($AllUpdates){
                        if($LogVariable){
                            pending_update_log -cat "Info" -t "Data retrieved from $computer, formatting to readable output."
                        } else {
                            Write-Verbose "Data retrieved from $computer, formatting to readable output."
                        } # else
                        foreach($update in $AllUpdates){
                            $JobState = Convert-EvaluationStateValueToName -ResultCode $update.EvaluationState
                            $properties = @{'ComputerName'=$computer
                                            'JobState'=$JobState
                                            'Name'=$update.name}
                            $obj = New-Object -TypeName psobject -Property $properties

                            #Output object
                            $obj | select ComputerName,JobState,Name
                    
                        } #Foreach Update
                        
                        $Protocol = 'Stop'
                    } #If allupdates
                
                    #If we find no updates, output an object with information
                    ElseIf(!$AllUpdates){
                        if($LogVariable){
                            pending_update_log -cat "Info" -t "Checking if there was no updates with compliance = 0"
                        } else{
                            Write-Verbose "Checking if there was no updates with compliance = 0"
                        } #else
                    
                        $properties = @{'ComputerName'=$computer
                                        'JobState'='Empty'
                                        'Name'="No updates found"}
                        $obj = New-Object -TypeName psobject -Property $properties

                        #Output object
                        $obj | select ComputerName,JobState,Name
                        
                        $Protocol = 'Stop'
                    } #ElseIf

                    if($LogVariable){
                        pending_update_log -cat "Info" -t "Closing connection to $computer"
                    } else{
                        Write-Verbose "Closing connection to $computer"
                    } #else
                    $session | Remove-CimSession                   

                    #If we have succesfully connected with dcom, stop the do loop.
                    if($Protocol -eq 'Dcom'){$Protocol = 'Stop'}
                } #Try
                # Try dcom if Wsman failes, then stop the do loop if Dcom failes
                Catch{
                    Switch ($Protocol){
                        'Wsman' {$Protocol = 'Dcom'
                            if($ErrorSession){
                                if($LogVariable){
                                    pending_update_log -cat "Error" -t "Failed to connect to $computer over Wsman." -fgc 'yellow'
                                } else{
                                    Write-Warning "Failed to connect to $computer over Wsman." 
                                } #else
                            } elseif($ErrorInstance){
                                if($LogVariable){
                                    pending_update_log -cat "Error" -t "Failed to query $computer over Wsman." -fgc 'yellow'
                                } else{
                                    Write-Warning "Failed to query $computer over Wsman."
                                } #else
                            } #elseif

                        }
                        'Dcom' {
                            $Protocol = 'Stop'
                            if($LogVariable){
                                pending_update_log -cat "Error" -t "Failed to connect to $computer over Dcom." -fgc 'yellow'
                            } else{
                                Write-Warning "Failed to connect to $computer over Dcom."
                            }
                            
                            $ErrorProperties = @{'ComputerName'=$computer
                                        'JobState'=$null
                                        'Name'="No connection to client"}
                            $ErrorObj = New-Object -TypeName psobject -Property $ErrorProperties
                            #$UpdatesOutput += New-Object -TypeName psobject -Property $properties

                            #Output object
                            $ErrorObj

                            if($PSBoundParameters.ContainsKey('ErrorLogFilePath')){
                                if($LogVariable){
                                    pending_update_log -cat "Information" -t "Logging error to $ErrorLogFilePath"
                                } else{
                                    Write-Verbose "Logging error to $ErrorLogFilePath"
                                } #else
                                Write-Output "$computer : $ErrorSession" | Out-File $ErrorLogFilePath -Append
                                Write-Output "$computer : $ErrorInstance" | Out-File $ErrorLogFilePath -Append
                            }
                        } #Dcom
                    } #Switch                    
                } #Catch
            } Until($Protocol -eq 'Stop')
        } #Foreach Computer
    } #Process

    END{
        #Left empty
    } #End
} #Function