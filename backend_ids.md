### backend

spark_caiops xvn5s-6iaaa-aaaap-qhesq-cai

spark_cyclesmanage vnrqu-jiaaa-aaaap-qhirq-cai

spark_portal xhlkl-syaaa-aaaap-qherq-cai

spark_backend klii6-7yaaa-aaaap-qhv7a-cai

### frontend

spark_frontend  5wfnd-jiaaa-aaaap-qhwaa-cai

https://5wfnd-jiaaa-aaaap-qhwaa-cai.icp0.io
https://ic-spark.app


spark_caiops_frontend 4omya-hiaaa-aaaap-qhwea-cai

https://4omya-hiaaa-aaaap-qhwea-cai.icp0.io/




### history 
dfx wallet balance --ic

dfx canister create spark_main --with-cycles 200000000 --ic

dfx build spark_caiops --ic
dfx canister install spark_caiops --ic --wasm ./.dfx/ic/canisters/spark_caiops/spark_
caiops.wasm

dfx build spark_cyclesmanage --ic
dfx canister uninstall-code vnrqu-jiaaa-aaaap-qhirq-cai --ic
dfx canister install spark_cyclesmanage --ic --wasm ./.dfx/ic/canisters/spark_cyclesmanage/spark_cyclesmanage.wasm
dfx canister start vnrqu-jiaaa-aaaap-qhirq-cai --ic

dfx build spark_portal --ic
dfx canister uninstall-code xhlkl-syaaa-aaaap-qherq-cai --ic
dfx canister install spark_portal --ic --wasm ./.dfx/ic/canisters/spark_portal/spark_portal.wasm
dfx canister start xhlkl-syaaa-aaaap-qherq-cai --ic

dfx build spark_backend --ic
dfx canister install spark_backend --ic --wasm ./.dfx/ic/canisters/spark_backend/spark_backend.wasm

dfx canister update-settings --add-controller es6cc-o7jxo-ytzux-pddov-wbuac-bebfb-4772w-gl5dp-6vaag-qeja2-dqe vnrqu-jiaaa-aaaap-qhirq-cai



临时充值cycles方法
https://iclight.io/cyclesFinance/swap

后面通过caiops为各个容器充值，只需要补充caiops的cycles即可
