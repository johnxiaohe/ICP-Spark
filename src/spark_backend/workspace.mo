import Time "mo:base/Time";
import List "mo:base/List";
import Error "mo:base/Error";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Prim "mo:prim";

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
    type User = types.User;
    type UserDetail = types.UserDetail;
    type LedgerActor = Ledger.Self;
    type UserActor = types.UserActor;

    private stable var owner : Principal = _owner;
    private stable var name : Text = _name;
    private stable var avatar : Text = _avatar;
    private stable var desc : Text = _desc;
    private stable var ctime : Time.Time = _ctime;
}