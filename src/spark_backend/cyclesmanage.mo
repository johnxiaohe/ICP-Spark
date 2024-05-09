import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import List "mo:base/List";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";

import Map "mo:map/Map";
import { thash } "mo:map/Map";

import types "types";
import Utils "utils";
import ledger "ledgers";
import cmc "cmc";
import configs "configs";
import AccountId "AccountId";

// 用户cycles预存和信息管理(提供account地址，转账ICP，兑换成等额cycles)
// user - canister - name映射列表
// canister rules、historybalance、currentbalance
// canister cycles 余额定时记录，余额折线图(每天两次，记录近15天) 定时任务
// canister 充值规则管理(阈值、充值数量)
// canister 余额定时充值 定时任务
// 删除规则、删除canister记录
// 充值日志

// 运行流程方式： cycles账户是唯一的，所以mintcycles必须是同步的
// 用户打开gas station页面，可查看到用户accountid、presave-icp数量、presave-cycles数量
// 用户从其他Dapp充值ICP到提供的accountid
// 用户添加canister，设置别名。
// 用户对指定canister添加rule规则
// 刷新用户预存的 icp cycles信息
// 用户手动mint指定数量ICP为cycles，添加到mint队列，更改minting状态（检查余额是否足够，是否满足最小mint数额）
// canister定时任务（10S）
// 先检查cycles mint队列，为用户icp mint为cycles
// 后检查rule规则，为canister充值cycles
shared (installation) actor class CyclesManage() = self {

    type UserPreSaveInfo = types.UserPreSaveInfo;
    type CanisterInfo = types.CanisterInfo;
    type Rule = types.Rule;
    type CanisterMetaData = types.CanisterMetaData;
    type MintData = types.MintData;

    type Management = actor { deposit_cycles : ({canister_id: Principal}) -> async (); };

    type Resp<T> = types.Resp<T>;

    // Some administrative functions are only accessible by who created this canister.
    let OWNER = installation.caller;

    // ICP fees (TODO: this ideally should come from the ledger instead of being hard coded).
    let FEE = 10000 : Nat64;

    // Minimum ICP mint : 0.05 = 5000000
    let MIN_MINT_CIP = 5000000 : Nat64;


    // The current method of converting ICP to cycles is by sending ICP to the
    // cycle minting canister with a memo.
    let CYCLE_MINTING_CANISTER = Principal.fromText(configs.CMC_ID);
    let TOP_UP_CANISTER_MEMO = 0x50555054 : Nat64;

    type ICActor = Management;
    type CMCActor = cmc.Self;
    type Ledger = ledger.Self;


    let IC: ICActor = actor(configs.IC_ID);
    let ICP: Ledger = actor(configs.ICP_LEGDER_ID);
    let CMC: CMCActor = actor(configs.CMC_ID);

    private stable var userPreSaveInfoMap = Map.new<Text,UserPreSaveInfo>();
    // 转换ICP-cycles、topupcycles
    private stable var userPreSaveLogsMap = Map.new<Text, List.List<Text>>();
    private stable var mintDataIndex : Nat = 0;

    let errPreSaveInfo =  {uid="";account="";cycles=0;icp=0;status=#Normal};
    func getUserPreSaveInfo(userCanisterId: Principal): async UserPreSaveInfo{
        let uid = Principal.toText(userCanisterId);
        switch(Map.get(userPreSaveInfoMap, thash, uid)){
            case(null){
                let info: UserPreSaveInfo = {
                    uid = uid;
                    account = Utils.getUserSubAccountAddress(Principal.fromActor(self), userCanisterId);
                    cycles = 0;
                    icp = 0;
                    status=#Normal;
                };
                Map.set(userPreSaveInfoMap, thash, uid, info);
                return info;
            };
            case(?preSaveInfo){
                let from_subaccount = Utils.principalToSubAccount(Principal.fromText(preSaveInfo.uid));
                let icpBalance = await ICP.icrc1_balance_of({ owner = Principal.fromActor(self); subaccount = ?Blob.fromArray(from_subaccount) });
                return {
                    uid = preSaveInfo.uid;
                    account = preSaveInfo.account;
                    cycles = preSaveInfo.cycles;
                    icp = icpBalance;
                    status = preSaveInfo.status;
                };
            };
        };
    };

    // user-subaccount manager
    public shared({caller}) func preSaveInfo(): async (Resp<UserPreSaveInfo>){
        if(Utils.isCanister(caller)){
            return {
                code = 200;
                msg = "";
                data = await getUserPreSaveInfo(caller);
            };
        };
        return {
            code = 400;
            msg = "";
            data = errPreSaveInfo;
        };
    };

    // 手动预存指定ICP,添加预存信息到mint队列，修改用户状态
    public shared({caller}) func mint(amount: Nat64): async(){
        assert(not Principal.isAnonymous(caller));
        // 检查amount是否满足最小mint数量 (0.05ICP)
        if (amount < MIN_MINT_CIP){
            return;
        };
        switch(Map.get(userPreSaveInfoMap, thash, Principal.toText(caller))){
            case(null){};
            case(?userInfo){
                // 非正常状态的用户都不能再次mint
                if(not (userInfo.status == #Normal)){
                    return;
                };
                let from_subaccount = Utils.principalToSubAccount(caller); // cycles manage for this user subaccount
                let icpBalance = await ICP.icrc1_balance_of({ owner = Principal.fromActor(self); subaccount = ?Blob.fromArray(from_subaccount) });
                if (Nat64.fromNat(icpBalance) < amount){
                    return;
                };
                // add mint queue; update status
                let newUserInfo : UserPreSaveInfo = {
                    uid = userInfo.uid;
                    account = userInfo.account;
                    cycles = userInfo.cycles;
                    icp = icpBalance;
                    status = #Minting;
                };
                Map.set(userPreSaveInfoMap, thash, userInfo.uid, newUserInfo);
            };
        };
    };

    // user-monitor manager

    // user-cycles manager
    // transfer icp --- cycles (3% to self main account)
    public shared({caller}) func refresh(): async(){
        assert(not Principal.isAnonymous(caller));
        switch(Map.get(userPreSaveInfoMap, thash, Principal.toText(caller))){
            case(null){};
            case(?userPreSaveInfo){
                
                let from_subaccount = Utils.principalToSubAccount(caller); // cycles manage for this user subaccount

                let icpBalance = await ICP.icrc1_balance_of({ owner = Principal.fromActor(self); subaccount = ?Blob.fromArray(from_subaccount) });
                if (icpBalance == 0){

                };
                // cut service fee

                // mint cycles
                let to_subaccount = Utils.principalToSubAccount(Principal.fromActor(self)); // cycles manage subaccount 
                let mint_account = AccountId.fromPrincipal(CYCLE_MINTING_CANISTER, ?to_subaccount); // mint canister for cycles manage account
                try{
                    let result = await ICP.transfer({
                        to = Blob.fromArray(mint_account);
                        fee = {e8s = FEE};
                        memo = TOP_UP_CANISTER_MEMO;
                        from_subaccount = ?Blob.fromArray(from_subaccount);
                        amount = {e8s = Nat64.fromNat(icpBalance) - FEE};
                        created_at_time = null;
                    });
                    switch(result){
                        case(#Err(err)){

                        };
                        case(#Ok(blockIndex)){
                            let starting_cycles = Cycles.balance();
                            let topupResult = await CMC.notify_top_up({
                                block_index  = blockIndex;
                                canister_id = Principal.fromActor(self);
                            });
                            switch(topupResult){
                                case(#Err(err)){

                                };
                                case(#Ok(result)){
                                    let ending_cycles = Cycles.balance();
                                    if(ending_cycles < starting_cycles){

                                    };

                                };
                            }
                        };
                    };
                }catch(err){

                };
            };
        };
    };
    
    // 主动充值
    public shared({caller}) func topup(amount: Nat, cid: Text): async (){
        Cycles.add<system>(amount);
        await IC.deposit_cycles({canister_id = Principal.fromText(cid)});

    };

    // user deposit call back( refresh icp ledger for user subaccount )
    public shared({caller}) func monitorCanister(cid: Text, threshold: Nat, amount: Nat): async(){

    };

    public shared({caller}) func unMonitor(cid: Text): async(){

    };
    
}