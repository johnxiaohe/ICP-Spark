import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import List "mo:base/List";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Time "mo:base/Time";
import Timer "mo:base/Timer";
import Error "mo:base/Error";
import Option "mo:base/Option";

import Map "mo:map/Map";
import { thash } "mo:map/Map";

import types "types";
import Utils "utils";
import ledger "ledgers";
import cmc "cmc";
import configs "configs";
import AccountId "AccountId";
import blackhole "blackhole";

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
    type CanistersResp = types.CanistersResp;
    type MintData = types.MintData;
    type Log = types.Log;
    type FeeLog = types.FeeLog;

    type Management = actor { deposit_cycles : ({canister_id: Principal}) -> async (); };

    type Resp<T> = types.Resp<T>;

    // Some administrative functions are only accessible by who created this canister.
    let OWNER = installation.caller;

    // ICP fees (TODO: this ideally should come from the ledger instead of being hard coded).
    let FEE = 10000 : Nat64;

    // Minimum ICP mint : 0.05 = 5000000
    let MIN_MINT_ICP = 5000000 : Nat;
    // CUT_FEE 0.001 ICP
    let CUT_FEE = 100000 : Nat;


    // The current method of converting ICP to cycles is by sending ICP to the
    // cycle minting canister with a memo.
    let CYCLE_MINTING_CANISTER = Principal.fromText(configs.CMC_ID);
    let TOP_UP_CANISTER_MEMO = 0x50555054 : Nat64;

    type ICActor = Management;
    type CMCActor = cmc.Self;
    type Ledger = ledger.Self;
    type BlackHoleActor = blackhole.Self;


    let IC: ICActor = actor(configs.IC_ID);
    let ICP: Ledger = actor(configs.ICP_LEGDER_ID);
    let CMC: CMCActor = actor(configs.CMC_ID);
    let BlackHole : BlackHoleActor = actor(configs.BLACK_HOLE_ID);

    private stable var userPreSaveInfoMap = Map.new<Text,UserPreSaveInfo>();
    // 转换ICP-cycles、topupcycles
    private stable var mintDataMap = Map.new<Text, MintData>();
    private stable var mintDataLogsMap = Map.new<Text, List.List<MintData>>();
    private stable var preSaveLogsMap = Map.new<Text, List.List<Log>>();
    private stable var sysErrLogs : List.List<Log> = List.nil();
    private stable var feeLogs : List.List<FeeLog> = List.nil();

    private stable var userCanisterMap = Map.new<Text, List.List<CanisterInfo>>();
    private stable var canisterRulesMap = Map.new<Text, List.List<Rule>>();
    private stable var canisterBalanceMap = Map.new<Text, List.List<Nat>>();
    private stable var canisterTopupLogsMap = Map.new<Text, List.List<Log>>();

    func addLog(log: Log, uid: Text){
        var newLogs : List.List<Log> = List.nil();
        newLogs := List.push(log, newLogs);
        switch(Map.get(preSaveLogsMap, thash, uid)){
            case(null){
                Map.set(preSaveLogsMap, thash, uid, newLogs);
            };
            case(?logs){
                newLogs := List.append<Log>(newLogs, logs);
                Map.set(preSaveLogsMap, thash, uid, newLogs);
            };
        };
    };

    // Convert Error to Text.
    func show_error(err: Error) : Text {
        debug_show({ error = Error.code(err); message = Error.message(err); })
    };
    func addSysErrLog(log: Log){
        sysErrLogs := List.push(log, sysErrLogs);
    };

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
    public shared({caller}) func aboutme(): async (Resp<UserPreSaveInfo>){
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
    public shared({caller}) func mint(amount: Nat): async(Resp<Bool>){
        assert(not Principal.isAnonymous(caller));
        // 检查amount是否满足最小mint数量 (0.05ICP)
        if (amount < MIN_MINT_ICP){
            return {
                code = 400;
                msg = "min icp mint amount : " # Nat.toText(MIN_MINT_ICP);
                data = false;
            };
        };
        switch(Map.get(userPreSaveInfoMap, thash, Principal.toText(caller))){
            case(null){
                return {
                    code = 404;
                    msg = "user info not found";
                    data = false;
                };
            };
            case(?userInfo){
                // 非正常状态的用户都不能再次mint
                if(not (userInfo.status == #Normal)){
                    return {
                        code = 400;
                        msg = "have a mint order";
                        data = false;
                    };
                };
                let from_subaccount = Utils.principalToSubAccount(caller); // cycles manage for this user subaccount
                let icpBalance = await ICP.icrc1_balance_of({ owner = Principal.fromActor(self); subaccount = ?Blob.fromArray(from_subaccount) });
                if (icpBalance < amount){
                    return {
                        code = 400;
                        msg = "balance not enought";
                        data = false;
                    };
                };
                // add mint queue
                let mintData : MintData = {
                    uid = userInfo.uid;
                    icp = amount;
                    cycles = 0;
                    mintIndex = 0;
                    notifyIndex = 0;
                    status = #Minting;
                    ctime = Time.now();
                    dtime = Time.now();
                };
                Map.set(mintDataMap, thash, userInfo.uid, mintData);
                let log : Log = {
                    time = Time.now();
                    info = "submit " # Nat.toText(amount) # " ICP mint cycles request";
                    opeater = "";
                };
                addLog(log, userInfo.uid);

                // update user status
                let newUserInfo : UserPreSaveInfo = {
                    uid = userInfo.uid;
                    account = userInfo.account;
                    cycles = userInfo.cycles;
                    icp = icpBalance;
                    status = #Minting;
                };
                Map.set(userPreSaveInfoMap, thash, userInfo.uid, newUserInfo);
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };

    // 手动充值cycles到指定canister
    public shared({caller}) func topup(amount: Nat, cid: Text): async (Resp<Bool>){
        assert(not Principal.isAnonymous(caller));
        switch(Map.get(userPreSaveInfoMap, thash, Principal.toText(caller))){
            case(null){
                return {
                    code = 404;
                    msg = "user not found";
                    data = false;
                };
            };
            case(?userInfo){
                if(Nat.less(userInfo.cycles, amount)){
                    return {
                        code = 200;
                        msg = "presave cycles balance not enought";
                        data = false;
                    };
                };
                
                // 用户充值cycles和mint cycles不冲突
                let newUserInfo : UserPreSaveInfo = {
                    uid = userInfo.uid;
                    account = userInfo.account;
                    icp = 0;
                    cycles = (userInfo.cycles - amount);
                    status = userInfo.status;
                };
                // top up
                Cycles.add<system>(amount);
                await IC.deposit_cycles({canister_id = Principal.fromText(cid)});

                Map.set(userPreSaveInfoMap, thash, userInfo.uid, newUserInfo);

                // log
                let log : Log = {
                    time = Time.now();
                    info = "manual topup " # Nat.toText(amount) # " cycles to canister : " # cid # "; cycles balance: " # Nat.toText(newUserInfo.cycles);
                    opeater = "";
                };
                addLog(log, userInfo.uid);

                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };

    // canisters manage
    public shared({caller}) func addCanister(cid: Text, name: Text): async (Resp<Bool>) {
        assert(not Principal.isAnonymous(caller));
        if (not Utils.isCanister(Principal.fromText(cid))){
            return {
                code = 400;
                msg = "must be canister id";
                data = false;
            };
        };
        let canisterInfo : CanisterInfo = {
            name = name;
            cid = cid;
        };
        var newCanisters : List.List<CanisterInfo> = List.nil();
        newCanisters := List.push(canisterInfo, newCanisters);
        switch(Map.get(userCanisterMap, thash, Principal.toText(caller))){
            case(null){
                Map.set(userCanisterMap, thash, Principal.toText(caller), newCanisters);
            };
            case(?canisters){
                let oldCInfo = List.find<CanisterInfo>(canisters, func item { Text.equal(item.cid, cid) });
                switch(oldCInfo){
                    case(null){
                        newCanisters := List.append<CanisterInfo>(newCanisters, canisters);
                        Map.set(userCanisterMap, thash, Principal.toText(caller), newCanisters);
                    };
                    case(old){};
                };
            };
        };
        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func canisters(): async (Resp<[CanistersResp]>){
        assert(not Principal.isAnonymous(caller));
        switch(Map.get(userCanisterMap, thash, Principal.toText(caller))){
            case(null){
                return {
                    code = 200;
                    msg = "";
                    data = [];
                }
            };
            case(?canisters){
                var result : List.List<CanistersResp> = List.nil();
                for(item in List.toIter(canisters)){
                    let canister : CanistersResp = {
                        cid = item.cid;
                        name = item.name;
                        cycles = (await BlackHole.canister_status({canister_id = Principal.fromText(item.cid)})).cycles;
                        rule = List.find<Rule>(Option.get(Map.get(canisterRulesMap, thash, item.cid), List.nil()), func item {Text.equal(item.uid, Principal.toText(caller))});
                    };
                    result := List.push(canister, result);
                };
                return {
                    code = 200;
                    msg = "";
                    data = List.toArray(result);
                }
            };
        };

    };

    public shared({caller}) func setRule(cid: Text, amount: Nat, threshold: Nat): async(Resp<Bool>) {
        assert(not Principal.isAnonymous(caller));
        let newRule : Rule = {
            amount = amount;
            threshold = threshold;
            uid = Principal.toText(caller);
        };
        var newRules : List.List<Rule> = List.nil();
        newRules := List.push(newRule, newRules);

        switch(Map.get(canisterRulesMap, thash, cid)){
            case(null){
                Map.set(canisterRulesMap, thash, cid, newRules);
            };
            case(?rules){
                newRules := List.append<Rule>(newRules, rules);
                Map.set(canisterRulesMap, thash, cid, newRules);
            };
        };
        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func delRule(cid: Text): async(Resp<Bool>){
        assert(not Principal.isAnonymous(caller));
        switch(Map.get(canisterRulesMap, thash, cid)){
            case(null){
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
            case(?rules){
                var newRules : List.List<Rule> = List.nil();
                for (rule in List.toIter(rules)){
                    if(not Text.equal(rule.uid, Principal.toText(caller))){
                        newRules := List.push(rule, newRules);
                    };
                };
                Map.set(canisterRulesMap, thash, cid, newRules);
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };

    // user-monitor manager
    // public shared({caller}) func canisterBalance

    // 充值ICP到cmc canister
    public shared({caller}) func mintCycles(mintData: MintData): async(){
        assert(caller == Principal.fromActor(self) or caller == OWNER);
        switch(Map.get(userPreSaveInfoMap, thash, mintData.uid)){
            case(null){};
            case(?userInfo){
                let from_subaccount = Utils.principalToSubAccount(Principal.fromText(userInfo.uid)); // cycles manage for this user subaccount
                let to_subaccount = Utils.principalToSubAccount(Principal.fromActor(self)); // cycles manage subaccount 
                let mint_account = AccountId.fromPrincipal(CYCLE_MINTING_CANISTER, ?to_subaccount); // mint canister for cycles manage account
                try{
                    // 扣减去 服务费和服务费转账的手续费
                    var amount = Nat.sub(mintData.icp, CUT_FEE);
                    amount := Nat.sub(mintData.icp, Nat64.toNat(FEE));
                    await cutfee(mintData);
                    // mint transfer
                    let result = await ICP.transfer({
                        to = Blob.fromArray(mint_account);
                        fee = {e8s = FEE};
                        memo = TOP_UP_CANISTER_MEMO;
                        from_subaccount = ?Blob.fromArray(from_subaccount);
                        amount = {e8s = Nat64.fromNat(amount) - FEE};
                        created_at_time = null;
                    });
                    switch(result){
                        case(#Err(err)){ // 没扣减成功,等待下次重试
                            let log : Log = {
                                time = Time.now();
                                info = debug_show (err);
                                opeater = userInfo.uid;
                            };
                            addSysErrLog(log);
                        };
                        case(#Ok(blockIndex)){
                            let newMintData : MintData = {
                                uid = userInfo.uid;
                                icp = mintData.icp;
                                cycles = 0;
                                mintIndex = blockIndex;
                                status = #Notifing;
                                ctime = mintData.ctime;
                                dtime = mintData.dtime;
                            };
                            Map.set(mintDataMap, thash, mintData.uid, newMintData);
                        };
                    };
                }catch(err){ // 没扣减成功,等待下次重试
                    let log : Log = {
                        time = Time.now();
                        info = show_error(err);
                        opeater = userInfo.uid;
                    };
                    addSysErrLog(log);
                };
            };
        };
    };

    public shared({caller}) func cutfee(mintData: MintData): async(){
        assert(caller == Principal.fromActor(self) or caller == OWNER);
        let from_subaccount = Utils.principalToSubAccount(Principal.fromText(mintData.uid)); // cycles manage for this user subaccount
        try{
            let result = await ICP.icrc1_transfer({
                to = {owner = Principal.fromActor(self); subaccount = null};
                fee = ?Nat64.toNat(FEE);
                memo = null;
                amount = CUT_FEE;
                from_subaccount = ?Blob.fromArray(from_subaccount);
                created_at_time = null;
            });
            switch(result){
                case(#Err(err)){ // 没扣减成功,等待下次重试
                    let log : Log = {
                        time = Time.now();
                        info = debug_show (err);
                        opeater = mintData.uid;
                    };
                    addSysErrLog(log);
                };
                case(#Ok(blockIndex)){
                    let log : FeeLog = {
                        mintIndex = mintData.mintIndex;
                        fee = CUT_FEE;
                        feeIndex = blockIndex;
                    };
                    feeLogs := List.push(log, feeLogs);
                };
            };
        }catch(err){
            let log : Log = {
                time = Time.now();
                info = show_error(err);
                opeater = mintData.uid;
            };
            addSysErrLog(log);
        };
    };

    // 通知cmc canister 生成cycles给self
    public shared({caller}) func notify(mintData: MintData): async(){
        assert(caller == Principal.fromActor(self) or caller == OWNER);
        switch(Map.get(userPreSaveInfoMap, thash, mintData.uid)){
            case(null){};
            case(?userInfo){
                // let starting_cycles = Cycles.balance();
                try{
                    let result = await CMC.notify_top_up({
                        block_index  = mintData.mintIndex;
                        canister_id = Principal.fromActor(self);
                    });
                    switch(result){
                        case(#Err(err)){ // 没有充值成功，等待下次充值
                            let log : Log = {
                                time = Time.now();
                                info = debug_show (err);
                                opeater = userInfo.uid;
                            };
                            addSysErrLog(log);
                        };
                        case(#Ok(topupcycles)){
                            // let ending_cycles = Cycles.balance();
                            // if (ending_cycles < starting_cycles) {
                            //     // TODO: add exception log
                            //     return;
                            // };
                            // let topupcycles : Nat = Nat.sub(ending_cycles, starting_cycles);
                            let newMintData : MintData = {
                                uid = userInfo.uid;
                                icp = mintData.icp;
                                cycles = topupcycles;
                                mintIndex = mintData.mintIndex;
                                status = #Down;
                                ctime = mintData.ctime;
                                dtime = Time.now();
                            };
                            // 删除出mintcycles队列
                            Map.delete(mintDataMap, thash, mintData.uid);

                            // 添加到用户mintdatalog中
                            var newMintLog : List.List<MintData> = List.nil();
                            newMintLog := List.push(newMintData, newMintLog);
                            switch(Map.get(mintDataLogsMap, thash, userInfo.uid)){
                                case(null){
                                    Map.set(mintDataLogsMap, thash, userInfo.uid, newMintLog);
                                };
                                case(?oldLogs){
                                    newMintLog := List.append(newMintLog, oldLogs);
                                    Map.set(mintDataLogsMap, thash, userInfo.uid, newMintLog);
                                };
                            };

                            // 更新用户cycles信息 和 状态
                            let newUserInfo : UserPreSaveInfo = {
                                uid = userInfo.uid;
                                account = userInfo.account;
                                cycles = Nat.add(userInfo.cycles, topupcycles);
                                icp = userInfo.icp;
                                status = #Normal;
                            };
                            Map.set(userPreSaveInfoMap, thash, userInfo.uid, newUserInfo);
                            
                            // 添加日志
                            let log : Log = {
                                time = Time.now();
                                info = "end " # Nat.toText(mintData.icp) # " ICP mint cycles request; mint cycles: " # Nat.toText(topupcycles);
                                opeater = "";
                            };
                            addLog(log, userInfo.uid);
                        };
                    };
                }catch(err){ // 等待下次重试
                    let log : Log = {
                        time = Time.now();
                        info = show_error(err);
                        opeater = userInfo.uid;
                    };
                    addSysErrLog(log);
                };
            };
        };
    };

    // 遍历mintDataMap，根据状态调用mintCycles或者notify。更新用户状态
    public shared({caller}) func mintCyclesTask(): async(){
        assert(caller == Principal.fromActor(self) or caller == OWNER);

        for(mintData in Map.vals(mintDataMap)){
            switch(mintData.status){
                case(#Normal){
                    Map.delete(mintDataMap, thash, mintData.uid);
                };
                case(#Minting){
                    try { await mintCycles(mintData) } catch(_) {};
                };
                case(#Notifing){
                    try { await notify(mintData) } catch(_) {};
                };
                case(#Down){
                    Map.delete(mintDataMap, thash, mintData.uid);
                };
            }
        };
    };

    // 定时执行用户 mintcycles任务、canister-cycles-balance检查、自动充值规则执行
    // private stable var processing : Bool = false;
    // ignore Timer.recurringTimer<system>(#seconds(5) , func () : async(){
    //     if(processing){return};

    //     processing := true;

    //     await mintCyclesTask();

    //     processing := false;
    // });
}