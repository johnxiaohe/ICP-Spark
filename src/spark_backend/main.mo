import Text "mo:base/Text";
import List "mo:base/List";
import Time "mo:base/Time";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";

import Map "mo:map/Map";
import { phash } "mo:map/Map";

import types "types";
import UserCs "user";
import User "user";

shared({caller}) actor class(){

  type User = types.User;

  // user pid --- user info map
  let userMap = Map.new<Principal,User>();
  // user id --- user pid
  let userIdMap = Map.new<Principal,Principal>();
  // 用户注册先后排名
  private stable var _ranking : List.List<Principal> = List.nil();

  private stable var _cyclesPerUser: Nat = 200_000_000_000; // 0.2t cycles for each token canister

  system func preupgrade() {};

  system func postupgrade() {};

  public shared({caller}) func initUserInfo(name: Text, avatar: Text, desc: Text): async(){
    let contains = Map.has(userMap, phash, caller);
    if (contains){
      return;
    };

    Cycles.add<system>(_cyclesPerUser);
    let ctime = Time.now();
    let userActor = await UserCs.UserSpace(caller, name, avatar, desc,ctime);
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
  };

  // user canister update callback
  public shared({caller}) func userUpdateCall(id: Principal, name: Text, avatar: Text, desc: Text): async(){
    var user = Map.get(userMap, phash, caller);
    switch(user){
      case(null){
        return
      };
      case(?user){
        // only update user canister by self
        if (Principal.equal(caller, user.uid)){
          let nUser:User = {
            id=id;
            uid=caller;
            name=name;
            avatar=avatar;
            desc=desc;
            ctime=user.ctime;
          };
          Map.set(userMap, phash, id, nUser);
        };
      };
    };
  };

  public shared({caller}) func queryUserInfo(): async(?User) {
    Map.get(userMap, phash, caller);
  };

  public shared({caller}) func queryByName(keyword: Text): async([User]){
    let result : List.List<User> = List.nil();
    for (u in Map.vals(userMap)){
      let name = u.name;
      if (Text.contains(name, #text keyword)){
        result := List.push(u, result);
      };
    };
    List.toArray(result);
  };

  public shared({caller}) func queryById(id: Principal): async(?User){
    switch(Map.get(userIdMap, phash, id)){
      case(null){
        return null;
      };
      case(?pid){
        Map.get(userMap, phash, pid);
      };
    };
  };

  public shared({caller}) func queryByPid(pid: Principal): async(?User){
    Map.get(userMap, phash, pid);
  };
}
