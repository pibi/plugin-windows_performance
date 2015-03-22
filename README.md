Boundary Windows Performance Counters Plugin
--------------------------
Collects statistics from Windows performance counters.

### Prerequisites

|     OS    | Linux | Windows | SmartOS | OS X |
|:----------|:-----:|:-------:|:-------:|:----:|
| Supported |       |    v    |         |      |


|  Runtime | node.js | Python | Java | LUA |
|:---------|:-------:|:------:|:----:|:---:|
| Required |         |       |       |  +  |


- [How to install Luvit (LUA)?](https://luvit.io/) 

### Plugin Setup

#### Installation of Luvit to test plugin

1. Compile Luvit from SRC

     ```Make.bat``` for Windows 
	 
2. You may use boundary-meter. Before params.json should be changed for choosen instances.

	```boundary-meter index.lua```

### Plugin Configuration Fields
|Field Name     |Description                                |
|:--------------|:------------------------------------------|
|Source         |display name                               |
|PollInterval   |Interval to query performance counters     |


### Metrics Collected

|Metric Name                      |Description                                                                                                   |
|:--------------------------------|:-------------------------------------------------------------------------------------------------------------|
|PROC - Perc Proc Time            |Percentage of the time the processor is busy                                                                  |
|MEM - Available Bytes            |Amount of memory available for allocation to a process or for system use                                      |
|MEM - Page Rate                  |Tracks the number of virtual memory pages read or written per second to or from the virtual memory file.      |
|PDISK - Disks Queue Length       |Tracks the average number of items in physical disks queue                                                    |
|PDISK - Disks Bytes Rate         |Current read or written rate to or from physical disks                                                        |
|PDISK - Perc Disks Time          |Percentage of the time the physical disks are busy servicing read or write requests                           |
|LDISK - Free disks space         |FreeSpace is the amount of total free storage space in bytes available on the logical disks                   |
|NET - Network receiving          |BytesReceivedPersec are the current transmission rates for the specified network card                         |
|NET - Network Queue Length       |Tracks the average number of items in the output queue of the specified network card                          |
|NET - Network sending            |BytesSentPersec are the current transmission rates for the specified network card                             |
|TCP4 - Connections               |TCP4ConnectionEstablished,  is the current number of established connections, inbound and outbound            |
|TCP6 - Connections               |TCP6ConnectionEstablished,  is the current number of established connections, inbound and outbound            |
