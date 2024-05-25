# spark本地开发环境搭建部署命令记录

## 基础环境安装(本地环境初始化一次即可) ===========================================================================

#### 安装包管理工具
sudo npm i ic-mops -g

#### 安装 nns ic网络神经元拓展
dfx extension install nns

#### 安装测试admin身份
> cd ～/.config/dfx
```text
$ cat <<EOF >ident-1.pem
-----BEGIN EC PRIVATE KEY-----
MHQCAQEEICJxApEbuZznKFpV+VKACRK30i6+7u5Z13/DOl18cIC+oAcGBSuBBAAK
oUQDQgAEPas6Iag4TUx+Uop+3NhE6s3FlayFtbwdhRVjvOar0kPTfE/N8N6btRnd
74ly5xXEBNSXiENyxhEuzOZrIWMCNQ==
-----END EC PRIVATE KEY-----
EOF
```

#### nns配置设置
> 设置 ～/.config/dfx/networks.json
```json
{
  "local": {
    "bind": "127.0.0.1:8080",
    "type": "ephemeral",
    "replica": {
      "subnet_type": "system"
    }
  }
}
```

#### 导入身份
> $ dfx identity import ident-1 ident-1.pem  
> 该命令会在本地创建一个 ident-1的身份，该身份可以管理nns一些系统canister，也是本地ICP的所有账户  

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
mops add ic-websocket-cdk  

## 开发调试(本地测试启动) ===========================================================================  

#### 前端启动
npm start  

#### 后端启动

#### 方式一：脚本一键启动
> sudo chmod -R 777 backend_start.sh  
> ./backend_start.sh  

#### 方式二：选择启动
#### 启动ICP容器基础环境
> dfx start --background --clean  
> clean命令会以纯净模式启动，消除之前的记录  

#### 关闭ICP环境(dfx stop)
> 停止开发和测试后，执行该命令

#### 启动NNS官方基础canister
> dfx nns install  
> 会启动：cmc、rate、icp、governance、identity等基础canister环境(部分开发功能会需要)  
> 查看nns启动后ii地址：例如：internet_identity     http://qhbym-qaaaa-aaaaa-aaafq-cai.localhost:8080/
> 修改至 --- frontend/src/Hooks/useAuth/index.jsx的local地址。如果不变固定是这个地址就不用改


#### 编译代码，生成did文件等
dfx generate spark_user
dfx generate spark_workspace
dfx generate spark_backend
dfx generate spark_portal
dfx generate spark_cyclesmanage
dfx generate blackhole

#### 启动业务后端容器
dfx deploy spark_backend --specified-id bd3sg-teaaa-aaaaa-qaaba-cai
dfx deploy spark_portal --specified-id bkyz2-fmaaa-aaaaa-qaaaq-cai
dfx deploy blackhole --specified-id e3mmv-5qaaa-aaaah-aadma-cai
dfx deploy spark_cyclesmanage --specified-id vnrqu-jiaaa-aaaap-qhirq-cai

#### 启动gateway本地服务(websocket功能测试需要)
docker run -p 8081:8080 omniadevs/ic-websocket-gateway --ic-network-url http://host.docker.internal:8080
