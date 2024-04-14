import Time "mo:base/Time";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Prim "mo:prim";

import configs "configs";
import Ledger "ledgers";

import types "types";
// Prim.rts_heap_size() -> Nat : wasm(canister) heap size at present

shared({caller}) actor class UserSpace(
    _owner: Principal,
    _name: Text, 
    _avatar: Text, 
    _desc: Text, 
    _ctime: Time.Time,
) = this{
    type User = types.User;
    type UserDetail = types.UserDetail;
    type LedgerActor = Ledger.Self;
    let spark : types.Spark = actor (configs.SPARK_CANISTER_ID);
    let icpLedger: LedgerActor = actor(configs.ICP_LEGDER_ID);

    private stable var owner : Principal = _owner;
    private stable var name : Text = _name;
    private stable var avatar : Text = _avatar;
    private stable var desc : Text = _desc;
    private stable var ctime : Time.Time = _ctime;
    private stable var cyclesPerNamespace: Nat = 20_000_000_000; // 0.02t cycles for each token canister

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
            id=owner;
            uid=Principal.fromActor(this);
            name=name;
            avatar=avatar;
            desc=desc;
            ctime=ctime;
          });
    };

    public shared({caller}) func detail(): async(UserDetail) {
        {
            id=owner;
            uid=Principal.fromActor(this);
            name=name;
            avatar=avatar;
            desc=desc;
            ctime=ctime;
            followSum=0;
            fansSum=0;
            collectionSum=0;
            subscribeSum=0;
        };
    };

    public query func canisterMemory() : async Nat {
        return Prim.rts_memory_size();
    };

    public query func cyclesBalance(): async Nat{
        Cycles.balance();
    };

    public shared func icpBalance(): async Nat{
        await icpLedger.icrc1_balance_of({owner=Principal.fromActor(this); subaccount=null});
    };

    public shared func withdrawals(amount: Nat, ): async {

    };

    public shared({caller}) follow(): async{

    };

    public query fans(): async{

    };

    public query follows(): async{

    };

    public shared({caller}) collection(): async{

    };

    public query collections(): async{

    };

    public shared({caller}) subscribe(): async{

    };

    public shared({caller}) subscribes(): async{

    };

}