import Time "mo:base/Time";
// Prim.rts_memory_size() -> Nat : the maximum memory has been used
// Prim.rts_heap_size() -> Nat : wasm(canister) heap size at present

shared({caller}) actor class UserSpace(
    _owner: Principal,
    _name: Text, 
    _avatar: Text, 
    _desc: Text, 
    _ctime: Time.Time,
) = this{

    private stable var owner : Principal = _owner;
    private stable var name : Text = _name;
    private stable var avatar : Text = _avatar;
    private stable var desc : Text = _desc;
    private stable var ctime : Time.Time = _ctime;
    private stable var cyclesPerNamespace: Nat = 20_000_000_000; // 0.02t cycles for each token canister


}