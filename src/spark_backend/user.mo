import Time "mo:base/Time";
import List "mo:base/List";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Prim "mo:prim";
import Cycles "mo:base/ExperimentalCycles";
import Bool "mo:base/Bool";

import configs "configs";
import Ledger "ledgers";
import WorkSpace "workspace";

import types "types";
// Prim.rts_heap_size() -> Nat : wasm(canister) heap size at present

// 用户的canisterid是唯一标识符，作为主键和对外关联关系字段
shared({caller}) actor class UserSpace(
    _owner: Principal,
    _name: Text, 
    _avatar: Text, 
    _desc: Text, 
    _ctime: Time.Time,
) = this{
    type User = types.User;
    type UserDetail = types.UserDetail;

    type WorkSpaceInfo = types.WorkSpaceInfo;
    type Collection = types.Collection;
    type MyWorkspaceResp = types.MyWorkspaceResp;
    type MyWorkspace = types.MyWorkspace;

    type LedgerActor = Ledger.Self;
    type UserActor = types.UserActor;
    type WorkActor = types.WorkActor;

    private stable var owner : Principal = _owner;
    private stable var name : Text = _name;
    private stable var avatar : Text = _avatar;
    private stable var desc : Text = _desc;
    private stable var ctime : Time.Time = _ctime;
    private stable var cyclesPerNamespace: Nat = 20_000_000_000; // 0.02t cycles for each token canister

    private stable var _follows: List.List<Principal> = List.nil();
    private stable var _fans: List.List<Principal> = List.nil();
    private stable var _collections: List.List<Collection> = List.nil();
    private stable var _subscribes: List.List<Principal> = List.nil();
    private stable var _workspaces: List.List<MyWorkspace> = List.nil();
    private stable var _showfollow: Bool = true;
    private stable var _showfans: Bool = true;
    private stable var _showcollection: Bool = true;
    private stable var _showsubscribe: Bool = true;

    let spark : types.Spark = actor (configs.SPARK_CANISTER_ID);
    private let tokenMap = HashMap.HashMap<Text, LedgerActor>(3, Text.equal, Text.hash);
    let icpLedger: LedgerActor = actor(configs.ICP_LEGDER_ID);
    let cyclesLedger: LedgerActor = actor(configs.CYCLES_LEGDER_ID);
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
        for (work in List.toIter(_workspaces)){
            let workActor: WorkActor = actor(Principal.toText(work.wid));
            let workInfo :WorkSpaceInfo = await workActor.info();
            let cyclesBalance = await cyclesLedger.icrc1_balance_of({owner=work.wid; subaccount=null});
            let workResp: MyWorkspaceResp = {
                wid = workInfo.id;
                name = workInfo.name;
                desc = workInfo.desc;
                cycles = cyclesBalance;
                owner = work.owner;
                start = work.start;
            };
            result := List.push(workResp, result);
        };
        return List.toArray(result);
    };

    public shared({caller}) func createWorkNs(name: Text, desc: Text, avatar: Text): async(){
        if (not Principal.equal(caller,owner)){
            return;
        };
        Cycles.add<system>(cyclesPerNamespace);
        let ctime = Time.now();
        let workspaceActor = await WorkSpace.WorkSpace(Principal.fromActor(this), name, avatar, desc,ctime);
        let myworkspace : MyWorkspace = {wid=Principal.fromActor(workspaceActor);owner=true;start=false};
        _workspaces := List.push(myworkspace, _workspaces);
    };

}