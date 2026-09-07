' Original Version
' CreateObject("WScript.Shell").Run "java -Dfile.encoding=UTF-8 -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+UseParallelGC -Duser.language=en -jar cobaltstrike-client.jar %*",0

' CSAgent
CreateObject("WScript.Shell").Run "java -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+UseParallelGC -javaagent:CSAgent.jar=CSAgent.properties -Duser.language=en -jar cobaltstrike-client.jar %*",0

