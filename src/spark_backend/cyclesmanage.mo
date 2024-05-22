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
import Debug "mo:base/Debug";

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
// 
shared (installation) actor class CyclesManage() ={

    type UserPreSaveInfo = types.UserPreSaveInfo;
    type CanisterInfo = types.CanisterInfo;
    type Rule = types.Rule;
    type CanistersResp = types.CanistersResp;
    type MintData = types.MintData;
    type Log = types.Log;
    type FeeLog = types.FeeLog;
    type BalanceLog = types.BalanceLog;

    type Management = actor { deposit_cycles : ({canister_id: Principal}) -> async (); };

    type Resp<T> = types.Resp<T>;

    // Some administrative functions are only accessible by who created this canister.
    let OWNER = installation.caller;
    let SELF : Principal = Principal.fromText(configs.CYCLES_MANAGER_ID);

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

    // 同一个canister可以被多个人添加管理
    private stable var canisterUidsMap = Map.new<Text, List.List<Text>>();
    private stable var userCanisterMap = Map.new<Text, List.List<CanisterInfo>>();
    private stable var canisterRulesMap = Map.new<Text, List.List<Rule>>();
    private stable var canisterBalanceMap = Map.new<Text, List.List<BalanceLog>>();
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

    func addTopUpLog(log: Log, cid: Text){
        var newLogs : List.List<Log> = List.nil();
        newLogs := List.push(log, newLogs);
        switch(Map.get(canisterTopupLogsMap, thash, cid)){
            case(null){
                Map.set(canisterTopupLogsMap, thash, cid, newLogs);
            };
            case(?logs){
                newLogs := List.append<Log>(newLogs, logs);
                Map.set(canisterTopupLogsMap, thash, cid, newLogs);
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
                    account = Utils.getUserSubAccountAddress(SELF, userCanisterId);
                    cycles = 0;
                    icp = 0;
                    status=#Normal;
                };
                Map.set(userPreSaveInfoMap, thash, uid, info);
                return info;
            };
            case(?preSaveInfo){
                let from_subaccount = Utils.principalToSubAccount(Principal.fromText(preSaveInfo.uid));
                let icpBalance = await ICP.icrc1_balance_of({ owner = SELF; subaccount = ?Blob.fromArray(from_subaccount) });
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

    public shared({caller}) func balance(): async (Nat){
        return Cycles.balance();
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
                let account = Blob.fromArray(AccountId.fromPrincipal(SELF, ?from_subaccount));
                let icpBalance = await ICP.account_balance({account = account});
                if (icpBalance.e8s < Nat64.fromNat(amount)){
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
                    icp = Nat64.toNat(icpBalance.e8s);
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

    public shared({caller}) func preSaveLogs(): async (Resp<[Log]>){
        let result : List.List<Log> = Option.get(Map.get(preSaveLogsMap, thash, Principal.toText(caller)), List.nil());
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
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
                    info = "manual topup " # Nat.toText(amount) # " cycles to canister : " # cid # "; topup by: " # userInfo.uid;
                    opeater = "";
                };
                addTopUpLog(log, cid);

                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };

    public shared func topUpLogs(cid: Text): async (Resp<[Log]>){
        let result : List.List<Log> = Option.get(Map.get(canisterTopupLogsMap, thash, cid), List.nil());
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
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
        // 用户canister映射
        var newCanisters : List.List<CanisterInfo> = List.make(canisterInfo);
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
                    case(?old){};
                };
            };
        };

        // canister uid 映射
        var newUids : List.List<Text> = List.make(Principal.toText(caller));
        switch(Map.get(canisterUidsMap, thash, cid)){
            case(null){
                Map.set(canisterUidsMap, thash, cid, newUids);
            };
            case(?uids){
                let exist = List.find<Text>(uids, func item { Text.equal(item, Principal.toText(caller)) });
                switch(exist){
                    case(null){
                        newUids := List.append(newUids, uids);
                        Map.set(canisterUidsMap, thash, cid, newUids);
                    };
                    case(?exist){};
                };
            };
        };
        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    // del canister
    public shared({caller}) func delCanister(cid: Text): async (Resp<Bool>) {
        assert(not Principal.isAnonymous(caller));
        if (not Utils.isCanister(Principal.fromText(cid))){
            return {
                code = 400;
                msg = "must be canister id";
                data = false;
            };
        };
        // 删除用户canister映射
        switch(Map.get(userCanisterMap, thash, Principal.toText(caller))){
            case(null){};
            case(?canisters){
                let newCanisters : List.List<CanisterInfo> = List.filter<CanisterInfo>(canisters, func item { not Text.equal(item.cid, cid) });
                Map.set(userCanisterMap, thash, Principal.toText(caller), newCanisters);
            };
        };
        // 删除规则
        switch(Map.get(canisterRulesMap, thash, cid)){
            case(null){};
            case(?rules){
                let newRules = List.filter<Rule>(rules, func item { not Text.equal(item.uid, Principal.toText(caller)) });
                if(Nat.equal(List.size(newRules), 0)){
                    Map.delete(canisterRulesMap, thash, cid);
                }else{
                    Map.set(canisterRulesMap, thash, cid, newRules);
                };
            };
        };

        // canister uid 映射
        switch(Map.get(canisterUidsMap, thash, cid)){
            case(null){};
            case(?uids){
                let newUids = List.filter<Text>(uids, func item { not Text.equal(item, Principal.toText(caller)) });
                if (Nat.equal(List.size(newUids), 0)){
                    // 没有用户关联管理，则删除规则、删除余额监控
                    Map.delete(canisterUidsMap, thash, cid);
                    Map.delete(canisterBalanceMap, thash, cid);
                    Map.delete(canisterRulesMap, thash, cid);
                }else{
                    Map.set(canisterUidsMap, thash, cid, newUids);
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
                        rule = List.toArray(Option.get(Map.get(canisterRulesMap, thash, item.cid), List.nil()));
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

    public shared({caller}) func canisterBalanceHistorys(cid: Text): async(Resp<[BalanceLog]>){
        let result = Option.get(Map.get(canisterBalanceMap, thash, cid), List.nil());
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
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

    public shared({caller}) func sysErrorLog(): async(Resp<[Log]>){
        // assert(caller == SELF or caller == OWNER);
        return {
            code = 200;
            msg = "";
            data = List.toArray(sysErrLogs);
        };
    };

    public shared({caller}) func feeLog(): async(Resp<[FeeLog]>){
        // assert(caller == SELF or caller == OWNER);
        return {
            code = 200;
            msg = "";
            data = List.toArray(feeLogs);
        };
    };

    // canister 定时任务方法： 定时获取已记录的canister balance --> 存储balance历史、查看是否有Rules，以及是否到达阈值，如到达则充值cycles。记录充值日志

    // 充值ICP到cmc canister
    public shared({caller}) func mintCycles(mintData: MintData): async(){
        assert(caller == SELF or caller == OWNER);
        switch(Map.get(userPreSaveInfoMap, thash, mintData.uid)){
            case(null){};
            case(?userInfo){
                let from_subaccount = Utils.principalToSubAccount(Principal.fromText(userInfo.uid)); // cycles manage for this user subaccount
                let to_subaccount = Utils.principalToSubAccount(SELF); // cycles manage subaccount 
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
                            Debug.print(debug_show(newMintData));
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
        assert(caller == SELF or caller == OWNER);
        let from_subaccount = Utils.principalToSubAccount(Principal.fromText(mintData.uid)); // cycles manage for this user subaccount
        try{
            let result = await ICP.icrc1_transfer({
                to = {owner = SELF; subaccount = null};
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
        assert(caller == SELF or caller == OWNER);
        switch(Map.get(userPreSaveInfoMap, thash, mintData.uid)){
            case(null){};
            case(?userInfo){
                // let starting_cycles = Cycles.balance();
                try{
                    let result = await CMC.notify_top_up({
                        block_index  = mintData.mintIndex;
                        canister_id = SELF;
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
                            // 这里返回的是兑换成功的cycles，所以可以同步改异步。
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
        assert(caller == SELF or caller == OWNER);

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

    // auto monitor canister
    // 监控更新canister余额，每八小时循环获取一次。每个canister保存最近30次记录
    public shared({caller}) func updateCanisterCycles(): async (){
        assert(caller == SELF or caller == OWNER);
        for(cid in Map.keys(canisterUidsMap)){
            let balance = (await BlackHole.canister_status({canister_id = Principal.fromText(cid)})).cycles;
            let log : BalanceLog = {
                time = Time.now();
                balance = balance;
            };
            var newBalances: List.List<BalanceLog> = List.make<BalanceLog>(log);
            switch(Map.get(canisterBalanceMap, thash, cid)){
                case(null){
                    Map.set(canisterBalanceMap, thash, cid, newBalances);
                };
                case(?oldBalances){
                    newBalances := List.append(newBalances, oldBalances);
                    if (Nat.greater(List.size(newBalances), 30)){
                        newBalances := List.take(newBalances, 30);
                    };
                    Map.set(canisterBalanceMap, thash, cid, newBalances);
                };
            };
        };
    };

    // 扫描规则，为匹配的canister充值cycles
    public shared({caller}) func scanRule(): async(){
        assert(caller == SELF or caller == OWNER);
        // 根据规则获取用户信息和cycles余额，为canister充值
        for((cid, rules) in Map.entries(canisterRulesMap)){

            var balance = (await BlackHole.canister_status({canister_id = Principal.fromText(cid)})).cycles;
            for (rule in List.toIter(rules)){
                // 余额小于规定阈值
                if (Nat.less(balance, rule.threshold)){
                    switch(Map.get(userPreSaveInfoMap, thash, rule.uid)){
                        case(null){};
                        case(?userInfo){
                            // 预存的cycles足够充值
                            if(Nat.greater(userInfo.cycles, rule.amount)){
                                let newUserInfo : UserPreSaveInfo = {
                                    uid = userInfo.uid;
                                    account = userInfo.account;
                                    icp = 0;
                                    cycles = (userInfo.cycles - rule.amount);
                                    status = userInfo.status;
                                };
                                // top up
                                Cycles.add<system>(rule.amount);
                                await IC.deposit_cycles({canister_id = Principal.fromText(cid)});

                                Map.set(userPreSaveInfoMap, thash, userInfo.uid, newUserInfo);

                                // log
                                let log : Log = {
                                    time = Time.now();
                                    info = "auto topup " # Nat.toText(rule.amount) # " cycles to canister : " # cid # "; topup by: " # userInfo.uid;
                                    opeater = "";
                                };
                                addTopUpLog(log, cid);

                                balance := Nat.add(balance, rule.amount);
                            };
                        };
                    };
                };
            };
        };

    };

    // 定时执行用户 mintcycles任务、canister-cycles-balance检查、自动充值规则执行
    private stable var processing : Bool = false;
    ignore Timer.recurringTimer<system>(#seconds(5) , func () : async(){
        if(processing){return};

        processing := true;

        await mintCyclesTask();

        processing := false;
    });

    // 每八小时执行一次
    ignore Timer.recurringTimer<system>(#seconds(10) , func () : async(){
        await updateCanisterCycles();
        await scanRule();
    });
}