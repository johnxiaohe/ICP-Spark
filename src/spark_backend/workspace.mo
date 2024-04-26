import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import List "mo:base/List";
import Bool "mo:base/Bool";
import Error "mo:base/Error";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";

import Map "mo:map/Map";
import { nhash;thash } "mo:map/Map";

import types "types";
import Ledger "ledgers";
import configs "configs";

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
    type Log = types.Log;
    type FundsLog = types.FundsLog;
    type ContentLog = types.ContentLog;
    type EditorRanking = types.EditorRanking;
    type ViewRanking = types.ViewRanking;
    type SpaceData = types.SpaceData;

    // 第三方类型声明
    type Resp<T> = types.Resp<T>;
    type User = types.User;

    type Collection = types.Collection;
    type UserDetail = types.UserDetail;
    type TransferFromArgs = Ledger.TransferFromArgs;
    type TransferArgs = Ledger.TransferArgs;

    type ContentTrait = types.ContentTrait;
    type ViewResp = types.ViewResp;
    
    // actor 类型声明
    type LedgerActor = Ledger.Self;
    type UserActor = types.UserActor;
    type PortalActor = types.PortalActor;

    // 全局 actor api client 预创建
    let portal : PortalActor = actor(configs.SPARK_PORTAL_ID);
    let icpLedger: LedgerActor = actor(configs.ICP_LEGDER_ID);
    let cyclesLedger: LedgerActor = actor(configs.CYCLES_LEGDER_ID);
    // token类型 actor 预存，用于 转账和余额查询等
    private let tokenMap = HashMap.HashMap<Text, LedgerActor>(3, Text.equal, Text.hash);
    tokenMap.put("ICP", icpLedger);
    tokenMap.put("CYCLES", cyclesLedger);

    private stable var superUid : Text = Principal.toText(_creater); // user canister id
    private stable var superPid : Text = Principal.toText(_createrPid);
    private stable var name : Text = _name;
    private stable var avatar : Text = _avatar;
    private stable var desc : Text = _desc;
    private stable var ctime : Time.Time = _ctime;
    private stable var showModel : types.ShowModel = _showModel;
    private stable var price : Nat = _price;

    // 成员管理数据, workspace的api接口由用户直接调用；部分callback由 user canister 调用
    // 需要判断 pid / uid 用户的成员角色
    // pid --- uid
    private stable var memberMap = Map.new<Text,Text>();
    private stable var adminMap = Map.new<Text,Text>();
    // uid --- pid
    private stable var memberIdMap = Map.new<Text,Text>();

    // 订阅用户记录
    // pid --- uid
    private stable var consumerPidMap = Map.new<Text,Text>();
    // uid --- pid
    private stable var consumerUidMap = Map.new<Text,Text>();

    // 内容管理数据
    private stable var _contentIndex : Nat = 0;
    private stable var contentIndex = Map.new<Nat, List.List<Nat>>();
    private stable var contentMap = Map.new<Nat, Content>();
    private stable var traitMap = Map.new<Nat, ContentTrait>();
    private stable var contentViewMap = Map.new<Nat, Nat>();
    private stable var contentEditMap = Map.new<Nat, Nat>();
    private stable var userEditMap = Map.new<Text, Nat>();

    // 操作日志数据
    // 创建、转让、更新canister元数据。成员加入、更新和退出
    private stable var _syslog : List.List<Log> = List.nil();
    var zeroLog: Log = {
        time = Time.now();
        info = "created workspace; name: " # name;
        opeater = superPid;
    };
    _syslog := List.push(zeroLog, _syslog);
    // 内容收入、收入分配日志
    private stable var _fundslog : List.List<FundsLog> = List.nil();
    private stable var _consumerlog : List.List<Log> = List.nil();
    // 内容创建、更新
    private stable var _contentlog = Map.new<Nat, List.List<ContentLog>>();

    // 统计  ICP
    // 总收入
    private stable var _income : Nat = 0;
    // 已分配
    private stable var _outgiving: Nat = 0;
    // 总浏览
    private stable var _viewcount : Nat = 0;
    // 总编辑数
    private stable var _editcount : Nat = 0;

    // 内部调用的查询判断私有方法   ----------------------------------------------------------
    // 是否是管理员  pid: user principal id
    private func isAdmin(pid: Text): Bool{
        return Text.equal(pid, superPid) or Map.has(adminMap, thash, pid);
    };

    // 是否是成员
    private func isMember(pid: Text): Bool{
        return Text.equal(pid, superPid) or Map.has(adminMap, thash, pid) or Map.has(memberMap, thash, pid);
    };
    private func isMemberByUid(uid: Text): Bool{
        Map.has(memberIdMap, thash, uid);
    };

    private func isSuper(id: Text): Bool{
        return Text.equal(id, superUid) or Text.equal(id, superPid);
    };

    private func isSubscriberByPid(pid: Text): Bool{
        Map.has(consumerPidMap, thash, pid);
    };
    private func isSubscriberByUid(uid: Text): Bool{
        Map.has(consumerUidMap, thash, uid);
    };

    private func getMemberUid(pid: Text): Text{
        if(Text.equal(pid,superPid)){
            return superUid;
        };
        switch(Map.get(adminMap, thash, pid)){
            case(null){
                return "";
            };
            case(?uid){
                return uid;
            };
        };
        switch(Map.get(memberMap, thash, pid)){
            case(null){
                return "";
            };
            case(?uid){
                return uid;
            };
        };
    };

    // pid \ loginfo
    private func pushSysLog(opeater: Text, info: Text){
        let log : Log = {
            time = Time.now();
            info = info;
            opeater = opeater;
        };
        _syslog := List.push(log, _syslog);
    };

    private func pushConsumerLog(opeater: Text, info: Text){
        let log : Log = {
            time = Time.now();
            info = info;
            opeater = opeater;
        };
        _consumerlog := List.push(log, _consumerlog);
    };

    private func pushFundsLog(opeater: Text, info: Text, opType: Text, token: Text, price: Nat, balance: Nat){
        let log : FundsLog = {
            time = Time.now();
            info = info;
            opeater = opeater;
            opType = opType;
            token = token;
            price = price;
            balance = balance;
        };
        _fundslog := List.push(log, _fundslog);
    };

    private func pushContentLog(opeater: Text, opType: Text, index: Nat, name: Text){
        let log : ContentLog = {
            time = Time.now();
            opeater = opeater;
            opType = opType;
            index = index;
            name = name;
        };
        var newLogs : List.List<ContentLog> = List.nil();
        newLogs := List.push(log, newLogs);
        switch(Map.get(_contentlog, nhash, index)){
            case(null){
                Map.set(_contentlog, nhash, index, newLogs);
            };
            case(?logs){
                newLogs := List.append(newLogs, logs);
                Map.set(_contentlog, nhash, index, newLogs);
            }
        }
    };

    // 删除订阅只能由user canister调用　
    private func delSubscribe(uid: Text){
        switch(Map.get(consumerUidMap, thash, uid)){
            case(null){

            };
            case(?pid){
                Map.delete(consumerPidMap, thash, pid);
                pushConsumerLog(pid, "unsubscribed workspace")
            };
        };
        Map.delete(consumerUidMap, thash, uid);
    };

    // 由用户直接调用的 空间基础信息管理方法 ---------------------------------------------------------------
    public shared func info(): async Resp<WorkSpaceInfo>{
        return {
                code = 200;
                msg = "";
                data = {
                    id = Principal.toText(Principal.fromActor(this));
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
        let callerPid = Principal.toText(caller);
        if (not isAdmin(callerPid)){
            return {
                code = 403;
                msg = "permision denied";
                data = {
                    id=callerPid;
                    super=callerPid;
                    name="";
                    avatar="";
                    desc="";
                    ctime=ctime;
                    model=#Public;
                    price=0;
                };
            };
        };
        name := newName;
        avatar := newAvatar;
        desc := newDesc;

        pushSysLog(callerPid, "update workspace info; name: " # name);

        return {
            code = 200;
            msg = "";
            data = {
                id= Principal.toText(Principal.fromActor(this));
                super= superUid;
                name=name;
                avatar=avatar;
                desc=desc;
                ctime=ctime;
                model=showModel;
                price=price
            };
        };
    };

    public shared({caller}) func updateShowModel(newShowModel: types.ShowModel, newPrice: Nat): async Resp<Bool>{
        if(not isSuper(Principal.toText(caller))){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        // 公开度在缩小，则需要判断是否合法
        if(newShowModel == #Private and showModel != #Private and Map.size(consumerUidMap) > 0){
            if(showModel == #Payment){
                return {
                    code = 400;
                    msg = "payment model can not change to private";
                    data = false;
                };
            }else{
                // clear consumers
                for (uid in Map.keys(consumerUidMap)){
                    let userActor : UserActor = actor(uid);
                    await userActor.quitSubscribe();
                };
                Map.clear(consumerPidMap);
                Map.clear(consumerUidMap);
                // clear portal
            };
        };
        showModel := newShowModel;
        if(showModel == #Payment){
            price := newPrice;
        };

        pushSysLog( Principal.toText(caller) , "update workspace show model");

        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    // 获取当前用户在空间中的角色
    public shared({caller}) func role(): async Resp<Text>{
        let pid = Principal.toText(caller);
        if (Text.equal(pid, superPid)){
            return {
                code = 200;
                msg = "";
                data = "owner";
            }
        };
        if (isAdmin(pid)){
            return {
                code = 200;
                msg = "";
                data = "admin";
            }
        };
        if (isMember(pid)){
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
        let callerUid = Principal.toText(caller);
        if (isSuper(callerUid)){
            return false;
        };
        switch(Map.get(memberIdMap, thash, callerUid)){
            case(null){};
            case(?pid){
                Map.delete(memberIdMap, thash, callerUid);
                Map.delete(adminMap, thash, pid);
                Map.delete(memberMap, thash, pid);
                pushSysLog(pid, "quit workspace by self");
            };
        };
        return true;
    };

    // update super admin
    public shared({caller}) func transfer(uid: Text): async(Resp<Bool>){
        let callerPid = Principal.toText(caller);
        if (not isSuper(callerPid)){
            return {
                code = 403;
                msg = "permision denied";
                data = false;
            };
        };
        switch(Map.get(memberIdMap, thash, uid)){
            case(null){
                return {
                    code = 404;
                    msg = "target user not found in members";
                    data = false;
                };
            };
            case(?pid){
                let userActor : UserActor = actor(uid);
                let result: Bool = await userActor.reciveWns();
                if (not result){
                    return {
                        code = 500;
                        msg = "target user revice workspace failed";
                        data = false;
                    };
                };
                Map.set(memberIdMap, thash, superUid, superPid);
                Map.set(adminMap, thash, superPid, superUid);
                superUid := uid;
                superPid := pid;
                Map.delete(adminMap, thash, superPid);
                Map.delete(memberMap, thash, superPid);
                Map.delete(memberIdMap, thash, superUid);
                pushSysLog(callerPid, "transfered owner to {" # superPid # "}");
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };

    public shared func members(): async(Resp<[User]>){
        var result : List.List<User> = List.nil();
        for(uid in Map.vals(memberMap)){
            let userActor: UserActor = actor(uid);
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
        let superActor: UserActor = actor(superUid);
        let superResp = await superActor.info();
        let superInfo : User = superResp.data;
        result := List.push(superInfo, result);
        for(uid in Map.vals(adminMap)){
            let userActor: UserActor = actor(uid);
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

    public shared({caller}) func addMember(uid: Text, role: Text): async(Resp<Bool>){
        if(isMemberByUid(uid)){
            return {
                code = 400;
                msg = "user member exists";
                data = false;
            };
        };
        if (not isAdmin(Principal.toText(caller))){
            return {
                code = 403;
                msg = "permission denied";
                data = false;
            };
        };
        let userActor: UserActor = actor(uid);
        let userResp = await userActor.info();
        let pid = userResp.data.pid;
        Map.set(memberIdMap, thash, uid, pid);
        if (role == "admin"){
            Map.set(adminMap, thash, pid, uid);
        }else if (role == "member"){
            Map.set(memberMap, thash, pid, uid);
        }else{
            return {
                code = 400;
                msg = "role not exist";
                data = false;
            };
        };

        pushSysLog(Principal.toText(caller), "add member: {" # pid # "} with role: " # role);

        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func delMember(uid: Text): async(Resp<Bool>){
        if(not isAdmin(Principal.toText(caller))){
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
        switch(Map.get(memberIdMap, thash, uid)){
            case(null){
                return {
                    code = 400;
                    msg = "user not found";
                    data = false;
                };
            };
            case(?pid){
                // 仅超管可以删管理员
                if(isAdmin(pid) and not isSuper(Principal.toText(caller))){
                    return {
                        code = 403;
                        msg = "only super admin can do that";
                        data = false;
                    };
                };
                let userActor : UserActor = actor (uid);
                let result = await userActor.leaveWorkNs();
                if (not result){
                    return {
                        code = 500;
                        msg = "del member failed";
                        data = false;
                    };
                };
                Map.delete(memberIdMap, thash, uid);
                Map.delete(adminMap, thash, pid);
                Map.delete(memberMap, thash, pid);
                pushSysLog(Principal.toText(caller), "del member: {" # pid # "}");
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };
    };

    public shared({caller}) func updatePermission(uid: Text, role: Text): async(Resp<Bool>){
        if(not isAdmin(Principal.toText(caller))){
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
        switch(Map.get(memberIdMap, thash, uid)){
            case(null){
                return {
                    code = 400;
                    msg = "user not found";
                    data = false;
                };
            };
            case(?pid){
                if(role == "admin"){
                    if(not isSuper(Principal.toText(caller))){
                        return {
                            code = 403;
                            msg = "only super admin change admin role";
                            data = false;
                        };
                    };
                    Map.delete(memberMap, thash, pid);
                    Map.set(adminMap, thash, pid,uid);
                }else if(role == "member"){
                    Map.delete(adminMap, thash, pid);
                    Map.set(memberMap, thash, pid,uid);
                }else{
                    return {
                        code = 400;
                        msg = "role not exist";
                        data = false;
                    };
                };

                pushSysLog(Principal.toText(caller), "update member : {" # pid # "} with role: " # role);

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
        if (isSubscriberByUid(Principal.toText(caller))){
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

        var msg = "";
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
                    Map.set(consumerPidMap, thash, userInfo.pid, userInfo.id);
                    Map.set(consumerUidMap, thash, userInfo.id, userInfo.pid);
                    msg := "blockIndex: " # Nat.toText(blockIndex);
                    pushFundsLog(userInfo.pid, "subscribed workspace", "income", "ICP", price, await icpLedger.icrc1_balance_of({owner=Principal.fromActor(this);subaccount=null}));
                    _income := _income + price;
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
        Map.set(consumerPidMap, thash, userInfo.pid, userInfo.id);
        Map.set(consumerUidMap, thash, userInfo.id, userInfo.pid);
        
        pushConsumerLog(userInfo.pid, "subscribed workspace");
        
        return {
            code = 200;
            msg = msg;
            data = true;
        };
    };

    public shared({caller}) func unSubscribe(): async (Resp<Bool>){
        if (not isSubscriberByUid(Principal.toText(caller))){
            return {
                code = 400;
                msg = "not subscriber";
                data = false;
            };
        };
        delSubscribe(Principal.toText(caller));

        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared func collectionCall(index: Nat): async (Resp<Collection>){
        switch(Map.get(contentMap, nhash, index)){
            case(null){
                return {
                    code = 404;
                    msg = "content not found";
                    data = {
                        wid=Principal.toText(Principal.fromActor(this)); 
                        wName=name;
                        index=index;
                        name="content not found"
                    };
                };
            };
            case(?content){
                return {
                    code = 200;
                    msg = "";
                    data = {
                        wid=Principal.toText(Principal.fromActor(this)); 
                        wName=name;
                        index=index;
                        name=content.name
                    };
                };
            };
        };
    };

    // 由消费者调用  查看是否有订阅 -------------------------------------
    public shared({caller}) func haveSubscribe(): async (Resp<Bool>){
        if (isSubscriberByPid(Principal.toText(caller))){
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
    public shared({caller}) func createContent(name: Text, parentId : Nat, sort: Nat): async (Resp<Content>){
        let callerPid = Principal.toText(caller);
        let callerUid = getMemberUid(callerPid);
        if (Text.equal(callerUid, "")){
            return {
                code = 403;
                msg = "permission denied";
                data = {id=0;pid=0;name="";content="";order=0;utime=Time.now();uid=Principal.toText(caller);coAuthors=List.nil();sort=0;};
            };
        };
        // pid id 循环
        _contentIndex := _contentIndex + 1;
        let index = _contentIndex;
        var pid = parentId;
        if (index == parentId){
            pid := 0;
        };
        var authors : List.List<Text> = List.nil();
        let content: Content = {
            id = index;
            pid = pid;
            name = name;
            content = "";
            sort = sort;
            utime = Time.now();
            uid = callerUid;
            coAuthors = List.push(callerUid, authors);
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

        // todo : add log
        pushContentLog(callerPid,"create",index,name);

        return {
            code = 200;
            msg = "";
            data = content;
        };
    };

    public shared({caller}) func changeLocal(id: Nat, pid: Nat, sort: Nat): async (Resp<Bool>){
        if (not isMember(Principal.toText(caller))){
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
                    name = content.name;
                    content = content.content;
                    sort = sort;
                    utime = content.utime;
                    uid = content.uid;
                    coAuthors = content.coAuthors;
                };
                Map.set(contentMap, nhash, content.id, newContent);
                // todo : add log push portal
                pushContentLog(Principal.toText(caller), "sort", content.id, content.name);
                return {
                    code = 200;
                    msg = "";
                    data = true;
                };
            };
        };

    };

    public shared({caller}) func updateContent(id: Nat, name: Text, content: Text): async (Resp<Content>){
        let callerPid = Principal.toText(caller);
        if (not isMember(callerPid)){
            return {
                code = 403;
                msg = "permission denied";
                data = {id=0;pid=0;name="";content="";sort=0;utime=Time.now();uid=Principal.toText(caller);coAuthors=List.nil();}
            };
        };
        switch(Map.get(contentMap,nhash, id)){
            case(null){
                return {
                    code = 404;
                    msg = "content not found";
                    data = {id=0;pid=0;name="";content="";sort=0;utime=Time.now();uid=Principal.toText(caller);coAuthors=List.nil();}
                };
            };
            case(?content){
                var coAuthors : List.List<Text> = List.nil();
                coAuthors := List.filter<Text>(content.coAuthors, func uid {not Text.equal(uid, callerPid)});

                let newContent : Content = {
                    id = content.id;
                    pid = content.pid;
                    name = name;
                    content = content.content;
                    sort = content.sort;
                    utime = Time.now();
                    uid = callerPid;
                    coAuthors = List.push(callerPid, coAuthors);
                };
                Map.set(contentMap, nhash, content.id, newContent);

                // log
                _editcount := _editcount + 1;
                pushContentLog(Principal.toText(caller), "update", content.id, content.name);
                switch(Map.get(contentEditMap, nhash, content.id)){
                    case(null){
                        Map.set(contentEditMap, nhash, content.id, 1);
                    };
                    case(?count){
                        Map.set(contentEditMap, nhash, content.id, count + 1);
                    };
                };
                switch(Map.get(userEditMap, thash, callerPid)){
                    case(null){
                        Map.set(userEditMap, thash, callerPid, 1);
                    };
                    case(?count){
                        Map.set(userEditMap, thash, callerPid, count + 1);
                    };
                };

                return {
                    code = 200;
                    msg = "";
                    data = newContent;
                };
            };
        };
    };

    // 更新内容时提示是否要发布至广场(如非Public空间不会变更可见性，用户需订阅或者付费才能看到具体内容)
    public shared({caller}) func updateTrait(index: Nat, name: Text, desc: Text, plate: Text, tag: [Text]): async(Resp<Bool>){
        let callerPid = Principal.toText(caller);
        if (not isMember(callerPid)){
            return {
                code = 403;
                msg = "permission denied";
                data =false;
            };
        };
        let trait : ContentTrait = {
            index = index;
            wid = Principal.toText(Principal.fromActor(this));
            name = name;
            desc = desc;
            plate = plate;
            tag = tag;
            like = 0;
            view = 0;
        };
        Map.set(traitMap, nhash, index, trait);
        return {
            code = 200;
            msg = "";
            data =true;
        };
    };

    public shared({caller}) func pushPortal(index: Nat): async(Resp<Bool>){
        let callerPid = Principal.toText(caller);
        if (not isMember(callerPid)){
            return {
                code = 403;
                msg = "permission denied";
                data =false;
            };
        };
        if (showModel == #Private){
            return {
                code = 403;
                msg = "private model workspace can not public content";
                data =false;
            };
        };

        var view = 0;
        switch(Map.get(contentViewMap, nhash, index)){
            case(null){};
            case(?count){
                view := count;
            };
        };
        switch(Map.get(traitMap, nhash, index)){
            case(null){
                return {
                    code = 404;
                    msg = "trait not found";
                    data = false;
                };
            };
            case(?trait){
                let newTrait : ContentTrait = {
                    index = trait.index;
                    wid = trait.wid;
                    name = trait.name;
                    desc = trait.desc;
                    plate = trait.plate;
                    tag = trait.tag;
                    like = 0;
                    view = view;
                };
                await portal.push(newTrait);
            };
        };
        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func getTrait(index: Nat): async (Resp<ContentTrait>){
        let callerPid = Principal.toText(caller);
        if (showModel == #Private and not isMember(callerPid)){
            return {
                code = 403;
                msg = "private model workspacet";
                data ={index=0;wid="";name="";desc="";plate="";tag=[];like=0;view=0;};
            };
        };
        var view = 0;
        switch(Map.get(contentViewMap, nhash, index)){
            case(null){};
            case(?count){
                view := count;
            };
        };
        switch(Map.get(traitMap, nhash, index)){
            case(null){
                return {
                    code = 404;
                    msg = "trait not found";
                    data = {index=0;wid="";name="";desc="";plate="";tag=[];like=0;view=0;};
                };
            };
            case(?trait){
                let newTrait : ContentTrait = {
                    index = trait.index;
                    wid = trait.wid;
                    name = trait.name;
                    desc = trait.desc;
                    plate = trait.plate;
                    tag = trait.tag;
                    like = 0;
                    view = view;
                };
                return {
                    code = 200;
                    msg = "";
                    data = newTrait;
                };
            };
        };
    };

    public shared func views(indexs: [Nat]): async([ViewResp]){
        var result : List.List<ViewResp> = List.nil();
        for(index in Array.vals(indexs)){
            var view = 0;
            switch(Map.get(contentViewMap, nhash, index)){
                case(null){};
                case(?viewnumber){view := viewnumber};
            };
            let viewResp : ViewResp = {
                index = index;
                view = view;
            };
            result := List.push( viewResp, result);
        };
        return List.toArray(result);
    };

    public shared({caller}) func delContent(id: Nat): async (Resp<Bool>){
        if (not isMember(Principal.toText(caller))){
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
                // todo : add log push portal
                pushContentLog(Principal.toText(caller), "delete", id, content.name);
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

        return {
            code = 200;
            msg = "";
            data = true;
        };
    };

    public shared({caller}) func getContent(id: Nat): async (Resp<ContentResp>){
        // 判断是否是成员 或者是否订阅
        if (showModel != #Public){
            if(not isMember(Principal.toText(caller)) and not isSubscriberByPid(Principal.toText(caller))){
                return {
                    code = 403;
                    msg = "permission denied";
                    data = {id=0;pid=0;name="";content="";utime=Time.now();uAuthor=null;coAuthors=List.nil();viewCount = 0};
                };
            };
        };
        switch(Map.get(contentMap, nhash, id)){
            case(null){
                return {
                    code = 404;
                    msg = "content not found";
                    data = {id=0;pid=0;name="";content="";utime=Time.now();uAuthor=null;coAuthors=List.nil();viewCount = 0};
                };
            };
            case(?content){
                let uAuthorActor : UserActor = actor(content.uid);
                let uAhthResp = await uAuthorActor.info();
                var coAuthors : List.List<User> = List.nil();
                for (uid in List.toIter(content.coAuthors)){
                    let coAuthorActor : UserActor = actor(uid);
                    let coAuthorResp = await coAuthorActor.info();
                    coAuthors := List.push(coAuthorResp.data, coAuthors);
                };
                var viewCount = 0;
                switch(Map.get(contentViewMap, nhash, content.id)){
                    case(null){
                        viewCount := viewCount + 1;
                    };
                    case(?count){
                        viewCount := count + 1;
                        Map.set(contentViewMap, nhash, content.id, viewCount);
                    }
                };
                let resp : ContentResp ={
                    id = content.id;
                    pid = content.pid;
                    name = content.name;
                    content = content.content;
                    utime = content.utime;
                    uAuthor = ?uAhthResp.data;
                    coAuthors = coAuthors;
                    viewCount = viewCount;
                };
                _viewcount := _viewcount + 1;
                return {
                    code = 200;
                    msg = "";
                    data = resp;
                };
            }
        }
    };

    // summary all
    public shared({caller}) func summary(): async (Resp<[SummaryResp]>){
        if (showModel == #Private and not isMember(Principal.toText(caller))){
            return {
                code = 403;
                msg = "workspace is private";
                data = [];
            };
        };
        var result : List.List<SummaryResp> = List.nil();
        for(content in Map.vals(contentMap)){
            let summary : SummaryResp = {
                id = content.id;
                pid = content.pid;
                name = content.name;
                sort = content.sort;
            };
            result := List.push( summary, result);
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared({caller}) func getSummery(pid: Nat): async (Resp<[SummaryResp]>){
        // 判断是否是成员,仅私有空间不能查看目录
        if (showModel == #Private){
            if(not isMember(Principal.toText(caller))){
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
                                sort = content.sort;
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

    public shared({caller}) func searchSummery(keyword: Text): async (Resp<[SummaryResp]>){
        // 判断是否是成员,仅私有空间不能查看目录
        if (showModel == #Private){
            if(not isMember(Principal.toText(caller))){
                return {
                    code = 403;
                    msg = "permission denied";
                    data =[];
                };
            };
        };
        var result : List.List<SummaryResp> = List.nil();
        for (content in Map.vals(contentMap)){
            if(Text.contains(content.name, #text keyword)){
                let resp : SummaryResp = {
                    id = content.id;
                    pid = content.pid;
                    name = content.name;
                    sort = content.sort;
                };
                result := List.push(resp, result);
            };
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    // 由用户调用的 空间统计信息管理方法 -------------------------------------------------
    public shared func count(): async Resp<SpaceData>{
        return{
            code = 200;
            msg = "";
            data = {
                income = _income;
                outgiving = _outgiving;
                editcount = _editcount;
                viewcount = _viewcount;
                membercount = Map.size(memberIdMap) + 1;
                subscribecount = Map.size(consumerPidMap);
            };
        };
    };

    public shared func editRanking(): async Resp<[EditorRanking]>{
        var result : List.List<EditorRanking> = List.nil();
        Map.forEach<Text,Nat>(userEditMap, func (pid,count)  {
            let ranking: EditorRanking = {
                pid = pid;
                count = count;
            };
            result := List.push(ranking, result);
        });
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    public shared func viewRanking(): async Resp<[ViewRanking]> {
        var result : List.List<ViewRanking> = List.nil();
        Map.forEach<Nat,Nat>(contentViewMap, func (id,count)  {
            switch(Map.get(contentMap, nhash, id)){
                case(null){};
                case(?content){
                    let ranking: ViewRanking = {
                        id = content.id;
                        name = content.name;
                        count = count;
                    };
                    result := List.push(ranking, result);
                };
            }
        });
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
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

    public shared({caller}) func outgiving(uid: Text, amount: Nat): async Resp<Bool>{
        if(not isSuper(Principal.toText(caller))){
            return {
                code = 403;
                msg = "permission denied";
                data = false;
            };
        };
        let balance = await icpLedger.icrc1_balance_of({owner=Principal.fromActor(this);subaccount=null});
        let fee = await icpLedger.icrc1_fee();
        if (balance < (amount+fee)){
            return {
                code = 400;
                msg = "balance is not enought";
                data = false;
            };
        };

        let transferArgs : TransferArgs = {
            memo = null;
            amount = amount;
            from_subaccount = null;
            fee = ?fee;
            to = { owner = Principal.fromText(uid); subaccount = null };
            created_at_time = null;
        };
        try {
            // initiate the transfer
            let transferResult = await icpLedger.icrc1_transfer(transferArgs);

            // check if the transfer was successfull
            switch (transferResult) {
                case (#Err(transferError)) {
                    return {
                        code = 500;
                        msg =  "Couldn't transfer funds:\n" # debug_show (transferError);
                        data = false;
                    };
                };
                case (#Ok(blockIndex)) {
                    _outgiving := _outgiving + amount + fee;

                    pushFundsLog(Principal.toText(caller), "out giving", "outgiving", "ICP", amount, await icpLedger.icrc1_balance_of({owner=Principal.fromActor(this);subaccount=null}));
                    
                    return {
                        code = 200;
                        msg = "";
                        data = true;
                    };
                };
            };
        } catch (error : Error) {
            // catch any errors that might occur during the transfer
            return {
                code = 500;
                msg = "Reject message: " # Error.message(error);
                data = false;
            };
        };
    };

    // 由用户直接调用的  空间日志 --------------------------------
    public shared({caller}) func contentLog(id: Nat): async Resp<[ContentLog]>{
        if (not isMember(Principal.toText(caller))){
            return {
                code = 403;
                msg = "permision denied";
                data = [];
            };
        };
        switch(Map.get(_contentlog, nhash, id)){
            case(null){
                return {
                    code = 200;
                    msg = "";
                    data = [];
                };
            };
            case(?logs){
                return {
                    code = 200;
                    msg = "";
                    data = List.toArray(logs);
                };
            };
        };
    };

    public shared({caller}) func fundsLog(): async Resp<[FundsLog]>{
        if (not isMember(Principal.toText(caller))){
            return {
                code = 403;
                msg = "permision denied";
                data = [];
            };
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(_fundslog);
        };
    };

    public shared({caller}) func consumerLog(): async Resp<[Log]>{
        if (not isMember(Principal.toText(caller))){
            return {
                code = 403;
                msg = "permision denied";
                data = [];
            };
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(_consumerlog);
        }
    };
    
    public shared({caller}) func sysLog(): async Resp<[Log]>{
        if (not isMember(Principal.toText(caller))){
            return {
                code = 403;
                msg = "permision denied";
                data = [];
            };
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(_syslog);
        };
    };

};