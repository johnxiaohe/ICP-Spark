## 命令备忘录

#### [常用命令](https://internetcomputer.org/docs/current/developer-docs/developer-tools/cli-tools/cli-reference/dfx-ledger)
```text
身份相关------------------------------------------------

查看本地身份列表
dfx identity list
查看当前使用身份
dfx identity whoami
切换账户身份
dfx identity use name


资产相关-------------------------------------------------

查看指定身份的account id
dfx ledger --identity {idname} account-id

查看当前身份ICP余额
dfx ledger balance

转账ICP到指定身份(account-id可以从canister-dashboard的icpledger account-identity接口传入principal获取)
dfx ledger transfer --memo 12345 --icp 10 {account-id}

授权ICP给指定身份

查看当前身份cycles余额
dfx wallet balance

容器相关-------------------------------------------------

获取canister metadata
dfx canister status vnrqu-jiaaa-aaaap-qhirq-cai --ic
添加controller
dfx canister --network ic update-settings --add-controller e3mmv-5qaaa-aaaah-aadma-cai vnrqu-jiaaa-aaaap-qhirq-cai
删除canister
dfx canister delete --ic  canister-id
安装代码
dfx canister install vnrqu-jiaaa-aaaap-qhirq-cai --wasm=.dfx/ic/canisters/spark_cyclesmanage/spark_cyclesmanage.wasm --mode='reinstall' --ic
暂停canister
dfx canister stop vnrqu-jiaaa-aaaap-qhirq-cai --ic
启动canister
dfx canister start vnrqu-jiaaa-aaaap-qhirq-cai --ic
```




## 过时命令==================

#### 拉取依赖第三方Canister资源文件
dfx deps pull

#### 初始化II身份认证本地容器罐
dfx deps init --argument '(null)' internet_identity
dfx deps deploy internet_identity

#### 启动本地Leger账本容器罐
dfx deploy --specified-id ryjl3-tyaaa-aaaaa-aaaba-cai icp-ledger --argument "(variant {
    Init = record {
      minting_account = \"$(dfx ledger --identity anonymous account-id)\";
      initial_values = vec {
        record {
          \"$(dfx ledger --identity default account-id)\";
          record {
            e8s = 10_000_000_000 : nat64;
          };
        };
      };
      send_whitelist = vec {};
      transfer_fee = opt record {
        e8s = 10_000 : nat64;
      };
      token_symbol = opt \"icp\";
      token_name = opt \"local-icp\";
    }
  })
"

dfx deploy --specified-id um5iw-rqaaa-aaaaq-qaaba-cai cycles-ledger --argument "(variant {
    Init = record {
      minting_account = \"$(dfx ledger --identity anonymous account-id)\";
      initial_values = vec {
        record {
          \"$(dfx ledger --identity default account-id)\";
          record {
            e8s = 10_000_000_000 : nat64;
          };
        };
      };
      send_whitelist = vec {};
      transfer_fee = opt record {
        e8s = 10_000 : nat64;
      };
      token_symbol = opt \"cycles\";
      token_name = opt \"local-cycles\";
    }
  })
"

#### 查看钱包余额
dfx canister call icp-ledger account_balance '(record { account = '$(python3 -c 'print("vec{" + ";".join([str(b) for b in bytes.fromhex("'$(dfx ledger --identity default account-id)'")]) + "}")')'})'

dfx canister call ryjl3-tyaaa-aaaaa-aaaba-cai account_balance '(record { account = '$(python3 -c 'print("vec{" + ";".join([str(b) for b in bytes.fromhex("'$(dfx ledger --identity default account-id)'")]) + "}")')'})'

#### 授权 和 转账
dfx canister call icp-ledger icrc2_approve '          
  record {
    amount = 100_010_000;
    spender = record {
      owner = principal "被授权人";
    };
  }
'
dfx canister call icp-ledger icrc1_transfer '(record {amount=1000000000; to=record{owner=principal "be2us-64aaa-aaaaa-qaabq-cai"}})'

dfx canister call icp-ledger transfer '(record {amount=record{ e8s=1000000; } to=})'
