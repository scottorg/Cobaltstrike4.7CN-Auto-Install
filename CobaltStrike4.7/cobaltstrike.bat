rem Original Version
rem java -Dfile.encoding=UTF-8 -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+UseParallelGC -Duser.language=en -jar cobaltstrike-client.jar %*

rem CSAgent
java -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+UseParallelGC -javaagent:CSAgent.jar=CSAgent.properties -Duser.language=en -jar cobaltstrike-client.jar
