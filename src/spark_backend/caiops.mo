// canister manage 模块，该模块用于Spark线上child canister的代码升级(user canister、workspace canister)
// 主要流程原理：使用ic-manageapi通过 controller 角色 对指定的canister wasm code更新
// 不能批量更新，只能一个一个更新，wasm对多个canister更新的话，从canister发起会造成大量cycles损耗？
// 必须要有一个中心的 update admin canister发起做这个事情 
// 问题点4: update admin canister的安全性问题？需要 child canister添加controller权限
// 1. 安全性问题，在admin canister做好控制权限后，未升级情况下将控制权给用户，用户可以在update时将控制权临时授权给 平台。平台授权后将自动取消自身授权
// 问题点5: update admin的控制权权限是否可以分散？
// 1. 管理员列表，判断权限
// 2. 增加角色和api权限接口
// 问题点6: child canister pid 如何归集？ 
//    1. root canister init接口主动初始化
//    2. root canister主动推送
import Text "mo:base/Text";
import List "mo:base/List";
import Time "mo:base/Time";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Array "mo:base/Array";

import Map "mo:map/Map";
import { phash;thash } "mo:map/Map";

import types "types";
import management "management";

// client --> wasm update canister(管理权给到admin user，需要更新升级的话由admin user临时授权升级后取消) --> target canister
// child canister 从main canister拉取 或者创建后推送给 update admin canister
actor{

    type CanisterOps = types.CanisterOps;
    type CaiModule = types.CaiModule;
    type CaiVersion = types.CaiVersion;

    type Management = management.Management;
    let mng : Management = actor("aaaaa-aa");

    // admin users
    let admins = Map.new<Principal,Text>();

    // 模块基本信息：名称、描述、root canister(如有)、upmodule(如有，将定时从upmodule canister同步child)
    let modulesMap = Map.new<Text,CaiModule>();
    // 模块 --- 版本wasm列表
    let versionMap = Map.new<Text,List.List<CaiVersion>>();
    // 模块 --- cai ids
    let moduleCaisMap = Map.new<Text,List.List<Text>>();

    let caiDescMap = Map.new<Text, Text>();

    let caiTags = Map.new<Text, List.List<Text>>();

    private func isAdmin(pid: Principal) : (Bool){
        switch(Map.get(admins, phash, pid)){
            case(null){ false};
            case(?p){true};
        }
    };

    public shared({caller}) func adminList() : async([Text]){
        if(isAdmin(caller)){
            return Iter.toArray(Map.vals(admins))
        };
        return [];
    };

    public shared({caller}) func addAdmins(pid: Principal) : async(){
        if(isAdmin(caller)){
            Map.set(admins, phash, pid, Principal.toText(pid))
        };
    };

    public shared({caller}) func delAdmins(pid: Principal): async(){
        if(isAdmin(caller)){
            Map.delete(admins, phash, pid);
        };
    };

    public shared({caller}) func modules(): async([CaiModule]){
        if(not isAdmin(caller)){
            return [];
        };
        Iter.toArray(Map.vals(modulesMap));
    };

    public shared({caller}) func addOrUpdateModule(cmdl: CaiModule): async(){
        if(not isAdmin(caller)){
            return;
        };
        Map.set(modulesMap, thash, cmdl.name, cmdl);
    };

    public shared({caller}) func delModule(name: Text): async(){
        if(not isAdmin(caller)){
            return;
        };
        Map.delete(modulesMap, thash, name);
    };

    public shared({caller}) func addVersion(moduleName: Text, version: CaiVersion): async(){
        if(not isAdmin(caller)){
            return;
        };

        switch(Map.get(versionMap, thash, moduleName)){
            case(null){
                var newVersions : List.List<CaiVersion> = List.nil();
                newVersions := List.push(version, newVersions);
                Map.set(versionMap, thash, moduleName, newVersions);
            };
            case(?versions){
                var newVersions : List.List<CaiVersion> = List.nil();
                newVersions := List.push(version, newVersions);
                // todo: find the exist version and update it
                newVersions := List.append(newVersions, versions);
                Map.set(versionMap, thash, moduleName, newVersions);
            };
        };
    };

    // 模块child init
    public shared({caller}) func initChilds(moduleName: Text): async(){
        if(not isAdmin(caller)){
            return;
        };
        switch(Map.get(modulesMap, thash, moduleName)){
            case(null){};
            case(?caiModule){
                if(not caiModule.isChild){
                    return;
                };
                if(caiModule.parentModule != ""){
                    var childs : List.List<Text> = List.nil();
                    switch(Map.get(moduleCaisMap, thash, caiModule.parentModule)){
                        case(null){return};
                        case(?parentCids){
                            for (parentCid in List.toIter(parentCids)){
                                let parentCai : CanisterOps = actor(parentCid);
                                let result: [Text] = await parentCai.childCids(moduleName);
                                childs := List.append(childs, List.fromArray<Text>(result));
                            };
                            Map.set(moduleCaisMap, thash, moduleName, childs);
                        };
                    };
                    return;
                };
            };
        };
    };

    public shared({caller}) func setCaiDesc(cid: Text, desc: Text): async(){
        if(not isAdmin(caller)){
            return;
        };
        Map.set(caiDescMap, thash, cid, desc);
    };

    public shared({caller}) func setCaiTags(cid: Text, tags: [Text]): async(){
        if(not isAdmin(caller)){
            return;
        };
        Map.set(caiTags, thash, cid, List.fromArray(tags));
    };

    public shared({caller}) func moduleCais(moduleName: Text): async([Text]){
        if(not isAdmin(caller)){
            return [];
        };
        switch(Map.get(moduleCaisMap, thash, moduleName)){
            case(null){[]};
            case(?cids){ List.toArray(cids)};
        };
    };

    // child 推送通知;父模块推送过来添加子模块cai的通知
    public shared({caller}) func addCanister(moduleName: Text, pid: Text): async(){
        // 查找模块是否存在
        switch(Map.get(modulesMap, thash, moduleName)){
            case(null){return};
            case(?thisModule){
                // 判断是否是子模块类型
                if(not thisModule.isChild){
                    return;
                };
                // 判断父模块是否存在
                switch(Map.get(moduleCaisMap, thash, thisModule.parentModule)) {
                    case(null) {return};
                    case(?cais) {
                        let callerId = Principal.toText(caller);
                        // 判断caller是否在父模块中
                        switch(List.find<Text>(cais, func epid {Text.equal(epid, callerId)})){
                            case(null){return};
                            case(?index){
                                // 添加到模块cai列表
                                switch(Map.get(moduleCaisMap, thash, moduleName)){
                                    case(null){return};
                                    case(?childCais){
                                        var newChildCais = List.make(pid);
                                        newChildCais := List.append(newChildCais, childCais);
                                        Map.set(moduleCaisMap, thash, moduleName, newChildCais);
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    };

    // 父模块主动摧毁或者子模块自己摧毁
    public shared({caller}) func delCanister(moduleName: Text, pid: Text): async(){
        // 查找模块是否存在
        switch(Map.get(modulesMap, thash, moduleName)){
            case(null){return};
            case(?thisModule){
                // 判断是否是子模块类型
                if(not thisModule.isChild){
                    return;
                };

                var delFlag = false;
                // 判断父模块是否存在
                switch(Map.get(moduleCaisMap, thash, thisModule.parentModule)) {
                    case(null) {return};
                    case(?cais) {
                        let callerId = Principal.toText(caller);
                        switch(List.find<Text>(cais, func epid {Text.equal(epid, callerId)})){
                            case(null){
                                // caller不是父模块,判断是否是自己摧毁自己
                                delFlag := Text.equal(callerId, pid);
                            };
                            case(?index){
                                // 判断caller是否在父模块中
                                delFlag := true;
                            };
                        };
                    };
                };
                if(not delFlag){
                    return;
                };
                // 从列表中删除该pid
                switch(Map.get(moduleCaisMap, thash, moduleName)){
                    case(null){return};
                    case(?childCais){
                        var newChildCais = List.filter<Text>(childCais, func epid {not Text.equal(epid, pid)});
                        Map.set(moduleCaisMap, thash, moduleName, newChildCais);
                    };
                };
            };
        };
    };

    public shared({caller}) func addCanisterByAdmin(moduleName: Text, pid: Text): async(Bool){
        if(not isAdmin(caller)){
            return false;
        };
        switch(Map.get(moduleCaisMap, thash, moduleName)){
            case(null){return false};
            case(?cais){
                var newCais = List.make(pid);
                newCais := List.append(newCais, cais);
                Map.set(moduleCaisMap, thash, moduleName, newCais);
            };
        };
        return true;
    };

    public shared({caller}) func delCanisterByAdmin(moduleName: Text, pid: Text): async(Bool){
        if(not isAdmin(caller)){
            return false;
        };
        switch(Map.get(moduleCaisMap, thash, moduleName)){
            case(null){return false};
            case(?cais){
                var newCais = List.filter<Text>(cais, func epid {not Text.equal(epid, pid)});
                Map.set(moduleCaisMap, thash, moduleName, newCais);
            };
        };
        return true;
    };

    // 更新模块部分canister
    public shared({caller}) func updateTargetCais(moduleName: Text, version: Text, cids: [Text]): async(Bool){
        if(not isAdmin(caller)){
            return false;
        };
        // todo: logs
        var wasm : [Nat8]= [];
        switch(Map.get(versionMap, thash, moduleName)){
            case(null){return false;};
            case(?versions){
                switch(List.find<CaiVersion>(versions, func v {Text.equal(v.name, version)})){
                    case(null){return false};
                    case(?thisVersion){
                        wasm := thisVersion.wasm;
                    };
                };
            };
        };
        if (Array.size(wasm) ==0){
            return false;
        };
        switch(Map.get(moduleCaisMap, thash, moduleName)){
            case(null){return true};
            case(?cais){
                // update one by one
                for(cid in List.toIter(cais)){
                    if(List.some<Text>(List.fromArray(cids), func c {Text.equal(c, cid)})){
                        ignore mng.install_code({
                            arg = [];
                            wasm_module = wasm;
                            mode = #upgrade;
                            canister_id = Principal.fromText(cid);
                        });
                    };

                };
            };
        };
        return true;
    };

    // 更新模块所有canister
    public shared({caller}) func updateAllCais(moduleName: Text, version: Text): async(Bool){
        if(not isAdmin(caller)){
            return false;
        };
        // todo: logs
        var wasm : [Nat8]= [];
        switch(Map.get(versionMap, thash, moduleName)){
            case(null){return false;};
            case(?versions){
                switch(List.find<CaiVersion>(versions, func v {Text.equal(v.name, version)})){
                    case(null){return false};
                    case(?thisVersion){
                        wasm := thisVersion.wasm;
                    };
                };
            };
        };
        if (Array.size(wasm) ==0){
            return false;
        };
        switch(Map.get(moduleCaisMap, thash, moduleName)){
            case(null){return true};
            case(?cais){
                // update one by one
                for(cid in List.toIter(cais)){
                    ignore mng.install_code({
                        arg = [];
                        wasm_module = wasm;
                        mode = #upgrade;
                        canister_id = Principal.fromText(cid);
                    });
                };
            };
        };
        return true;
    };

    // todo: async update queue

}