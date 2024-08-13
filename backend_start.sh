#!/bin/sh

dfx start --background --clean &&
dfx nns install && 
dfx generate spark_user && 
dfx generate spark_workspace && 
dfx generate spark_backend && 
dfx generate spark_portal && 
dfx generate spark_cyclesmanage && 
dfx generate blackhole && 
dfx deploy spark_backend && 
dfx deploy spark_portal && 
dfx deploy blackhole && 
dfx deploy spark_cyclesmanage