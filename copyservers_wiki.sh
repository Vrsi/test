#!/bin/bash

while read server; do
    scp -r /home/xvrsas00/Dokumenty/CP_na_servery/slave_server_xvrsas00 $server:/mnt/data/indexes/wikipedia
done < servers.txt
<<<<<<< Updated upstream
# zmena zmena test1
# dalski
=======
# zkousim test2 test33
# test merge
# CO TU BUDE?
<<<<<<< Updated upstream
<<<<<<< Updated upstream
#sss
>>>>>>> Stashed changes
=======
#sss
>>>>>>> Stashed changes
=======
#sss
>>>>>>> Stashed changes
