#[boundary.com] Windows Performance Counters Lua Plugin
#[author] Ivano Picco <ivano.picco@pianobit.com>

Try {

    $PdhLookupPerfNameByIndex = '[DllImport("pdh.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern UInt32 PdhLookupPerfNameByIndex(string szMachineName, uint dwNameIndex, System.Text.StringBuilder szNameBuffer, ref uint pcchNameBufferSize); [DllImport("pdh.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern UInt32 PdhLookupPerfIndexByName(string szMachineName, string szNameBuffer, ref uint pdwIndex);' 
    $t = Add-Type -MemberDefinition $PdhLookupPerfNameByIndex -PassThru -Name PerfCounter -Namespace Utility

}Catch {
 
}

function ConvertFrom-JSON {
    param(
        $json,
        [switch]$raw  
    )

    Begin
    {
    	$script:startStringState = $false
    	$script:valueState = $false
    	$script:arrayState = $false	
    	$script:saveArrayState = $false

    	function scan-characters ($c) {
    		switch -regex ($c)
    		{
    			"{" { 
    				"(New-Object PSObject "
    				$script:saveArrayState=$script:arrayState
    				$script:valueState=$script:startStringState=$script:arrayState=$false				
    			    }
    			"}" { ")"; $script:arrayState=$script:saveArrayState }

    			'"' {
    				if($script:startStringState -eq $false -and $script:valueState -eq $false -and $script:arrayState -eq $false) {
    					'| Add-Member -Passthru NoteProperty "'
    				}
    				else { '"' }
    				$script:startStringState = $true
    			}

    			"[a-z0-9A-Z@.\\%()*\/_ ]" { $c }

    			":" {" " ;$script:valueState = $true}
    			"," {
    				if($script:arrayState) { "," }
    				else { $script:valueState = $false; $script:startStringState = $false }
    			}	
    			"\[" { "@("; $script:arrayState = $true }
    			"\]" { ")"; $script:arrayState = $false }
    			"[\t\r\n]" {}
    		}
    	}
       
    	
    	function parse($target)
    	{
    		$result = ""
    		ForEach($c in $target.ToCharArray()) {	
    			$result += scan-characters $c
    		}
    		$result 	
    	}
    }

    Process { 
        if($_) { $result = parse $_ } 
    }

    End { 
        If($json) { $result = parse $json }

        If(-Not $raw) {
            $result | Invoke-Expression
        } else {
            $result 
        }
    }
}


function Get-PerformanceCounterLocalName
{
  param
  (
    [UInt32]$ID,
    $ComputerName = $env:COMPUTERNAME
  )

  $Buffer = New-Object System.Text.StringBuilder(1024)
  [UInt32]$BufferSize = $Buffer.Capacity

  $rv = [Utility.PerfCounter]::PdhLookupPerfNameByIndex($ComputerName, $id, $Buffer, [Ref]$BufferSize)
 
  if ($rv -eq 0)
  {
    $Buffer.ToString().Substring(0, $BufferSize-1)
  }
  else
  {
    Throw 'Get-PerformanceCounterLocalName : Unable to retrieve localized name. Check computer name and performance counter ID.'
  }
}

function Get-PerformanceCounterID
{
    param
    (
    [Parameter(Mandatory=$true)]$Name,
    $ComputerName = $env:COMPUTERNAME
    )
          
    [UInt32]$id = 0;

    $rv = [Utility.PerfCounter]::PdhLookupPerfIndexByName($ComputerName, $Name , [Ref]$id)
 
    if ($rv -eq 0){
        return $id
    } else {
        return -1
    }
    
}

function  Get-PerformanceCountersJSON {
    param 
    (
        [Parameter(Mandatory=$true)]$jsonfile
    )

    "{" | out-file -FilePath $jsonfile

    $counters  = Get-Counter -ListSet * | Select-Object -ExpandProperty CounterSetName
    for($i = 0; $i -lt $counters.count; $i+=1) {
        $counter_id = Get-PerformanceCounterID $counters[$i]
        $paths = Get-Counter -ListSet $counters[$i]  | Select-Object -ExpandProperty Paths
		$json =  '"'+ $counters[$i]  + '" : { "setIdx" :' + $counter_id + ', "counters" : {'
        for($j = 0; $j -lt $paths.count; $j+=1) {
            $path = $paths[$j]
            Try {
                $subpaths = $path.split('\')
                $path_id = Get-PerformanceCounterID $subpaths[2]

                $json += '"' + $subpaths[2] + '" : {"path" : "' + ($subpaths -join '\\') +'", "counterIdx" : '+ $path_id +'}'
			
			    if ($j -eq ($paths.count-1)) {}
			    else {$json += ','}
            } Catch {}
        }
		$json +=  ' }}'
        if ($i -eq ($counters.count-1)) {}
		else {$json +=','}

		$json | out-file -FilePath $jsonfile -Append
	}

    "}" | out-file -FilePath $jsonfile -Append
}

function  Get-CountersValueJSON {
    param 
    (
        [Parameter(Mandatory=$true)]$counters
    )

	$json = "["
    for($i = 0; $i -lt $counters.count; $i+=1) {
        $setIdx = $counters[$i].setIdx
        $cntIdx = $counters[$i].counterIdx
		
		$json += '{ "setIdx" :' + $setIdx + ', "counterIdx" : ' + $cntIdx + ', "metric" : "' +  $counters[$i].metric +'"'

        TRY{
            $_ = $counters[$i].instance.gettype()
            $instance = $counters[$i].instance
        } CATCH {
            $instance = -1
        }
        $hasInstances = ($counters[$i].path.split('*')).count - 1        
        
        $setName = Get-PerformanceCounterLocalName $setIdx
        $cntName = Get-PerformanceCounterLocalName $cntIdx
        
        if ($hasInstances ) {
            if ($instance -ge 0) {
                $setName+='(*)'
            } else {
                $setName+='(_Total)'
                $instance = 0
            }
        } else {
            $instance = 0
        }    

		$json += ', "value" : ' + (Get-Counter "\$setName\$cntName").CounterSamples[$instance].CookedValue

		if ($i -ne $counters.count-1) {
			$json += " }, "
		} else {
			$json += " }"
		}
	}
	$json += "]"
	return $json
}


#$jsonfile = "r:\metrics_it.json"
#Get-PerformanceCountersJSON -jsonfile $jsonfile

#Gets counters setup
$jsonfile = "tools\counters.json"
$cnts = (Get-Content $jsonfile) -join "`n"  | ConvertFrom-Json 

#Outputs counters value (JSON format)
Get-CountersValueJSON -Counters $cnts

#Force Exit
[Environment]::Exit(0)