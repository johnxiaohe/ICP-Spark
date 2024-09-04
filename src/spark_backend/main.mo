import Text "mo:base/Text";
import List "mo:base/List";
import Time "mo:base/Time";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
// import Debug "mo:base/Debug";

import Map "mo:map/Map";
import { thash } "mo:map/Map";

import ic "ic";
import configs "configs";
import types "types";
import userspace "user";

// 接口消息最大承载容量2MB
actor{

  type ICActor = ic.ICActor;
  type CanisterOps = types.CanisterOps;
  let IC: ICActor = actor(configs.IC_ID);
  let CaiOps : CanisterOps = actor(configs.SPARK_CAIOPS_ID);

  type Resp<T> = types.Resp<T>;
  type User = types.User;
  type UserActor = userspace.UserSpace;

  // user pid --- user info map
  private stable var userMap = Map.new<Text,User>();
  // user id --- user pid
  private stable var userIdMap = Map.new<Text,Text>();
  // 用户注册先后排名
  private stable var _ranking : List.List<Text> = List.nil();

  private stable var _cyclesPerUser: Nat = 200_000_000_000; // 0.2t cycles for each token canister

  system func preupgrade() {};

  system func postupgrade() {};

  public query({caller}) func version(): async (Text){
    return "v1.0.0"
  };

  public query({caller}) func initArgs(): async(Blob){
    return to_candid();
  };

  public query({caller}) func childCids(moduleName: Text): async ([Text]){
    if (not Principal.equal(caller, Principal.fromText(configs.SPARK_CAIOPS_ID))){
      return []
    };
    if (Text.equal(moduleName, "userspace")){
      return Iter.toArray(Map.keys(userIdMap));
    };
    return [];
  };

  // 录入个人信息
  public shared({caller}) func initUserInfo(name: Text, avatar: Text, desc: Text): async Resp<User>{
    let contains = Map.has(userMap, thash, Principal.toText(caller));
    if (contains){
      return {
          code=400;
          msg="user exist";
          data={id=Principal.toText(caller);avatar="";desc="";name="";pid=Principal.toText(caller);ctime=0};
      };
    };
    Cycles.add<system>(_cyclesPerUser);
    let ctime = Time.now();
    // Debug.print(debug_show(ctime));
    let userActor = await userspace.UserSpace(name, caller, avatar, desc, ctime);
    let userActorId = Principal.fromActor(userActor);

    // 添加控制器（用户、cycles监控黑洞、caiops）
    let controllers: ?[Principal] = ?[caller, Principal.fromText(configs.BLACK_HOLE_ID), Principal.fromText(configs.SPARK_CAIOPS_ID)];
    let settings : ic.CanisterSettings = {
      controllers = controllers;
      compute_allocation = null;
      freezing_threshold = null;
      memory_allocation = null;
    };
    let params: ic.UpdateSettingsParams = {
        canister_id = userActorId;
        settings = settings;
    };
    await IC.update_settings(params);

    ignore CaiOps.addCanister("userspace", Principal.toText(userActorId));

    // 添加业务关联记录
    _ranking := List.push( Principal.toText(caller), _ranking);
    let user:User = {
      id=Principal.toText(userActorId);
      pid=Principal.toText(caller);
      name=name;
      avatar=avatar;
      desc=desc;
      ctime=ctime;
    };
    Map.set(userMap, thash, Principal.toText(caller), user);
    Map.set(userIdMap, thash, Principal.toText(userActorId), Principal.toText(caller));
    return {
      code=200;
      msg="user exist";
      data=user;
    };
  };

  // user canister update callback
  public shared({caller}) func userUpdateCall(owner: Principal, name: Text, avatar: Text, desc: Text): async(){
    var user = Map.get(userMap, thash, Principal.toText(owner));
    switch(user){
      case(null){
        return
      };
      case(?user){
        // only update user canister by self
        if (Principal.equal(caller, Principal.fromText(user.id))){
          let nUser:User = {
            id=Principal.toText(caller);
            pid=user.pid;
            name=name;
            avatar=avatar;
            desc=desc;
            ctime=user.ctime;
          };
          Map.set(userMap, thash, user.pid, nUser);
        };
      };
    };
  };

  // 查询个人基础信息
  public query({caller}) func queryUserInfo(): async Resp<User> {
    switch(Map.get(userMap, thash, Principal.toText(caller))){
      case(null){
        return {
          code=404;
          msg="user not registed";
          data={id=Principal.toText(caller);avatar="";desc="";name="";pid=Principal.toText(caller);ctime=0};
        };
      };
      case(?user){
        return {
          code=200;
          msg="";
          data=user;
        };
      };
    };
  };

  // 用户名称模糊查询
  public query func queryByName(keyword: Text): async(Resp<[User]>){
    var result : List.List<User> = List.nil();
    for (u in Map.vals(userMap)){
      let name = u.name;
      if (Text.contains(name, #text keyword)){
        result := List.push(u, result);
      };
    };
    return {
      code=200;
      msg="";
      data=List.toArray(result);
    };
  };

  // 用户canisterid查询
  public query({caller}) func queryById(id: Text): async(Resp<User>){
    switch(Map.get(userIdMap, thash, id)){
      case(null){
        return {
          code=404;
          msg="user not exist";
          data={id=Principal.toText(caller);avatar="";desc="";name="";pid=Principal.toText(caller);ctime=0};
        };
      };
      case(?pid){
        switch(Map.get(userMap, thash, pid)){
          case(null){
            return {
              code=404;
              msg="user not exist";
              data={id=Principal.toText(caller);avatar="";desc="";name="";pid=Principal.toText(caller);ctime=0};
            };
          };
          case(?user){
            return {
              code=200;
              msg="";
              data=user;
            };
          };
        };
      };
    };
  };

  // 用户principalid查询
  public query({caller}) func queryByPid(pid: Text): async(Resp<User>){
    switch(Map.get(userMap, thash, pid)){
      case(null){
        return {
          code=404;
          msg="user not exist";
          data={id=Principal.toText(caller);avatar="";desc="";name="";pid=Principal.toText(caller);ctime=0};
        };
      };
      case(?user){
        return {
          code=200;
          msg="";
          data=user;
        };
      };
    };
  };

  public func wallet_receive(): async() {
    let amout = Cycles.available();
    let accepted = Cycles.accept(amout);
  };

}
