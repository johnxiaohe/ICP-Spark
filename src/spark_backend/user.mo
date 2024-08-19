import Prim "mo:prim";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import List "mo:base/List";
import Text "mo:base/Text";
import Bool "mo:base/Bool";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
// import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Option "mo:base/Option";
import Iter "mo:base/Iter";

import Map "mo:map/Map";
import { thash } "mo:map/Map";

import ic "ic";
import types "types";
import Utils "utils";
import Ledger "ledgers";
import configs "configs";
import WorkSpace "workspace";

// 用户的canisterid是唯一标识符，作为主键和对外关联关系字段
shared({caller}) actor class UserSpace(
    _name: Text,
    _owner: Principal,
    _avatar: Text, 
    _desc: Text, 
    _ctime: Time.Time,
) = this{

    type ICActor = ic.ICActor;
    let IC: ICActor = actor(configs.IC_ID);

    // 用户接口api类型声明
    type BaseUserInfo = types.BaseUserInfo;
    type User = types.User;
    type UserDetail = types.UserDetail;
    type Collection = types.Collection;
    type MyWorkspaceResp = types.MyWorkspaceResp;
    type MyWorkspace = types.MyWorkspace;
    type RecentWork = types.RecentWork;
    type RecentEdit = types.RecentEdit;
    type Resp<T> = types.Resp<T>;

    type WorkSpaceInfo = types.WorkSpaceInfo;
    type WorkSpaceBaseInfo = types.WorkSpaceBaseInfo;
    type ApproveArgs = Ledger.ApproveArgs;
    type TransferArg = Ledger.TransferArg;
    type UserPreSaveInfo = types.UserPreSaveInfo;

    // 第三方api actor类型声明
    type LedgerActor = Ledger.Self;
    type UserActor = types.UserActor;
    type WorkActor = types.WorkActor;
    type SparkActor = types.SparkActor;
    type CyclesManageActor = types.CyclesManageActor;
    type CanisterOps = types.CanisterOps;

    type CanistersResp = types.CanistersResp;

    // 常量声明
    private stable var cyclesPerNamespace: Nat = 20_000_000_000; // 0.02t cycles for each token canister

    // 用户元信息
    private stable var owner : Principal = _owner;
    private stable var name : Text = _name;
    private stable var avatar : Text = _avatar;
    private stable var desc : Text = _desc;
    private stable var ctime : Time.Time = _ctime;

    // 用户隐私显示开关
    private stable var _showfollow: Bool = true;
    private stable var _showfans: Bool = true;
    private stable var _showcollection: Bool = true;
    private stable var _showsubscribe: Bool = true;

    // 用户交互数据
    private stable var _follows: List.List<Text> = List.nil();
    private stable var _fans: List.List<Text> = List.nil();
    private stable var _collections: List.List<Collection> = List.nil();
    private stable var _subscribes: List.List<Text> = List.nil();

    // 用户参与的空间
    private stable var _workspaces = Map.new<Text,MyWorkspace>();
    // 最近创作记录
    private stable var _RECENT_SIZE : Nat = 10;
    private stable var _recentWorks : List.List<RecentWork> = List.nil();
    private stable var _recentEdits : List.List<RecentEdit> = List.nil();

    // 全局 actor api client 预创建
    let spark : SparkActor = actor (configs.SPARK_MAIN_ID);
    let cyclesmanage : CyclesManageActor = actor (configs.CYCLES_MANAGER_ID);
    let icpLedger: LedgerActor = actor(configs.ICP_LEGDER_ID);
    let cyclesLedger: LedgerActor = actor(configs.CYCLES_LEGDER_ID);
    let CaiOps : CanisterOps = actor(configs.SPARK_CAIOPS_ID);

    // token类型 actor 预存，用于 转账和余额查询等
    private let tokenMap = HashMap.HashMap<Text, LedgerActor>(3, Text.equal, Text.hash);
    tokenMap.put("ICP", icpLedger);
    tokenMap.put("CYCLES", cyclesLedger);

    public shared({caller}) func initArgs(): async(Blob){
        if(Principal.equal(caller, Principal.fromText(configs.SPARK_CAIOPS_ID))){
            return to_candid(name,owner,avatar,desc,ctime);
        };
        return to_candid();
    };

    public shared({caller}) func version(): async (Text){
        return "v1.0.5"
    };

    public shared({caller}) func childCids(moduleName: Text): async ([Text]){
        if (not Principal.equal(caller, Principal.fromText(configs.SPARK_CAIOPS_ID))){
            return [];
        };
        if (Text.equal(moduleName, "workspace")){
            let workspaces : List.List<MyWorkspace> = Iter.toList<MyWorkspace>(Map.vals(_workspaces));
            let owneIds = List.mapFilter<MyWorkspace, Text>(workspaces, func item {
                if (item.owner){
                    return ?item.wid;
                }else{
                    return null;
                };
            });
            return List.toArray(owneIds);
        };
        return [];
    };

    // 更新用户信息，回调用户管理模块更新全局存储的用户信息
    public shared({caller}) func updateInfo(newName: Text, newAvatar: Text, newDesc: Text): async Resp<User>{
        if (not Principal.equal(caller,owner)){
            return {
                code=403;
                msg="permision denied";
                data={id=Principal.toText(caller);avatar="";desc="";name="";pid=Principal.toText(caller);ctime=0};
            };
        };
        name := newName;
        avatar := newAvatar;
        desc := newDesc;
        await spark.userUpdateCall(owner,newName,newAvatar,newDesc);
        return {
            code=200;
            msg="";
            data={
                id=Principal.toText(Principal.fromActor(this));
                pid=Principal.toText(owner);
                name=name;
                avatar=avatar;
                desc=desc;
                ctime=ctime;
            };
        };
    };

    public shared func baseUserInfo(): async Resp<BaseUserInfo>{
        return {
            code=200;
            msg="";
            data={
                id=Principal.toText(Principal.fromActor(this));
                name=name;
                avatar=name;
            };
        };
    };

    public shared func info(): async Resp<User>{
        return {
            code=200;
            msg="";
            data={
                id=Principal.toText(Principal.fromActor(this));
                pid=Principal.toText(owner);
                name=name;
                avatar=avatar;
                desc=desc;
                ctime=ctime;
            };
        };
    };

    public shared func getAvatar(): async Resp<Text>{
        return {
            code = 200;
            msg = "";
            data = avatar;
        };
    };

    public shared func detail(): async(Resp<UserDetail>) {
        return {
            code=200;
            msg="";
            data={
                id=Principal.toText(Principal.fromActor(this));
                pid=Principal.toText(owner);
                name=name;
                avatar=avatar;
                desc=desc;
                ctime=ctime;
                followSum = List.size(_follows);
                fansSum = List.size(_fans);
                collectionSum=List.size(_collections);
                subscribeSum=List.size(_subscribes);
                showfollow = _showfollow;
                showfans = _showfans;
                showcollection = _showcollection;
                showsubscribe = _showsubscribe;
            };
        };
    };

    public shared func status(): async (ic.CanisterStatus){
        return await IC.canister_status(Principal.fromActor(this));
    };

    public query func canisterMemory() : async Resp<Nat> {
        return {
            code = 200;
            msg = "";
            data = Prim.rts_memory_size();
        };
    };

    public shared func balance(token: Text): async Resp<Nat>{
        switch(tokenMap.get(token)){
            case(null){
                return {
                    code = 404;
                    msg = "token not found";
                    data = 0;
                };
            };
            case(?ledger){
                return {
                    code = 200;
                    msg = "";
                    data = await ledger.icrc1_balance_of({owner=Principal.fromActor(this); subaccount=null});
                };
            };
        };
    };

    public shared func fee(token: Text): async Resp<Nat>{
        switch(tokenMap.get(token)){
            case(null){
                return {
                    code = 404;
                    msg = "token not found";
                    data = 0;
                };
            };
            case(?ledger){
                return {
                    code = 200;
                    msg = "";
                    data = await ledger.icrc1_fee();
                };
            };
        };
    };

    public shared func cycles(): async Resp<Nat>{
        return {
            code = 200;
            msg = "";
            data = Cycles.balance();
        };
    };

    public shared({caller}) func withdrawals(token: Text, amount: Nat, reciver: Text): async Resp<Nat>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = 0;
            };
        };
        switch(tokenMap.get(token)){
            case(null){
                return {
                    code = 404;
                    msg = "unsuport token: " # token;
                    data = 0;
                };
            };
            case(?ledger){
                let feeAmount = await ledger.icrc1_fee();
                let transferArgs : Ledger.TransferArgs = {
                    memo = null;
                    amount = amount;
                    from_subaccount = null;
                    fee = ?feeAmount;
                    to = { owner = Principal.fromText(reciver); subaccount = null };
                    created_at_time = null;
                };
                try {
                    // initiate the transfer
                    let transferResult = await ledger.icrc1_transfer(transferArgs);

                    // check if the transfer was successfull
                    switch (transferResult) {
                        case (#Err(transferError)) {
                            return {
                                code = 500;
                                msg = "Couldn't transfer funds:\n" # debug_show (transferError);
                                data = 0;
                            };
                        };
                        case (#Ok(blockIndex)) { 
                            return {
                                code = 200;
                                msg = "";
                                data = blockIndex;
                            };
                        };
                    };
                } catch (error : Error) {
                    // catch any errors that might occur during the transfer
                    return {
                        code = 500;
                        msg = "Reject message: " # Error.message(error);
                        data = 0;
                    };
                };
            };
        };
    };

    // ICP 转账: 使用原始的transfer方法 从usercanister 转账ICP到指定 account identifier. amount是 icp数量 * 10^8
    public shared({caller}) func presaveICP(amount: Nat, accountId: Text): async Resp<Nat64>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = 0;
            };
        };
        let balance = await icpLedger.icrc1_balance_of({owner = Principal.fromActor(this); subaccount = null});
        if(Nat.greater((amount + 10_000), balance)){
            return {
                code = 400;
                msg = "balance not enought";
                data = 0;
            };
        };
        let transferArg : TransferArg = {
            to = Blob.fromArray(Utils.fromHex(accountId));
            fee = { e8s = 10_000 };
            memo = 0x481;
            from_subaccount = null;
            amount = {e8s = Nat64.fromNat(amount)};
            created_at_time = null;
        };
        try {
            let result = await icpLedger.transfer(transferArg);
            switch(result){
                case(#Err(transferError)){
                    return {
                        code = 500;
                        msg = debug_show(transferError);
                        data = 0;
                    };
                };
                case(#Ok(blockIndex)) {
                    return {
                        code = 200;
                        msg = "";
                        data = blockIndex;
                    };
                };
            }
        }catch(err : Error){
            return {
                code = 500;
                msg = Error.message(err);
                data = 0;
            };
        };
    };

    // cycles 管理 api --------------------------------------
    public shared({caller}) func aboutme(): async Resp<UserPreSaveInfo>{
        assert(Principal.equal(caller, owner));
        return await cyclesmanage.aboutme();
    };

    public shared({caller}) func mint(amount: Nat) : async Resp<Bool> {
        assert(Principal.equal(caller, owner));
        return await cyclesmanage.mint(amount);
    };

    public shared({caller}) func canisters(): async Resp<[CanistersResp]> {
        assert(Principal.equal(caller, owner));
        return await cyclesmanage.canisters();
    };

    public shared({caller}) func addCanister(cid: Text, name: Text): async Resp<Bool>{
        assert(Principal.equal(caller, owner));
        return await cyclesmanage.addCanister(cid, name);
    };

    public shared({caller}) func delCanister(cid: Text): async (Resp<Bool>){
        assert(Principal.equal(caller, owner));
        return await cyclesmanage.delCanister(cid);
    };

    public shared({caller}) func setRule(cid: Text, amount: Nat, threshold: Nat): async(Resp<Bool>) {
        assert(Principal.equal(caller, owner));
        return await cyclesmanage.setRule(cid, amount, threshold);
    };
    
    public shared({caller}) func delRule(cid: Text): async(Resp<Bool>){
        assert(Principal.equal(caller, owner));
        return await cyclesmanage.delRule(cid);
    };

    public shared({caller}) func topup(amount: Nat, cid: Text): async (Resp<Bool>){
        assert(Principal.equal(caller, owner));
        return await cyclesmanage.topup(amount, cid);
    };

    // user meta data manage-----------------------------------
    // a follow b => a.follow b.fans relation: uid -- uid
    public shared({caller}) func hvFollowed(uid: Text): async Resp<Bool> {
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let fuid = Option.get(List.find<Text>(_follows, func item {Text.equal(item, uid)}), "");
        if (Text.equal(fuid, uid)){
            return {
                code = 200;
                msg = "";
                data = true;
            };
        };
        return {
            code = 200;
            msg = "";
            data = false;
        };
    };

    public shared({caller}) func addFollow(uid: Text): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let fuid = Option.get(List.find<Text>(_follows, func item {Text.equal(item, uid)}), "");
        if(Text.equal(fuid, uid)){
            return {
                code = 400;
                msg = "follwed";
                data = false;
            };
        };
        // add target fans relation
        let userActor : UserActor = actor(uid);
        let success = await userActor.addFans();
        if (success){
            // add follow relation
            _follows := List.push(uid, _follows);
        };
        return {
            code = 200;
            msg = "";
            data = success;
        };
    };

    public shared({caller}) func unFollow(uid: Text): async Resp<Bool> {
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // add target fans relation
        let userActor : UserActor = actor(uid);
        let success = await userActor.delFans();
        if (success){
            // find and del target
            _follows := List.filter<Text>(_follows, func target { not Text.equal(uid, target) });
        };
        return {
            code = 200;
            msg = "";
            data =  success;
        };
    };

    public shared({caller}) func follows(): async Resp<[BaseUserInfo]> {
        if ( not _showfollow and not Principal.equal(caller, owner) ){
            return {
                code = 403;
                msg = "secret model";
                data = [];
            };
        };
        var result: List.List<BaseUserInfo> = List.nil();
        for (uid in List.toIter<Text>(_follows)) {
            let userActor : UserActor = actor(uid);
            let user = await userActor.baseUserInfo();
            result := List.push(user.data, result);
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared({caller}) func changeFollowDisplay(): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        _showfollow := not _showfollow;
        return {
            code = 200;
            msg = "";
            data = _showfollow;
        };
    };

    public shared({caller}) func addFans(): async Bool{
        // call by other user canister 
        if (Principal.equal(caller,owner)){
            return false;
        };
        let uid = Option.get(List.find<Text>(_fans, func item {Text.equal(item, Principal.toText(caller))}), "");
        if(Text.equal(uid , "")){
            _fans := List.push(Principal.toText(caller), _fans);
        };
        return true;
    };

    public shared({caller}) func delFans(): async Bool{
        if (Principal.equal(caller,owner)){
            return false;
        };
        _fans := List.filter<Text>(_fans, func uid { not Text.equal(uid, Principal.toText(caller)) });
        return true;
    };

    public shared({caller}) func fans(): async Resp<[BaseUserInfo]> {
        if ( not _showfans and not Principal.equal(caller, owner) ){
            return {
                code = 403;
                msg = "secret model";
                data = [];
            };
        };
        var result: List.List<BaseUserInfo> = List.nil();
        for (uid in List.toIter<Text>(_fans)) {
            let userActor : UserActor = actor(uid);
            let user = await userActor.baseUserInfo();
            result := List.push(user.data, result);
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared({caller}) func changeFansDisplay(): async Resp<Bool> {
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        _showfans := not _showfans;
        return {
            code = 200;
            msg = "";
            data = _showfans;
        };
    };

    // 收藏、取消收藏、收藏列表
    public shared({caller}) func hvCollectioned(wid: Text, index: Nat): async Resp<Bool> {
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let cc = List.find<Collection>(_collections, func item {Text.equal(item.wid, wid) and Nat.equal(item.index, index)});
        switch(cc){
            case(null){
                return {
                    code = 200;
                    msg = "";
                    data = false;
                };
            };
            case(?cc){
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };
    public shared({caller}) func collection(wid: Text, index: Nat): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let cc = List.find<Collection>(_collections, func item {Text.equal(item.wid, wid) and Nat.equal(item.index, index)});
        switch(cc){
            case(null){
                let waitCollection : Collection = {wid=wid;wName="";index=index;name="";time=Time.now()};
                _collections := List.push(waitCollection, _collections);
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
            case(?cc){
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };

    };

    public shared({caller}) func unCollection(wid: Text, index:Nat): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // find and del target
        _collections := List.filter<Collection>(_collections, func c { not Text.equal(c.wid,wid) or not Nat.equal(c.index, index) });
        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func collections(): async Resp<[Collection]>{
        if ( not _showcollection and not Principal.equal(caller, owner) ){
            return {
                code = 403;
                msg = "secret model";
                data = [];
            };
        };
        var result : List.List<Collection> = List.nil();
        for (c in List.toIter(_collections)){
            let wActor : WorkActor = actor(c.wid);
            let cresp = await wActor.collectionCall(c.index);
            let rc = {
                wid=c.wid;
                index=c.index;
                wName= cresp.data.wName;
                name= cresp.data.name;
                time = c.time;
            };
            result := List.push( rc, result);
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared({caller}) func changeCollectionDisplay(): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        _showcollection := not _showcollection;
        return {
            code = 200;
            msg = "";
            data = _showcollection;
        };
    };

    // 订阅列表、添加、删除订阅。关联标识为目标workspace的 priciaplid
    public shared({caller}) func hvSubscribed(wid: Text): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let id = List.find<Text>(_subscribes, func item { Text.equal(item, wid) });
        switch (id){
            case(null){
                return {
                    code = 200;
                    msg = "";
                    data = false;
                };
            };
            case(?id){
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };

    public shared({caller}) func subscribe(wid: Text): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let id = List.find<Text>(_subscribes, func item { Text.equal(item, wid) });
        switch (id){
            case(null){};
            case(?id){
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
        let workActor : WorkActor = actor(wid);
        let workResp = await workActor.info();
        let workInfo = workResp.data;
        if(workInfo.model == #Private){
            return {
                code = 403;
                msg = "private work space";
                data = false;
            };
        };
        if(workInfo.model == #Subscribe and workInfo.price > 0){
            // 授权转账；检查余额
            let args : ApproveArgs = {
                fee = null;
                memo = null;
                from_subaccount = null;
                created_at_time = null;
                expected_allowance = null;
                expires_at =null;
                amount = workInfo.price + 1000000;
                spender = {owner=Principal.fromText(wid); subaccount=null};
            };
            let transferResult = await icpLedger.icrc2_approve(args);
            // check if the transfer was successfull
            switch (transferResult) {
                case (#Err(transferError)) {
                    return {
                        code = 500;
                        msg = "Couldn't approve funds:\n" # debug_show (transferError);
                        data = false;
                    };
                };
                case (#Ok(blockIndex)) {
                };
            };
        };
        let resp = await workActor.subscribe();
        if (resp.code != 200){
            return resp;
        };
        _subscribes := List.push(wid, _subscribes);
        return resp;
    };

    // 主动取消订阅
    public shared({caller}) func unsubscribe(wid: Text): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let workActor : WorkActor = actor(wid); 
        let resp = await workActor.unSubscribe();
        if (resp.code != 200){
            return resp;
        };
        _subscribes := List.filter<Text>(_subscribes, func id { not Text.equal(id, wid) });
        return resp;
    };

    // 被动取消订阅
    public shared({caller}) func quitSubscribe(): async(){
       _subscribes := List.filter<Text>(_subscribes, func wid { not Text.equal(wid, Principal.toText(caller))});
    };

    public shared({caller}) func subscribes(): async Resp<[WorkSpaceBaseInfo]> {
        if ( not _showsubscribe and not Principal.equal(caller, owner) ){
            return {
                code = 403;
                msg = "secret model";
                data = [];
            };
        };
        var result: List.List<WorkSpaceBaseInfo> = List.nil();
        for (wid in List.toIter<Text>(_subscribes)) {
            let workActor : WorkActor = actor(wid); 
            let worksBaseInfo = await workActor.baseInfo();
            result := List.push(worksBaseInfo.data, result);
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared({caller}) func changeSubscribeDisplay(): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        _showsubscribe := not _showsubscribe;
        return {
            code = 200;
            msg = "";
            data = _showsubscribe;
        };
    };

    // 工作空间列表、创建工作空间、转让工作空间、退出工作空间、加入工作空间
    public shared({caller}) func workspaces(): async(Resp<[MyWorkspaceResp]>){
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = [];
            };
        };
        var result : List.List<MyWorkspaceResp> = List.nil();
        for (work in Map.vals(_workspaces)){
            let workActor: WorkActor = actor(work.wid);
            let workResp = await workActor.info();
            let workInfo : WorkSpaceInfo= workResp.data;
            let mywork: MyWorkspaceResp = {
                wid = workInfo.id;
                name = workInfo.name;
                desc = workInfo.desc;
                owner = Text.equal(Principal.toText(Principal.fromActor(this)), workInfo.super);
                start = work.start;
                avatar = workInfo.name; // 因为接口最大传输2MB，所以头像由客户端异步获取
            };
            result := List.push(mywork, result);
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared({caller}) func createWorkNs(name: Text, desc: Text, avatar: Text, model: types.ShowModel, price: Nat): async(Resp<Bool>){
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        Cycles.add<system>(cyclesPerNamespace);
        let ctime = Time.now();
        var payPrice = price;
        if (model == #Public or model == #Private){
            payPrice := 0;
        };
        let workspaceActor = await WorkSpace.WorkSpace(Principal.fromActor(this), owner, name, avatar, desc,ctime, model, payPrice);
        let workspaceActorId = Principal.fromActor(workspaceActor);

        // add controllers
        let controllers: ?[Principal] = ?[Principal.fromActor(this), Principal.fromText(configs.BLACK_HOLE_ID), Principal.fromText(configs.SPARK_CAIOPS_ID)];
        let settings : ic.CanisterSettings = {
        controllers = controllers;
        compute_allocation = null;
        freezing_threshold = null;
        memory_allocation = null;
        };
        let params: ic.UpdateSettingsParams = {
            canister_id = workspaceActorId;
            settings = settings;
        };
        await IC.update_settings(params);

        ignore CaiOps.addCanister("workspace", Principal.toText(workspaceActorId));

        // add workspace relation
        let myworkspace : MyWorkspace = {wid=Principal.toText(workspaceActorId);owner=true;start=false};
        Map.set(_workspaces, thash, myworkspace.wid, myworkspace);
        return {
            code =200;
            msg = "";
            data = true;
        };
    };

    // 加入工作空间，被动
    public shared({caller}) func addWorkNs(): async(Bool){
        let callerPid = Principal.toText(caller);
        let contains = Map.has(_workspaces, thash, callerPid);
        if (contains){
            return true;
        };
        // 判断是否实现 workspace方法或者 是否是canister
        if (not Utils.isCanister(caller)){
            return false;
        };
        let wns : MyWorkspace = {
            wid=callerPid;
            owner=false;
            start=false;
        };
        Map.set(_workspaces, thash, callerPid, wns);
        return true;
    };

    // 退出工作空间，被动
    public shared({caller}) func leaveWorkNs(): async(Bool){
        let callerPid = Principal.toText(caller);
        let contains = Map.has(_workspaces, thash, callerPid);
        if (not contains){
            return true;
        };
        removeRecentData(callerPid);
        Map.delete(_workspaces, thash, callerPid);
        return true;
    };

    // 退出工作空间 主动
    public shared({caller}) func quitWorkNs(wid: Text): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // 退出指定工作空间: 删除工作空间映射，通知指定工作空间
        switch(Map.get(_workspaces, thash, wid)){
            case(null){
                return {
                    code = 404;
                    msg ="can not find target workspace";
                    data = false;
                };
            };
            case(?wns){
                let workActor: WorkActor = actor(wid);
                let wInfoResp = await workActor.info();
                if (Text.equal(wInfoResp.data.super, Principal.toText(Principal.fromActor(this)))){
                    return {
                        code = 500;
                        msg = "Please transfer ownership";
                        data = false;
                    }
                };
                
                let success = await workActor.quit();
                if (success){
                    Map.delete(_workspaces, thash, wid);
                    removeRecentData(wid);
                    return {
                        code = 200;
                        msg ="";
                        data = true;
                    };
                };
                return {
                    code = 500;
                    msg ="quit failed";
                    data = false;
                };
            };
        };
    };

    // 接收他人转移过来的工作空间 由workspace canister调用
    public shared({caller}) func reciveWns(): async Bool{
        let callerPid = Principal.toText(caller);
        switch(Map.get(_workspaces, thash, callerPid)){
            case(null){
                return false;
            };
            case(?wns){
                if ( wns.owner ){
                    return false;
                };
                let nWns : MyWorkspace = {
                    wid=wns.wid;
                    owner=true;
                    start=wns.start;
                };
                Map.set(_workspaces, thash, wns.wid, nWns);
                return true;
            };
        };
    };

    // 最近工作记录管理
    public shared({caller}) func addRecentWork(wid:Text): async(Resp<Bool>){
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // filter old memo
        _recentWorks := List.filter<RecentWork>(_recentWorks, func rc {not Text.equal(rc.wid, wid)});

        let recent :RecentWork = {wid=wid;name="";owner=false;time=Time.now();avatar=""};
        _recentWorks := List.push(recent, _recentWorks);
        if (Nat.greater(List.size(_recentWorks), _RECENT_SIZE)){
            let sub: Nat = List.size(_recentWorks) - _RECENT_SIZE;
            _recentWorks := List.drop<RecentWork>(_recentWorks, sub);
        };
        return { 
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func recentWorks(): async(Resp<[RecentWork]>){
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = [];
            };
        };
        var result : List.List<RecentWork> = List.nil();
        for (rw in List.toIter(_recentWorks)){
            let wActor : WorkActor = actor(rw.wid);
            let wResp = await wActor.info(); 
            let rwresp = {
                wid = rw.wid;
                name = wResp.data.name;
                owner = Text.equal(Principal.toText(Principal.fromActor(this)), wResp.data.super);
                time = rw.time;
                avatar = wResp.data.name;
            };
            result := List.push( rwresp, result);
        };
        return { 
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared({caller}) func addRecentEdit(wid: Text, index: Nat): async(Resp<Bool>){
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // filter old memo
        // Debug.print(debug_show(_recentEdits));
        // wid 和 index都不等才返回 true (错误逻辑) --> wid/index 有一个不等即可 
        _recentEdits := List.filter<RecentEdit>(_recentEdits, func rc { not Text.equal(rc.wid, wid) or not Nat.equal(rc.index, index)});
        // Debug.print(debug_show(_recentEdits));
        let recent : RecentEdit = {wid=wid;wname="";index=index;cname="";etime=Time.now()};
        _recentEdits := List.push(recent, _recentEdits);
        // Debug.print(debug_show(_recentEdits));
        if (Nat.greater(List.size(_recentEdits), _RECENT_SIZE)){
            let sub: Nat = List.size(_recentEdits) - _RECENT_SIZE;
            _recentEdits := List.drop<RecentEdit>(_recentEdits, sub);
        };
        return { 
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func recentEdits(): async(Resp<[RecentEdit]>){
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = [];
            };
        };
        var result : List.List<RecentEdit> = List.nil();
        for (re in List.toIter(_recentEdits)){
            let wActor : WorkActor = actor(re.wid);
            let wResp = await wActor.collectionCall(re.index); 
            let reresp = {
                wid = re.wid;
                wname = wResp.data.wName;
                index = re.index;
                cname = wResp.data.name;
                etime = re.etime;
            };
            result := List.push( reresp, result);
        };
        return { 
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    // 退出工作空间后，需要删除对应的最近工作记录
    private func removeRecentData(wid: Text){
        _recentEdits := List.filter<RecentEdit>(_recentEdits, func edit {not Text.equal(wid, edit.wid)});
        _recentWorks := List.filter<RecentWork>(_recentWorks, func ns {not Text.equal(wid, ns.wid)});
    };

    // 在代码发生变更的时候，可以通过main canister对 user、workspace canister进行升级通知。

}