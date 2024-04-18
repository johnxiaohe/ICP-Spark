import Prim "mo:prim";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import List "mo:base/List";
import Error "mo:base/Error";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";

import Map "mo:map/Map";
import { phash } "mo:map/Map";

import configs "configs";
import Ledger "ledgers";
import types "types";
// Prim.rts_heap_size() -> Nat : wasm(canister) heap size at present

shared({caller}) actor class WorkSpace(
    _owner: Principal,
    _name: Text, 
    _avatar: Text, 
    _desc: Text, 
    _ctime: Time.Time,
) = this{
    
    // workspace 类型声明
    type Content = types.Content;
    type WorkSpaceInfo = types.WorkSpaceInfo;

    // 第三方类型声明
    type User = types.User;
    type UserDetail = types.UserDetail;
    
    // actor 类型声明
    type LedgerActor = Ledger.Self;
    type UserActor = types.UserActor;

    private stable var owner : Principal = _owner; // user canister id
    private stable var name : Text = _name;
    private stable var avatar : Text = _avatar;
    private stable var desc : Text = _desc;
    private stable var ctime : Time.Time = _ctime;

    // 成员管理数据
    // 预想还是由客户端直接调用workspace的接口，所以这里需要做用户pid和用户canisterid的映射
    private stable var memberMap = Map.new<Principal,Principal>();
    private stable var adminMap = Map.new<Principal,Principal>();

    // 内容管理数据
    private stable var _contentIndex : Nat = 0;
    private stable var contents: List.List<Content> = List.nil();

    // 操作日志数据
    private stable var _memberlog : List.List<Text> = List.nil();
    private stable var _fundslog : List.List<Text> = List.nil();
    private stable var _contentlog : List.List<Text> = List.nil();

    public shared func info(): async (WorkSpaceInfo){
        return {
            id = Principal.fromActor(this);
            owner = owner;
            name = name;
            avatar = avatar;
            desc = desc;
            ctime = ctime;
        };
    };

    public shared({caller}) func update(newName: Text, newAvatar: Text, newDesc: Text): async Result.Result<WorkSpaceInfo,Text>{
        return #err("");
    };

    public shared func cycles(): async Nat{
        return Cycles.balance();
    };

    public shared func subscribe(): async (){

    };

    public shared func unSubscribe(): async (){

    };

    public shared func quit(): async(){

    };

    public shared func transfer(): async(){

    };

    public shared({caller}) func addContent(name: Text){

    };

    public shared({caller}) func updateContent(name: Text, content: Text){

    };

    public shared({caller}) func delContent(id: Nat){

    };
}