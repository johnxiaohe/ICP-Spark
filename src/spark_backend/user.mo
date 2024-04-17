import Prim "mo:prim";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import List "mo:base/List";
import Text "mo:base/Text";
import Bool "mo:base/Bool";
import Error "mo:base/Error";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";

import Map "mo:map/Map";
import { phash } "mo:map/Map";

import Ledger "ledgers";
import configs "configs";
import types "types";

import WorkSpace "workspace";

// 用户的canisterid是唯一标识符，作为主键和对外关联关系字段
shared({caller}) actor class UserSpace(
    _owner: Principal,
    _name: Text, 
    _avatar: Text, 
    _desc: Text, 
    _ctime: Time.Time,
) = this{

    // 用户接口api类型声明
    type User = types.User;
    type UserDetail = types.UserDetail;
    type WorkSpaceInfo = types.WorkSpaceInfo;
    type Collection = types.Collection;
    type MyWorkspaceResp = types.MyWorkspaceResp;
    type MyWorkspace = types.MyWorkspace;
    type RecentWork = types.RecentWork;
    type RecentEdit = types.RecentEdit;

    // 第三方api actor类型声明
    type LedgerActor = Ledger.Self;
    type UserActor = types.UserActor;
    type WorkActor = types.WorkActor;

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
    private stable var _follows: List.List<Principal> = List.nil();
    private stable var _fans: List.List<Principal> = List.nil();
    private stable var _collections: List.List<Collection> = List.nil();
    private stable var _subscribes: List.List<Principal> = List.nil();

    // 用户创作数据
    let _workspaces = Map.new<Principal,MyWorkspace>();
    // private stable var _workspaces: List.List<MyWorkspace> = List.nil();
    // 最近创作记录
    private stable var _RECENT_SIZE : Nat = 10;
    private stable var _recentWorks : List.List<RecentWork> = List.nil();
    private stable var _recentEdits : List.List<RecentEdit> = List.nil();

    // 全局 actor api client 预创建
    let spark : types.Spark = actor (configs.SPARK_CANISTER_ID);
    let icpLedger: LedgerActor = actor(configs.ICP_LEGDER_ID);
    let cyclesLedger: LedgerActor = actor(configs.CYCLES_LEGDER_ID);

    // token类型 actor 预存，用于 转账和余额查询等
    private let tokenMap = HashMap.HashMap<Text, LedgerActor>(3, Text.equal, Text.hash);
    tokenMap.put("ICP", icpLedger);
    tokenMap.put("CYCLES", cyclesLedger);

    // 更新用户信息，回调用户管理模块更新全局存储的用户信息
    public shared({caller}) func updateInfo(newName: Text, newAvatar: Text, newDesc: Text): async Result.Result<User,Text>{
        if (not Principal.equal(caller,owner)){
            return #err("")
        };
        name := newName;
        avatar := newAvatar;
        desc := newDesc;
        await spark.userUpdateCall(owner,newName,newAvatar,newDesc);
        return #ok({
            id=Principal.fromActor(this);
            pid=owner;
            name=name;
            avatar=avatar;
            desc=desc;
            ctime=ctime;
          });
    };

    public shared func info(): async (User){
        {
            id=Principal.fromActor(this);
            pid=owner;
            name=name;
            avatar=avatar;
            desc=desc;
            ctime=ctime;
        };
    };

    public shared func detail(): async(UserDetail) {
        {
            id=Principal.fromActor(this);
            pid=owner;
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

    public query func canisterMemory() : async Nat {
        return Prim.rts_memory_size();
    };

    public shared func balance(token: Text): async Nat{
        switch(tokenMap.get(token)){
            case(null){
                0;
            };
            case(?ledger){
                await ledger.icrc1_balance_of({owner=Principal.fromActor(this); subaccount=null});
            }
        };
    };

    public shared({caller}) func withdrawals(token: Text, amount: Nat, reciver: Principal): async Result.Result<Nat, Text>{
        if (not Principal.equal(caller,owner)){
            return #err("permision denied")
        };
        switch(tokenMap.get(token)){
            case(null){
                return #err("unsuport token: " # token);
            };
            case(?ledger){
                let transferArgs : Ledger.TransferArgs = {
                    memo = null;
                    amount = amount;
                    from_subaccount = null;
                    fee = null;
                    to = { owner = reciver; subaccount = null };
                    created_at_time = null;
                };
                try {
                    // initiate the transfer
                    let transferResult = await ledger.icrc1_transfer(transferArgs);

                    // check if the transfer was successfull
                    switch (transferResult) {
                        case (#Err(transferError)) {
                            return #err("Couldn't transfer funds:\n" # debug_show (transferError));
                        };
                        case (#Ok(blockIndex)) { 
                            return #ok blockIndex 
                        };
                    };
                } catch (error : Error) {
                    // catch any errors that might occur during the transfer
                    return #err("Reject message: " # Error.message(error));
                };
            };
        };
    };

    // 为指定容器添加Cycles，仅限本人操作
    public shared({caller}) func addCycles(target: Principal): async(){

    };

    // 预存cycles到 cycles管理容器，并设置自动充值阈值
    public shared({caller}) func presaveCycles(presaveAmount: Nat, addAmount: Nat, trigger: Nat): async(){

    };

    // 获取预存余额
    public shared({caller}) func presaveBalance(): async(Nat){
        return 0;
    };

    // a follow b => a.follow b.fans relation: uid -- uid
    public shared({caller}) func addFollow(uid: Principal): async(){
        if (not Principal.equal(caller,owner)){
            return;
        };
        // add follow relation
        _follows := List.push(uid, _follows);
        // add target fans relation
        let userActor : UserActor = actor(Principal.toText(uid));
        await userActor.addFans();
    };

    public shared({caller}) func unFollow(target: Principal): async(){
        if (not Principal.equal(caller,owner)){
            return;
        };
        // find and del target
        _follows := List.filter<Principal>(_follows, func uid { not Principal.equal(uid, target) });
        // add target fans relation
        let userActor : UserActor = actor(Principal.toText(target));
        await userActor.addFans();
    };

    public shared({caller}) func follows(): async(Result.Result<[User], Text>){
        if ( not _showfollow and not Principal.equal(caller, _owner) ){
            return #err("permision denied");
        };
        var result: List.List<User> = List.nil();
        for (uid in List.toIter<Principal>(_follows)) {
            let userActor : UserActor = actor(Principal.toText(uid));
            let user = await userActor.info();
            result := List.push(user, result);
        };
        return #ok(List.toArray(result));
    };

    public shared({caller}) func changeFollowDisplay(): async(Bool){
        if (not Principal.equal(caller,owner)){
            return false;
        };
        _showfollow := not _showfollow;
        return _showfollow;
    };

    public shared({caller}) func addFans(): async (){
        if (Principal.equal(caller,owner)){
            return;
        };
        _fans := List.push(caller, _fans);
    };

    public shared({caller}) func delFans(): async (){
        if (Principal.equal(caller,owner)){
            return;
        };
        _fans := List.filter<Principal>(_fans, func uid { not Principal.equal(uid, caller) });
    };

    public shared({caller}) func fans(): async(Result.Result<[User], Text>){
        if ( not _showfans and not Principal.equal(caller, _owner) ){
            return #err("permision denied");
        };
        var result: List.List<User> = List.nil();
        for (uid in List.toIter<Principal>(_fans)) {
            let userActor : UserActor = actor(Principal.toText(uid));
            let user = await userActor.info();
            result := List.push(user, result);
        };
        return #ok(List.toArray(result));
    };

    public shared({caller}) func changeFansDisplay(): async(Bool){
        if (not Principal.equal(caller,owner)){
            return false;
        };
        _showfans := not _showfans;
        return _showfans;
    };

    // 收藏、取消收藏、收藏列表
    public shared({caller}) func collection(wid: Principal, wName: Text, index: Nat, name: Text): async(){
        if (not Principal.equal(caller,owner)){
            return;
        };
        let waitCollection : Collection = {wid=wid;wName=wName;index=index;name=name};
        _collections := List.push(waitCollection, _collections);
    };

    public shared({caller}) func unCollection(wid: Principal, index:Nat): async(){
        if (not Principal.equal(caller,owner)){
            return;
        };
        // find and del target
        _collections := List.filter<Collection>(_collections, func c { not Principal.equal(c.wid,wid) and c.index != index });
    };

    public shared({caller}) func collections(): async(Result.Result<[Collection], Text>){
        if ( not _showcollection and not Principal.equal(caller, _owner) ){
            return #err("permision denied");
        };
        return #ok(List.toArray(_collections));
    };

    public shared({caller}) func changeCollectionDisplay(): async(Bool){
        if (not Principal.equal(caller,owner)){
            return false;
        };
        _showcollection := not _showcollection;
        return _showcollection;
    };

    // 订阅列表、添加、删除订阅。关联标识为目标workspace的 priciaplid
    public shared({caller}) func subscribe(wid: Principal): async(){
        if (not Principal.equal(caller,owner)){
            return;
        };
        _subscribes := List.push(wid, _subscribes);
        let workActor : WorkActor = actor(Principal.toText(wid)); 
        await workActor.subscribe();
    };

    public shared({caller}) func unsubscribe(wid: Principal): async(){
        if (not Principal.equal(caller,owner)){
            return;
        };
        _subscribes := List.filter<Principal>(_subscribes, func id { not Principal.equal(id, wid) });
        let workActor : WorkActor = actor(Principal.toText(wid)); 
        await workActor.unSubscribe();
    };

    public shared({caller}) func subscribes(): async(Result.Result<[WorkSpaceInfo], Text>){
        if ( not _showsubscribe and not Principal.equal(caller, _owner) ){
            return #err("permision denied");
        };
        var result: List.List<WorkSpaceInfo> = List.nil();
        for (wid in List.toIter<Principal>(_subscribes)) {
            let workActor : WorkActor = actor(Principal.toText(wid)); 
            let workspaceinfo = await workActor.info();
            result := List.push(workspaceinfo, result);
        };
        return #ok(List.toArray(result));
    };

    public shared({caller}) func changeSubscribeDisplay(): async(Bool){
        if (not Principal.equal(caller,owner)){
            return false;
        };
        _showsubscribe := not _showsubscribe;
        return _showsubscribe;
    };

    // 工作空间列表、创建工作空间、转让工作空间、退出工作空间、加入工作空间
    public shared({caller}) func workspaces(): async([MyWorkspaceResp]){
        if (not Principal.equal(caller,owner)){
            return [];
        };
        var result : List.List<MyWorkspaceResp> = List.nil();
        for (work in Map.vals(_workspaces)){
            let workActor: WorkActor = actor(Principal.toText(work.wid));
            let workInfo :WorkSpaceInfo = await workActor.info();
            let workResp: MyWorkspaceResp = {
                wid = workInfo.id;
                name = workInfo.name;
                desc = workInfo.desc;
                owner = work.owner;
                start = work.start;
            };
            result := List.push(workResp, result);
        };
        return List.toArray(result);
    };

    public shared({caller}) func createWorkNs(name: Text, desc: Text, avatar: Text): async(Bool){
        if (not Principal.equal(caller,owner)){
            return false;
        };
        Cycles.add<system>(cyclesPerNamespace);
        let ctime = Time.now();
        let workspaceActor = await WorkSpace.WorkSpace(Principal.fromActor(this), name, avatar, desc,ctime);
        let myworkspace : MyWorkspace = {wid=Principal.fromActor(workspaceActor);owner=true;start=false};
        Map.set(_workspaces, phash, myworkspace.wid, myworkspace);
        return true;
    };

    public shared({caller}) func addWorkNs(): async(Bool){
        let contains = Map.has(_workspaces, phash, caller);
        if (contains){
            return true;
        };
        // 判断是否实现 workspace方法或者非canister
        let workActor: WorkActor = actor(Principal.toText(caller));
        let workInfo :WorkSpaceInfo = await workActor.info();

        let wns : MyWorkspace = {
            wid=caller;
            owner=false;
            start=false;
        };
        Map.set(_workspaces, phash, caller, wns);
        return true;
    };

    // 退出工作空间，被动
    public shared({caller}) func leaveWorkNs(): async(){
        let contains = Map.has(_workspaces, phash, caller);
        if (not contains){
            return;
        };
        removeRecentData(caller);
        Map.delete(_workspaces, phash, caller);
    };

    // 退出工作空间 主动
    public shared({caller}) func quitWorkNs(wid: Principal): async Result.Result<Bool, Text>{
        if (not Principal.equal(caller,owner)){
            return #err("permision denied");
        };
        // 退出指定工作空间: 删除工作空间映射，通知指定工作空间
        switch(Map.get(_workspaces, phash, wid)){
            case(null){
                return #err("can not find target workspace");
            };
            case(?wns){
                Map.delete(_workspaces, phash, wid);
                removeRecentData(wid);
                let workActor: WorkActor = actor(Principal.toText(wid));
                await workActor.quit();
                return #ok(true);
            };
        };
    };

    // 转移工作空间owner身份
    public shared({caller}) func transferWorkOwner(wid: Principal, target: Principal): async Result.Result<Bool, Text>{
        if (not Principal.equal(caller,owner)){
            return #err("permision denied");
        };

        switch(Map.get(_workspaces, phash, wid)){
            case(null){
                return #err("can not find target workspace");
            };
            case(?wns){
                if ( not wns.owner ){
                    return #err("you are not this workspace owner");
                };
                let nWns : MyWorkspace = {
                    wid=wns.wid;
                    owner=false;
                    start=wns.start;
                };
                Map.set(_workspaces, phash, wid, nWns);
                let workActor: WorkActor = actor(Principal.toText(target));
                await workActor.transfer(target);
                return #ok(true);
            };
        };
    };

    // 接收他人转移过来的工作空间 由workspace canister调用
    public shared({caller}) func reciveWns(): async Result.Result<Bool, Text>{
        switch(Map.get(_workspaces, phash, caller)){
            case(null){
                return #err("can not find target workspace");
            };
            case(?wns){
                if ( wns.owner ){
                    return #err("still owner");
                };
                let nWns : MyWorkspace = {
                    wid=wns.wid;
                    owner=true;
                    start=wns.start;
                };
                Map.set(_workspaces, phash, wns.wid, nWns);
                return #ok(true);
            };
        };
    };

    // 最近工作记录管理
    public shared({caller}) func addRecentWork(wid:Principal, name: Text, isowner: Bool): async([RecentWork]){
        if (not Principal.equal(caller,owner)){
            return [];
        };
        let recent :RecentWork = {wid=wid;name=name;owner=isowner};
        _recentWorks := List.push(recent, _recentWorks);
        if (Nat.greater(List.size(_recentWorks), _RECENT_SIZE)){
            let sub: Nat = List.size(_recentWorks) - _RECENT_SIZE;
            _recentWorks := List.drop<RecentWork>(_recentWorks, sub);
        };
        return List.toArray(_recentWorks);
    };

    public shared({caller}) func recentWorks(): async([RecentWork]){
        if (not Principal.equal(caller,owner)){
            return [];
        };
        return List.toArray(_recentWorks);
    };

    public shared({caller}) func addRecentEdit(wid: Principal, wname: Text, cid: Nat, cname: Text): async([RecentEdit]){
        if (not Principal.equal(caller,owner)){
            return [];
        };
        let recent : RecentEdit = {wid=wid;wname=wname;cid=cid;cname=cname;etime=Time.now()};
        _recentEdits := List.push(recent, _recentEdits);
        if (Nat.greater(List.size(_recentEdits), _RECENT_SIZE)){
            let sub: Nat = List.size(_recentEdits) - _RECENT_SIZE;
            _recentEdits := List.drop<RecentEdit>(_recentEdits, sub);
        };
        return List.toArray(_recentEdits);
    };

    public shared({caller}) func recentEdits(): async([RecentEdit]){
        if (not Principal.equal(caller,owner)){
            return [];
        };
        return List.toArray(_recentEdits);
    };

    // 退出工作空间后，需要删除对应的最近工作记录
    private func removeRecentData(wid: Principal){
        _recentEdits := List.filter<RecentEdit>(_recentEdits, func edit {not Principal.equal(wid, edit.wid)});
        _recentWorks := List.filter<RecentWork>(_recentWorks, func ns {not Principal.equal(wid, ns.wid)});
    };

}