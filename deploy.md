## spark本地开发环境搭建部署命令记录

#### 安装包管理工具
sudo npm i ic-mops -g

#### 安装 nns ic网络神经元拓展
dfx extension install nns

#### 初始化mops
mops init (有 mops.toml文件后可不执行该步骤)

#### 初始化包依赖
> mops包管理库地址：https://mops.one/
> 安装文档: https://j4mwm-bqaaa-aaaam-qajbq-cai.ic0.app/docs/install
##### 安装 mops.toml所有包文件
mops install

##### 安装指定包文件
mops add map
mops add base 

#### 启动ICP容器基础环境
clean命令会以纯净模式启动，消除之前的记录
dfx start --background --clean

#### 安装神经元官方基础canister
dfx nns install

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

#### 授权 和 转账
dfx canister call icp-ledger icrc2_approve '          
  record {
    amount = 100_010_000;
    spender = record {
      owner = principal "被授权人";
    };
  }
'
dfx canister call icp-ledger icrc1_transfer '(record {amount=1000000; to=record{owner=principal "2aa2k-fbfp4-bkpwq-yt6x4-erilk-t7sy3-x7zij-rvu4s-ocv32-dahpu-uqe"}})'


#### 启动业务后端容器
dfx deploy spark_backend --specified-id bd3sg-teaaa-aaaaa-qaaba-cai
dfx deploy spark_portal --specified-id bkyz2-fmaaa-aaaaa-qaaaq-cai
dfx deploy cmc --specified-id rkp4c-7iaaa-aaaaa-aaaca-cai  // 成功失败都无所谓




#### 编译生成did文件等
dfx generate spark_user
dfx generate spark_workspace