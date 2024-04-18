## spark本地开发环境搭建部署命令记录

#### 安装包管理工具
sudo npm i ic-mops -g

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

#### 拉取依赖第三方Canister资源文件
dfx deps pull

#### 初始化II身份认证本地容器罐
dfx deps init --argument '(null)' internet_identity
dfx deploy internet_identity

#### 启动本地Leger账本容器罐
dfx deploy icp-ledger --argument "(variant {
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
dfx deploy --backend




#### 编译生成did文件等
dfx generate