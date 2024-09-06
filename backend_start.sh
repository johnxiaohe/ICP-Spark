#!/bin/sh

dfx start --background --clean &&
dfx nns install && 
dfx generate spark_user && 
dfx generate spark_workspace && 
dfx generate spark_backend && 
dfx generate spark_portal && 
dfx generate spark_cyclesmanage && 
dfx generate blackhole && 
dfx deploy spark_backend --specified-id klii6-7yaaa-aaaap-qhv7a-cai && 
dfx deploy spark_portal --specified-id xhlkl-syaaa-aaaap-qherq-cai && 
dfx deploy blackhole --specified-id e3mmv-5qaaa-aaaah-aadma-cai && 
dfx deploy spark_cyclesmanage --specified-id vnrqu-jiaaa-aaaap-qhirq-cai &&
dfx deploy spark_caiops --specified-id xvn5s-6iaaa-aaaap-qhesq-cai