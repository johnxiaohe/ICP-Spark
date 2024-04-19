import Text "mo:base/Text";
import List "mo:base/List";
import Time "mo:base/Time";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";

import Map "mo:map/Map";
import { phash } "mo:map/Map";

import types "types";
import userspace "user";

actor{

  type Resp<T> = types.Resp<T>;
  type User = types.User;
  type UserActor = userspace.UserSpace;

  // user pid --- user info map
  let userMap = Map.new<Principal,User>();
  // user id --- user pid
  let userIdMap = Map.new<Principal,Principal>();
  // 用户注册先后排名
  private stable var _ranking : List.List<Principal> = List.nil();

  private stable var _cyclesPerUser: Nat = 200_000_000_000; // 0.2t cycles for each token canister

  system func preupgrade() {};

  system func postupgrade() {};

  // 录入个人信息
  public shared({caller}) func initUserInfo(name: Text, avatar: Text, desc: Text): async Resp<User>{
    let contains = Map.has(userMap, phash, caller);
    if (contains){
      return {
          code=400;
          msg="user exist";
          data={id=caller;avatar="";desc="";name="";pid=caller;ctime=0};
        };
    };
    Cycles.add<system>(_cyclesPerUser);
    let ctime = Time.now();
    Debug.print(debug_show(ctime));
    let userActor = await userspace.UserSpace(name, caller, avatar, desc, ctime);
    let userActorId = Principal.fromActor(userActor);
    _ranking := List.push(caller, _ranking);
    let user:User = {
      id=userActorId;
      pid=caller;
      name=name;
      avatar=avatar;
      desc=desc;
      ctime=ctime;
    };
    Map.set(userMap, phash, caller, user);
    Map.set(userIdMap, phash, userActorId,caller);
    return {
      code=200;
      msg="user exist";
      data=user;
    };
  };

  // user canister update callback
  public shared({caller}) func userUpdateCall(owner: Principal, name: Text, avatar: Text, desc: Text): async(){
    var user = Map.get(userMap, phash, owner);
    switch(user){
      case(null){
        return
      };
      case(?user){
        // only update user canister by self
        if (Principal.equal(caller, user.id)){
          let nUser:User = {
            id=caller;
            pid=user.pid;
            name=name;
            avatar=avatar;
            desc=desc;
            ctime=user.ctime;
          };
          Map.set(userMap, phash, user.pid, nUser);
        };
      };
    };
  };

  // 查询个人基础信息
  public shared({caller}) func queryUserInfo(): async Resp<User> {
    switch(Map.get(userMap, phash, caller)){
      case(null){
        return {
          code=404;
          msg="user not registed";
          data={id=caller;avatar="";desc="";name="";pid=caller;ctime=0};
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
  public shared func queryByName(keyword: Text): async(Resp<[User]>){
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
  public shared({caller}) func queryById(id: Principal): async(Resp<User>){
    switch(Map.get(userIdMap, phash, id)){
      case(null){
        return {
          code=404;
          msg="user not exist";
          data={id=caller;avatar="";desc="";name="";pid=caller;ctime=0};
        };
      };
      case(?pid){
        switch(Map.get(userMap, phash, pid)){
          case(null){
            return {
              code=404;
              msg="user not exist";
              data={id=caller;avatar="";desc="";name="";pid=caller;ctime=0};
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
  public shared({caller}) func queryByPid(pid: Principal): async(Resp<User>){
    switch(Map.get(userMap, phash, pid)){
      case(null){
        return {
          code=404;
          msg="user not exist";
          data={id=caller;avatar="";desc="";name="";pid=caller;ctime=0};
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
}
