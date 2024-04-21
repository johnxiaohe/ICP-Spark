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
    _name: Text,
    _owner: Principal,
    _avatar: Text, 
    _desc: Text, 
    _ctime: Time.Time,
) = this{

    // 用户接口api类型声明
    type User = types.User;
    type UserDetail = types.UserDetail;
    type Collection = types.Collection;
    type MyWorkspaceResp = types.MyWorkspaceResp;
    type MyWorkspace = types.MyWorkspace;
    type RecentWork = types.RecentWork;
    type RecentEdit = types.RecentEdit;
    type Resp<T> = types.Resp<T>;

    type WorkSpaceInfo = types.WorkSpaceInfo;

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
    public shared({caller}) func updateInfo(newName: Text, newAvatar: Text, newDesc: Text): async Resp<User>{
        if (not Principal.equal(caller,owner)){
            return {
                code=403;
                msg="permision denied";
                data={id=caller;avatar="";desc="";name="";pid=caller;ctime=0};
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
                id=Principal.fromActor(this);
                pid=owner;
                name=name;
                avatar=avatar;
                desc=desc;
                ctime=ctime;
            };
        };
    };

    public shared func info(): async Resp<User>{
        return {
            code=200;
            msg="";
            data={
                id=Principal.fromActor(this);
                pid=owner;
                name=name;
                avatar=avatar;
                desc=desc;
                ctime=ctime;
            };
        };
    };

    public shared func detail(): async(Resp<UserDetail>) {
        return {
            code=200;
            msg="";
            data={
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

    public shared func cycles(): async Resp<Nat>{
        return {
            code = 200;
            msg = "";
            data = Cycles.balance();
        };
    };

    public shared({caller}) func withdrawals(token: Text, amount: Nat, reciver: Principal): async Resp<Nat>{
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

    // cycles 管理 api --------------------------------------
    // 为指定容器添加Cycles，仅限本人操作. 返回当前cycles
    public shared({caller}) func addCycles(target: Principal): async Resp<Nat>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = 0;
            };
        };
        return {
            code = 200;
            msg = "";
            // todo 
            data = Cycles.balance();
        };
    };

    // 预存cycles到 cycles管理容器，并设置自动充值阈值
    public shared({caller}) func presaveCycles(presaveAmount: Nat, addAmount: Nat, trigger: Nat): async Resp<Nat>{
        // todo 
        return {
            code = 200;
            msg = "";
            data = 0;
        }
    };

    // 获取预存余额
    public shared({caller}) func presaveBalance(): async Resp<Nat>{
        // todo 
        return {
            code = 200;
            msg = "";
            data = 0;
        }
    };


    // a follow b => a.follow b.fans relation: uid -- uid
    public shared({caller}) func addFollow(uid: Principal): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // add target fans relation
        let userActor : UserActor = actor(Principal.toText(uid));
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

    public shared({caller}) func unFollow(target: Principal): async Resp<Bool> {
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // add target fans relation
        let userActor : UserActor = actor(Principal.toText(target));
        let success = await userActor.delFans();
        if (success){
            // find and del target
            _follows := List.filter<Principal>(_follows, func uid { not Principal.equal(uid, target) });
        };
        return {
            code = 200;
            msg = "";
            data =  success;
        };
    };

    public shared({caller}) func follows(): async Resp<[User]> {
        if ( not _showfollow and not Principal.equal(caller, owner) ){
            return {
                code = 403;
                msg = "secret model";
                data = [];
            };
        };
        var result: List.List<User> = List.nil();
        for (uid in List.toIter<Principal>(_follows)) {
            let userActor : UserActor = actor(Principal.toText(uid));
            let user = await userActor.info();
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
        _fans := List.push(caller, _fans);
        return true;
    };

    public shared({caller}) func delFans(): async Bool{
        if (Principal.equal(caller,owner)){
            return false;
        };
        _fans := List.filter<Principal>(_fans, func uid { not Principal.equal(uid, caller) });
        return true;
    };

    public shared({caller}) func fans(): async Resp<[User]> {
        if ( not _showfans and not Principal.equal(caller, owner) ){
            return {
                code = 403;
                msg = "secret model";
                data = [];
            };
        };
        var result: List.List<User> = List.nil();
        for (uid in List.toIter<Principal>(_fans)) {
            let userActor : UserActor = actor(Principal.toText(uid));
            let user = await userActor.info();
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
    public shared({caller}) func collection(wid: Principal, wName: Text, index: Nat, name: Text): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let waitCollection : Collection = {wid=wid;wName=wName;index=index;name=name};
        _collections := List.push(waitCollection, _collections);
        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func unCollection(wid: Principal, index:Nat): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // find and del target
        _collections := List.filter<Collection>(_collections, func c { not Principal.equal(c.wid,wid) and c.index != index });
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
        return {
            code = 200;
            msg = "";
            data = List.toArray(_collections);
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
    public shared({caller}) func subscribe(wid: Principal): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let workActor : WorkActor = actor(Principal.toText(wid)); 
        let success = await workActor.subscribe();
        if (success){
            _subscribes := List.push(wid, _subscribes);
        };
        return {
            code = 200;
            msg = "";
            data = success;
        };
    };

    public shared({caller}) func unsubscribe(wid: Principal): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        let workActor : WorkActor = actor(Principal.toText(wid)); 
        let success = await workActor.unSubscribe();
        if (success) {
            _subscribes := List.filter<Principal>(_subscribes, func id { not Principal.equal(id, wid) });
        };
        return {
            code = 200;
            msg = "";
            data = success;
        };

    };

    public shared({caller}) func subscribes(): async Resp<[WorkSpaceInfo]> {
        if ( not _showsubscribe and not Principal.equal(caller, owner) ){
            return {
                code = 403;
                msg = "secret model";
                data = [];
            };
        };
        var result: List.List<WorkSpaceInfo> = List.nil();
        for (wid in List.toIter<Principal>(_subscribes)) {
            let workActor : WorkActor = actor(Principal.toText(wid)); 
            let workspaceinfo = await workActor.info();
            result := List.push(workspaceinfo, result);
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
        if (model == #Public or model == #Subscribe){
            payPrice := 0;
        };
        let workspaceActor = await WorkSpace.WorkSpace(Principal.fromActor(this), owner, name, avatar, desc,ctime, model, payPrice);
        let myworkspace : MyWorkspace = {wid=Principal.fromActor(workspaceActor);owner=true;start=false};
        Map.set(_workspaces, phash, myworkspace.wid, myworkspace);
        return {
            code =200;
            msg = "";
            data = true;
        };
    };

    // 加入工作空间，被动
    public shared({caller}) func addWorkNs(): async(Bool){
        let contains = Map.has(_workspaces, phash, caller);
        if (contains){
            return true;
        };
        // 判断是否实现 workspace方法或者 是否是canister
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
    public shared({caller}) func leaveWorkNs(): async(Bool){
        let contains = Map.has(_workspaces, phash, caller);
        if (not contains){
            return true;
        };
        removeRecentData(caller);
        Map.delete(_workspaces, phash, caller);
        return true;
    };

    // 退出工作空间 主动
    public shared({caller}) func quitWorkNs(wid: Principal): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // 退出指定工作空间: 删除工作空间映射，通知指定工作空间
        switch(Map.get(_workspaces, phash, wid)){
            case(null){
                return {
                    code = 404;
                    msg ="can not find target workspace";
                    data = false;
                };
            };
            case(?wns){
                if (wns.owner){
                    return {
                        code = 500;
                        msg = "Please transfer ownership";
                        data = false;
                    }
                };
                let workActor: WorkActor = actor(Principal.toText(wid));
                let success = await workActor.quit();
                if (success){
                    Map.delete(_workspaces, phash, wid);
                    removeRecentData(wid);
                };
                return {
                    code = 403;
                    msg ="can not find target workspace";
                    data = false;
                };
            };
        };
    };

    // 转移工作空间owner身份
    public shared({caller}) func transferWorkOwner(wid: Principal, target: Principal): async Resp<Bool>{
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };

        switch(Map.get(_workspaces, phash, wid)){
            case(null){
                return {
                    code = 404;
                    msg = "can not find target workspace";
                    data = false;
                };
            };
            case(?wns){
                if ( not wns.owner ){
                    return {
                        code = 404;
                        msg = "you are not this workspace owner";
                        data = false;
                    };
                };
                let workActor: WorkActor = actor(Principal.toText(target));
                let success = await workActor.transfer(target);
                if (success){
                    let nWns : MyWorkspace = {
                        wid=wns.wid;
                        owner=false;
                        start=wns.start;
                    };
                    Map.set(_workspaces, phash, wid, nWns);
                };
                return {
                    code = 200;
                    msg = "";
                    data = success;
                };
            };
        };
    };

    // 接收他人转移过来的工作空间 由workspace canister调用
    public shared({caller}) func reciveWns(): async Bool{
        switch(Map.get(_workspaces, phash, caller)){
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
                Map.set(_workspaces, phash, wns.wid, nWns);
                return true;
            };
        };
    };

    // 最近工作记录管理
    public shared({caller}) func addRecentWork(wid:Principal, name: Text, isowner: Bool): async(Resp<[RecentWork]>){
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = [];
            };
        };
        let recent :RecentWork = {wid=wid;name=name;owner=isowner};
        _recentWorks := List.push(recent, _recentWorks);
        if (Nat.greater(List.size(_recentWorks), _RECENT_SIZE)){
            let sub: Nat = List.size(_recentWorks) - _RECENT_SIZE;
            _recentWorks := List.drop<RecentWork>(_recentWorks, sub);
        };
        return { 
            code = 200;
            msg = "";
            data = List.toArray(_recentWorks);
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
        return { 
            code = 200;
            msg = "";
            data = List.toArray(_recentWorks);
        };
    };

    public shared({caller}) func addRecentEdit(wid: Principal, wname: Text, cid: Nat, cname: Text): async(Resp<[RecentEdit]>){
        if (not Principal.equal(caller,owner)){
            return {
                code = 403;
                msg = "permision denied";
                data = [];
            };
        };
        let recent : RecentEdit = {wid=wid;wname=wname;cid=cid;cname=cname;etime=Time.now()};
        _recentEdits := List.push(recent, _recentEdits);
        if (Nat.greater(List.size(_recentEdits), _RECENT_SIZE)){
            let sub: Nat = List.size(_recentEdits) - _RECENT_SIZE;
            _recentEdits := List.drop<RecentEdit>(_recentEdits, sub);
        };
        return { 
            code = 200;
            msg = "";
            data = List.toArray(_recentEdits);
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
        return { 
            code = 200;
            msg = "";
            data = List.toArray(_recentEdits);
        };
    };

    // 退出工作空间后，需要删除对应的最近工作记录
    private func removeRecentData(wid: Principal){
        _recentEdits := List.filter<RecentEdit>(_recentEdits, func edit {not Principal.equal(wid, edit.wid)});
        _recentWorks := List.filter<RecentWork>(_recentWorks, func ns {not Principal.equal(wid, ns.wid)});
    };

}