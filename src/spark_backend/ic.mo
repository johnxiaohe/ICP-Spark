// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module {

  public type CanisterStatus = {
    status : { #stopped; #stopping; #running };
    memory_size : Nat;
    cycles : Nat;
    settings : CanisterSettings;
    module_hash : ?Blob;
  };
  public type CanisterSettings = {
    freezing_threshold : ?Nat;
    controllers : ?[Principal];
    memory_allocation : ?Nat;
    compute_allocation : ?Nat;
  };

  public type InstallMode = {
    #install;
    #reinstall;
    #upgrade;
  };

  public type InstallCodeParams = {
    mode: InstallMode;
    canister_id: Principal;
    wasm_module: Blob;
    arg: Blob;
  };
  public type UpdateSettingsParams = {
    canister_id: Principal;
    settings: CanisterSettings;
  };

  public type ICActor = actor {
      update_settings: shared(params: UpdateSettingsParams) -> async ();
      install_code: shared(params: InstallCodeParams) -> async ();
      canister_status: query(canister_id: Principal) -> async CanisterStatus;
      deposit_cycles : ({canister_id: Principal}) -> async ();
  };

}