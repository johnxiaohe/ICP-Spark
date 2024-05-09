// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module {
  public type canister_id = Principal;
  public type canister_status = {
    status : { #stopped; #stopping; #running };
    memory_size : Nat;
    cycles : Nat;
    settings : definite_canister_settings;
    module_hash : ?Blob;
  };
  public type definite_canister_settings = {
    freezing_threshold : Nat;
    controllers : [Principal];
    memory_allocation : Nat;
    compute_allocation : Nat;
  };
  public type Self = actor {
    canister_status : shared {
        canister_id : canister_id;
      } -> async canister_status;
  }
}