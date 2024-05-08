import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Principal "mo:base/Principal";

import AccountId "AccountId";

module Util {

    public func isCanister(p : Principal) : Bool {
        let principal_text = Principal.toText(p);
        // Canister principals have 27 characters
        Text.size(principal_text) == 27
        and
        // Canister principals end with "-cai"
        Text.endsWith(principal_text, #text "-cai");
    };

    public func getSubAccount(mainCid: Principal, userCid: Principal): Text{
        let subaccount = principalToSubAccount(userCid);
        let account = toHex(AccountId.fromPrincipal(mainCid, ?subaccount));
        return account;
    };

    public func principalToSubAccount(id: Principal) : [Nat8] {
        let p = Blob.toArray(Principal.toBlob(id));
        Array.tabulate(32, func(i : Nat) : Nat8 {
        if (i >= p.size() + 1) 0
        else if (i == 0) (Nat8.fromNat(p.size()))
        else (p[i - 1])
        });
    };

    let hexChars = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"];
    public func toHex(arr: [Nat8]): Text {
        Text.join("", Iter.map<Nat8, Text>(Iter.fromArray(arr), func (x: Nat8) : Text {
        let a = Nat8.toNat(x / 16);
        let b = Nat8.toNat(x % 16);
        hexChars[a] # hexChars[b]
        }))
    };

}