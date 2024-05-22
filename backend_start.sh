#!/bin/sh

dfx start --background --clean &&
dfx nns install && 
dfx generate spark_user && 
dfx generate spark_workspace && 
dfx generate spark_backend && 
dfx generate spark_portal && 
dfx generate spark_cyclesmanage && 
dfx generate blackhole && 
dfx deploy spark_backend --specified-id bd3sg-teaaa-aaaaa-qaaba-cai && 
dfx deploy spark_portal --specified-id bkyz2-fmaaa-aaaaa-qaaaq-cai && 
dfx deploy blackhole --specified-id e3mmv-5qaaa-aaaah-aadma-cai && 
dfx deploy spark_cyclesmanage --specified-id vnrqu-jiaaa-aaaap-qhirq-cai