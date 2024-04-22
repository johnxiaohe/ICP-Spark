import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import List "mo:base/List";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Bool "mo:base/Bool";
import HashMap "mo:base/HashMap";
import Error "mo:base/Error";

import Map "mo:map/Map";
import { phash;nhash } "mo:map/Map";
import Set "mo:map/Set";

import configs "configs";
import Ledger "ledgers";
import types "types";

// 用户在做 订阅、取消订阅、转移空间、退出空间时均使用用户caniser代为调用
// 用户在浏览、更新空间内容时，可以由用户自己调用
// 用户角色
// 订阅、取消订阅 由user canister调用
// 获取文章信息、获取空间信息 由 user id 调用
// 成员角色
// 空间创建、转移、退出 由 user canister调用
// 文章管理 由 user id调用
// 空间日志 由 user id调用
// 空间统计 由 user id调用

// 空间管理 由 空间
shared({caller}) actor class WorkSpace(
    _creater: Principal,
    _createrPid: Principal,
    _name: Text, 
    _avatar: Text, 
    _desc: Text, 
    _ctime: Time.Time,
    _showModel: types.ShowModel,
    _price : Nat,
) = this{
    
    // workspace 类型声明
    type Content = types.Content;
    type ContentResp = types.ContentResp;
    type SummaryResp = types.SummaryResp;
    type WorkSpaceInfo = types.WorkSpaceInfo;

    // 第三方类型声明
    type Resp<T> = types.Resp<T>;
    type User = types.User;
    type UserDetail = types.UserDetail;
    type TransferFromArgs = Ledger.TransferFromArgs;
    
    // actor 类型声明
    type LedgerActor = Ledger.Self;
    type UserActor = types.UserActor;

    // 全局 actor api client 预创建
    let icpLedger: LedgerActor = actor(configs.ICP_LEGDER_ID);
    let cyclesLedger: LedgerActor = actor(configs.CYCLES_LEGDER_ID);
    // token类型 actor 预存，用于 转账和余额查询等
    private let tokenMap = HashMap.HashMap<Text, LedgerActor>(3, Text.equal, Text.hash);
    tokenMap.put("ICP", icpLedger);
    tokenMap.put("CYCLES", cyclesLedger);


    private stable var superUid : Principal = _creater; // user canister id
    private stable var superPid : Principal = _createrPid;
    private stable var name : Text = _name;
    private stable var avatar : Text = _avatar;
    private stable var desc : Text = _desc;
    private stable var ctime : Time.Time = _ctime;
    private stable var showModel : types.ShowModel = _showModel;
    private stable var price : Nat = _price;

    // 成员管理数据, workspace的api接口由用户直接调用；部分callback由 user canister 调用
    // 需要判断 pid / uid 用户的成员角色
    // pid --- uid
    private stable var memberMap = Map.new<Principal,Principal>();
    private stable var adminMap = Map.new<Principal,Principal>();
    // uid --- pid
    private stable var memberIdMap = Map.new<Principal,Principal>();

    // 订阅用户记录
    // pid --- uid
    private stable var consumerPidMap = Map.new<Principal,Principal>();
    // uid --- pid
    private stable var consumerUidMap = Map.new<Principal,Principal>();

    // 内容管理数据
    private stable var _contentIndex : Nat = 0;
    private stable var contentIndex = Map.new<Nat, List.List<Nat>>();
    private stable var contentMap = Map.new<Nat, Content>();

    // 操作日志数据
    private stable var _memberlog : List.List<Text> = List.nil();
    private stable var _fundslog : List.List<Text> = List.nil();
    private stable var _contentlog : List.List<Text> = List.nil();

    // 统计  ICP
    private stable var _income : Nat = 0;
    private stable var _outgiving: Nat = 0;
    private stable var _viewcount : Nat = 0;
    private stable var _editcount : Nat = 0;

    // 内部调用的查询判断私有方法   ----------------------------------------------------------
    // 是否是管理员  pid: user principal id
    private func isAdmin(pid: Principal): Bool{
        return Principal.equal(pid, superPid) or Map.has(adminMap, phash, pid);
    };

    // 是否是成员
    private func isMember(pid: Principal): Bool{
        return Principal.equal(pid, superPid) or Map.has(adminMap, phash, pid) or Map.has(memberMap, phash, pid);
    };
    private func isMemberByUid(uid: Principal): Bool{
        Map.has(memberIdMap, phash, uid);
    };

    private func isSuper(id: Principal): Bool{
        return Principal.equal(id, superUid) or Principal.equal(id, superPid);
    };

    private func isSubscriberByPid(pid: Principal): Bool{
        Map.has(consumerPidMap, phash, pid);
    };
    private func isSubscriberByUid(uid: Principal): Bool{
        Map.has(consumerUidMap, phash, uid);
    };

    // 删除订阅只能由user canister调用　
    private func delSubscribe(uid: Principal){
        switch(Map.get(consumerUidMap, phash, uid)){
            case(null){

            };
            case(?pid){
                Map.delete(consumerPidMap, phash, pid);
            };
        };
        Map.delete(consumerUidMap, phash, uid);
    };

    // 由用户直接调用的 空间基础信息管理方法 ---------------------------------------------------------------
    public shared func info(): async Resp<WorkSpaceInfo>{
        return {
                code = 200;
                msg = "";
                data = {
                    id = Principal.fromActor(this);
                    super = superUid;
                    name = name;
                    avatar = avatar;
                    desc = desc;
                    ctime = ctime;
                    model = showModel;
                    price = price;
                };
        };
    };

    public shared({caller}) func update(newName: Text, newAvatar: Text, newDesc: Text): async Resp<WorkSpaceInfo>{
        if (not isAdmin(caller)){
            return {
                code = 403;
                msg = "permision denied";
                data = {id=caller;super=caller;name="";avatar="";desc="";ctime=ctime;model=#Public;price=0;};
            };
        };
        name := newName;
        avatar := newAvatar;
        desc := newDesc;
        return {
            code = 200;
            msg = "";
            data = {id=Principal.fromActor(this);super=superUid;name=name;avatar=avatar;desc=desc;ctime=ctime;model=showModel;price=price};
        };
    };

    public shared({caller}) func updateShowModel(newShowModel: types.ShowModel, newPrice: Nat): async Resp<WorkSpaceInfo>{
        if(not isSuper(caller)){
            return {
                code = 403;
                msg = "permision denied";
                data = {id=caller;super=caller;name="";avatar="";desc="";ctime=ctime;model=#Public;price=0;};
            };
        };
        // 公开度在缩小，则需要判断是否合法
        if(newShowModel == #Private and showModel != #Private and Map.size(consumerUidMap) > 0){
            if(showModel == #Payment){
                return {
                    code = 400;
                    msg = "payment model can not change to private";
                    data = {id=caller;super=caller;name="";avatar="";desc="";ctime=ctime;model=#Public;price=0;};
                };
            }else{
                // clear consumers
                for (uid in Map.keys(consumerUidMap)){
                    let userActor : UserActor = actor(Principal.toText(uid));
                    await userActor.quitSubscribe();
                };
                Map.clear(consumerPidMap);
                Map.clear(consumerUidMap);
            };
        };
        showModel := newShowModel;
        if(showModel == #Payment){
            price := newPrice;
        };
        return {
            code = 200;
            msg = "";
            data = {id=Principal.fromActor(this);super=superUid;name=name;avatar=avatar;desc=desc;ctime=ctime;model=showModel;price=price};
        };
    };

    // 获取当前用户在空间中的角色
    public shared({caller}) func role(): async Resp<Text>{
        if (Principal.equal(caller, superPid)){
            return {
                code = 200;
                msg = "";
                data = "owner";
            }
        };
        if (isAdmin(caller)){
            return {
                code = 200;
                msg = "";
                data = "admin";
            }
        };
        if (isMember(caller)){
            return {
                code = 200;
                msg = "";
                data = "member";
            };
        };
        return {
            code = 404;
            msg = "permission not found";
            data = "";
        };
    };

    // 由管理者canister调用的  空间退出、空间转让、成员管理 ---------------------------
    public shared({caller}) func quit(): async(Bool){
        if (isSuper(caller)){
            return false;
        };
        if(Map.has(memberIdMap, phash, caller)){
            switch(Map.get(memberIdMap, phash, caller)){
                case(null){};
                case(?pid){
                    Map.delete(memberIdMap, phash, caller);
                    Map.delete(adminMap, phash, pid);
                    Map.delete(memberMap, phash, pid);
                };
            };
            return true;
        };
        return false;
    };

    // update super admin
    public shared({caller}) func transfer(uid: Principal): async(Bool){
        if(isSuper(caller)){
            switch(Map.get(memberIdMap, phash, uid)){
                case(null){return false;};
                case(?pid){
                    if(isAdmin(pid)){
                        let userActor : UserActor = actor(Principal.toText(uid));
                        let result: Bool = await userActor.reciveWns();
                        if (not result){
                            return false;
                        };
                        Map.set(memberIdMap, phash, superUid, superPid);
                        Map.set(memberMap, phash, superPid, superUid);
                        superUid := uid;
                        superPid := pid;
                        return true;
                    };
                    return false;
                }
            };
        };
        return false;
    };

    public shared func memers(): async(Resp<[User]>){
        var result : List.List<User> = List.nil();
        for(uid in Map.vals(memberMap)){
            let userActor: UserActor = actor(Principal.toText(uid));
            let userResp = await userActor.info();
            let userInfo : User = userResp.data;
            result := List.push(userInfo, result);
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared func admins(): async(Resp<[User]>){
        var result : List.List<User> = List.nil();
        let superActor: UserActor = actor(Principal.toText(superUid));
        let superResp = await superActor.info();
        let superInfo : User = superResp.data;
        result := List.push(superInfo, result);
        for(uid in Map.vals(adminMap)){
            let userActor: UserActor = actor(Principal.toText(uid));
            let userResp = await userActor.info();
            let userInfo : User = userResp.data;
            result := List.push(userInfo, result);
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared({caller}) func addMember(uid: Principal, role: Text): async(Resp<Bool>){
        if(isMemberByUid(uid)){
            return {
                code = 400;
                msg = "user member exists";
                data = false;
            };
        };
        if (not isAdmin(caller)){
            return {
                code = 403;
                msg = "permission denied";
                data = false;
            };
        };
        let userActor: UserActor = actor(Principal.toText(uid));
        let userResp = await userActor.info();
        let pid = userResp.data.pid;
        Map.set(memberIdMap, phash, uid, pid);
        if (role == "admin"){
            Map.set(adminMap, phash, pid, uid);
        }else if (role == "member"){
            Map.set(memberMap, phash, pid, uid);
        }else{
            return {
                code = 400;
                msg = "role not exist";
                data = false;
            };
        };
        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func delMember(uid: Principal): async(Resp<Bool>){
        if(not isAdmin(caller)){
            return {
                code = 403;
                msg = "permission denied";
                data = false;
            };
        };
        if (isSuper(uid)){
            return {
                code = 403;
                msg = "super admin can not del";
                data = false;
            };
        };
        if(not isMemberByUid(uid)){
            return {
                code = 404;
                msg = "member not found";
                data = false;
            };
        };
        switch(Map.get(memberIdMap, phash, uid)){
            case(null){
                return {
                    code = 400;
                    msg = "user not found";
                    data = false;
                };
            };
            case(?pid){
                // 仅超管可以删管理员
                if(isAdmin(pid) and not isSuper(caller)){
                    return {
                        code = 403;
                        msg = "only super admin can do that";
                        data = false;
                    };
                };
                Map.delete(memberIdMap, phash, uid);
                Map.delete(adminMap, phash, pid);
                Map.delete(memberMap, phash, pid);
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };

    // 更新 空间公开度
    public shared({caller}) func updatePermission(uid: Principal, role: Text): async(Resp<Bool>){
        if(not isAdmin(caller)){
            return {
                code = 403;
                msg = "permission denied";
                data = false;
            };
        };
        if(isSuper(uid)){
            return {
                code = 403;
                msg = "super admin can not change";
                data = false;
            };
        };
        if(not isMemberByUid(uid)){
            return {
                code = 404;
                msg = "user not found";
                data = false;
            };
        };
        switch(Map.get(memberIdMap, phash, uid)){
            case(null){
                return {
                    code = 400;
                    msg = "user not found";
                    data = false;
                };
            };
            case(?pid){
                Map.delete(adminMap, phash, pid);
                Map.delete(memberMap, phash, pid);
                if(role == "admin"){
                    if(not isSuper(caller)){
                        return {
                            code = 403;
                            msg = "only super admin change admin role";
                            data = false;
                        };
                    };
                    Map.set(adminMap, phash, pid,uid);
                }else if(role == "member"){
                    Map.set(memberMap, phash, pid,uid);
                }else{
                    return {
                        code = 400;
                        msg = "role not exist";
                        data = false;
                    };
                };
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };

    // 由消费者canister调用的  订阅、取消订阅 ----------------------------
    public shared({caller}) func subscribe(): async (Resp<Bool>){
        if (isSubscriberByUid(caller)){
            return {
                code = 400;
                msg = "subscribed";
                data = false;
            };
        };
        if(showModel == #Private){
            return {
                code = 403;
                msg = "private work space";
                data = false;
            };
        };
        
        let user: UserActor = actor(Principal.toText(caller));
        let userResp = await user.info();
        let userInfo : User = userResp.data;
        // todo: transferfrom 将用户canister 钱转移到自己账户中
        let fee = await icpLedger.icrc1_fee();
        if(showModel == #Payment and price > 0){
            let transferFromArgs : TransferFromArgs = {
                from = {owner=caller; subaccount=null};
                memo = null;
                amount = price + fee;
                spender_subaccount = null;
                fee = ?fee;
                to = { owner = Principal.fromActor(this); subaccount = null };
                created_at_time = null;
            };
            try {
            // initiate the transfer
            let transferResult = await icpLedger.icrc2_transfer_from(transferFromArgs);

            // check if the transfer was successfull
            switch (transferResult) {
                case (#Err(transferError)) {
                    return {
                        code = 500;
                        msg = "Couldn't transfer funds:\n" # debug_show (transferError);
                        data = false;
                    };
                };
                case (#Ok(blockIndex)) {
                    Map.set(consumerPidMap, phash, userInfo.pid, userInfo.id);
                    Map.set(consumerUidMap, phash, userInfo.id, userInfo.pid);
                    // todo: log
                    return {
                        code = 200;
                        msg = "blockIndex: " # Nat.toText(blockIndex);
                        data = true;
                    };
                };
            };
            } catch (error : Error) {
            // catch any errors that might occur during the transfer
                return {
                    code = 500;
                    msg ="Reject message: " # Error.message(error);
                    data = false;
                };
            };
        };
        Map.set(consumerPidMap, phash, userInfo.pid, userInfo.id);
        Map.set(consumerUidMap, phash, userInfo.id, userInfo.pid);
        // todo: log
        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func unSubscribe(): async (Resp<Bool>){
        if (not isSubscriberByUid(caller)){
            return {
                code = 400;
                msg = "not subscriber";
                data = false;
            };
        };
        delSubscribe(caller);
        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    // 由消费者调用  查看是否有订阅 -------------------------------------
    public shared({caller}) func haveSubscribe(): async (Resp<Bool>){
        if (isSubscriberByPid(caller)){
            return {
                code = 200;
                msg = "";
                data = true;
            };
        };
        return {
            code = 404;
            msg = "user do not subscribe";
            data = false;
        };
    };

    // 由用户直接调用的  创作内容管理相关api
    public shared({caller}) func createContent(name: Text, pid : Nat, order: Nat): async (Resp<Content>){
        if (not isMember(caller)){
            return {
                code = 403;
                msg = "permission denied";
                data = {id=0;pid=0;name="";content="";order=0;utime=Time.now();uid=caller;coAuthors=List.nil()}
            };
        };
        _contentIndex := _contentIndex + 1;
        let index = _contentIndex;
        var authors : List.List<Principal> = List.nil();
        let content = {
            id = index;
            pid = pid;
            name = name;
            content = "";
            order = order;
            utime = Time.now();
            uid = caller;
            coAuthors = List.push(caller, authors);
        };

        var ids : List.List<Nat> = List.nil();
        ids := List.push(index, ids);
        switch(Map.get(contentIndex, nhash, pid)){
            case(null){};
            case(?existIds){
                ids := List.append<Nat>(ids, existIds);
            };
        };
        Map.set(contentIndex, nhash, pid, ids);
        Map.set(contentMap, nhash, index, content);

        // todo : add log push portal

        return {
            code = 200;
            msg = "";
            data = content;
        };
    };

    public shared({caller}) func changeLocal(id: Nat, pid: Nat, order: Nat): async (Resp<Bool>){
        if (not isMember(caller)){
            return {
                code = 403;
                msg = "permission denied";
                data =false;
            };
        };
        switch(Map.get(contentMap,nhash, id)){
            case(null){
                return {
                    code = 404;
                    msg = "content not found";
                    data =false;
                };
            };
            case(?content){
                if(not Map.has(contentIndex, nhash, content.pid) or not Map.has(contentIndex, nhash, pid)){
                    return {
                        code = 404;
                        msg = "parent content not found";
                        data = false;
                    };
                };
                // 判断pid是否相同，如不同 删除原映射关联，添加新映射关联
                if (content.pid != pid){
                    switch(Map.get(contentIndex, nhash, content.pid)){
                        case(null){};
                        case(?oids){
                            switch(Map.get(contentIndex, nhash, pid)){
                                case(null){};
                                case(?nids){
                                    var newNids : List.List<Nat> = List.nil();
                                    newNids := List.push(id, newNids);
                                    newNids := List.append(newNids, nids);
                                    Map.set(contentIndex, nhash, content.pid, newNids);
                                };
                            };
                            var newOids = List.filter<Nat>(oids, func id { id != content.id});
                            Map.set(contentIndex, nhash, content.pid, newOids);
                        };
                    };
                };
                // 修改order
                let newContent : Content = {
                    id = content.id;
                    pid = pid;
                    name = name;
                    content = content.content;
                    order = order;
                    utime = content.utime;
                    uid = content.uid;
                    coAuthors = content.coAuthors;
                };
                Map.set(contentMap, nhash, content.id, newContent);
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };

    };

    public shared({caller}) func updateContent(id: Nat, name: Text, content: Text): async (Resp<Content>){
        if (not isMember(caller)){
            return {
                code = 403;
                msg = "permission denied";
                data = {id=0;pid=0;name="";content="";order=0;utime=Time.now();uid=caller;coAuthors=List.nil()}
            };
        };
        switch(Map.get(contentMap,nhash, id)){
            case(null){
                return {
                    code = 404;
                    msg = "content not found";
                    data = {id=0;pid=0;name="";content="";order=0;utime=Time.now();uid=caller;coAuthors=List.nil()}
                };
            };
            case(?content){
                var coAuthors : List.List<Principal> = List.nil();
                coAuthors := List.filter<Principal>(content.coAuthors, func uid {not Principal.equal(uid, caller)});

                let newContent : Content = {
                    id = content.id;
                    pid = content.pid;
                    name = name;
                    content = content.content;
                    order = content.order;
                    utime = Time.now();
                    uid = caller;
                    coAuthors = List.push(caller, coAuthors);
                };
                Map.set(contentMap, nhash, content.id, newContent);

                // todo : add log push portal

                return {
                    code = 200;
                    msg = "";
                    data = newContent;
                };
            };
        };
    };

    public shared({caller}) func delContent(id: Nat): async (Resp<Bool>){
        if (not isMember(caller)){
            return {
                code = 403;
                msg = "permission denied";
                data = false;
            };
        };
        switch(Map.get(contentMap, nhash, id)){
            case(null){};
            case(?content){
                Map.delete(contentMap, nhash, id);
                switch(Map.get(contentIndex, nhash, content.pid)){
                    case(null){};
                    case(?ids){
                        var newIds: List.List<Nat> = List.nil();
                        newIds := List.filter<Nat>(ids, func x { x != id});
                        Map.set(contentIndex, nhash, content.pid, newIds);
                    };
                };
            };
        };
        // todo : add log push portal

        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func getContent(id: Nat): async (Resp<ContentResp>){
        // 判断是否是成员 或者是否订阅
        if (showModel != #Public){
            if(not isMember(caller) and not isSubscriberByPid(caller)){
                return {
                    code = 403;
                    msg = "permission denied";
                    data = {id=0;pid=0;name="";content="";utime=Time.now();uAuthor=null;coAuthors=List.nil()};
                };
            };
        };
        switch(Map.get(contentMap, nhash, id)){
            case(null){
                return {
                    code = 404;
                    msg = "content not found";
                    data = {id=0;pid=0;name="";content="";utime=Time.now();uAuthor=null;coAuthors=List.nil()};
                };
            };
            case(?content){
                let uAuthorActor : UserActor = actor(Principal.toText(content.uid));
                let uAhthResp = await uAuthorActor.info();
                var coAuthors : List.List<User> = List.nil();
                for (uid in List.toIter(content.coAuthors)){
                    let coAuthorActor : UserActor = actor(Principal.toText(uid));
                    let coAuthorResp = await coAuthorActor.info();
                    coAuthors := List.push(coAuthorResp.data, coAuthors);
                };
                let resp : ContentResp ={
                    id = content.id;
                    pid = content.pid;
                    name = content.name;
                    content = content.content;
                    utime = content.utime;
                    uAuthor = ?uAhthResp.data;
                    coAuthors = coAuthors;
                };
                return {
                    code = 200;
                    msg = "";
                    data = resp;
                };
            }
        }
    };

    public shared({caller}) func getSummery(pid: Nat): async (Resp<[SummaryResp]>){
        // 判断是否是成员,仅私有空间不能查看目录
        if (showModel == #Private){
            if(not isMember(caller)){
                return {
                    code = 403;
                    msg = "permission denied";
                    data =[];
                };
            };
        };
        switch(Map.get(contentIndex, nhash, pid)){
            case(null){
                return {
                    code = 200;
                    msg = "";
                    data = [];
                };
            };
            case(?ids){
                var summarys : List.List<SummaryResp> = List.nil();
                for(id in List.toIter(ids)){
                    switch(Map.get(contentMap, nhash, id)){
                        case(null){};
                        case(?content){
                            let summary : SummaryResp = {
                                id = content.id;
                                pid = content.pid;
                                name = content.name;
                                order = content.order;
                            };
                            summarys := List.push( summary, summarys);
                        };
                    };
                };
                return {
                    code = 200;
                    msg = "";
                    data = List.toArray(summarys);
                };
            };
        };
    };

    // 由用户调用的 空间统计信息管理方法 -------------------------------------------------
    public shared func income(): async Resp<Nat> {
        return {
            code = 200;
            msg = "";
            data = 0;
        };
    };

    public shared func cycles(): async Nat{
        return Cycles.balance();
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


    // 由用户直接调用的  空间日志 --------------------------------
}