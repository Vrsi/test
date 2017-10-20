#!/bin/bash

while read server; do
    scp $server:/mnt/data/indexes/wikipedia/slave_server_xvrsas00/list_of_uris /home/xvrsas00/Dokumenty/BP_testy
    mv /home/xvrsas00/Dokumenty/BP_testy/list_of_uris /home/xvrsas00/Dokumenty/BP_testy/list_of_uris_$server
done < servers.txt
#sssss
