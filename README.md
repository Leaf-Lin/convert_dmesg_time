This script convert_dmesg_time.sh will help us correlate system events occurred in dmesg with other ES events by converting system time to human readable **local** time in dmesg.

_Disclaimer, the human readable output in dmesg may be off by few seconds._

**Usage:**
```
cd diagnostics-%datetime%
convert_dmesg_time.sh
```

**Prerequisite:**
It reads files collected from [ES support diagnostics tool](https://github.com/elastic/support-diagnostics). 
The following files must be present for it to work.
- dmesg.txt (with system timestamp)
- top.txt
- manifest.json


**Example input: (dmesg.txt)**
```
[    0.000000] Initializing cgroup subsys cpuset
[    0.000000] Initializing cgroup subsys cpu
[2518647.427425] Out of memory: Kill process 20757 (java) score 78 or sacrifice child
[2518647.433502] Killed process 20757 (java) total-vm:7901288kB, anon-rss:1275032kB, file-rss:11068kB
```

**Example output: (dmesg_human_readable_time.txt)**
```
 Boot at: 2018-06-14 19:17:43
 Collect: 2018-06-20 18:57:43
[2018-06-07 18:36:56] Initializing cgroup subsys cpuset
[2018-06-07 18:36:56] Initializing cgroup subsys cpu
[2018-07-06 22:14:23] Out of memory: Kill process 20757 (java) score 78 or sacrifice child
[2018-07-06 22:14:23] Killed process 20757 (java) total-vm:7901288kB, anon-rss:1275032kB, file-rss:11068kB
```

_Currently supports Mac (Darwin) and Linux, no windows support yet._




