import Nat "mo:base/Nat";
import Char "mo:base/Char";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Hash "mo:base/Hash";
import Array "mo:base/Array";
import Option "mo:base/Option";
import HashMap "mo:base/HashMap";
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

    public func getUserSubAccountAddress(mainCid: Principal, userCid: Principal): Text{
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

    public func fromHex(t : Text) : [Nat8] {
        var map = HashMap.HashMap<Nat, Nat8>(1, Nat.equal, Hash.hash);
        // '0': 48 -> 0; '9': 57 -> 9
        for (num in Iter.range(48, 57)) {
            map.put(num, Nat8.fromNat(num-48));
        };
        // 'a': 97 -> 10; 'f': 102 -> 15
        for (lowcase in Iter.range(97, 102)) {
            map.put(lowcase, Nat8.fromNat(lowcase-97+10));
        };
        // 'A': 65 -> 10; 'F': 70 -> 15
        for (uppercase in Iter.range(65, 70)) {
            map.put(uppercase, Nat8.fromNat(uppercase-65+10));
        };
        let p = Iter.toArray(Iter.map(Text.toIter(t), func (x: Char) : Nat { Nat32.toNat(Char.toNat32(x)) }));
        var res : [var Nat8] = [var];
        for (i in Iter.range(0, 31)) {
            let a = Option.unwrap(map.get(p[i*2]));
            let b = Option.unwrap(map.get(p[i*2 + 1]));
            let c = 16*a + b;
            res := Array.thaw(Array.append(Array.freeze(res), Array.make(c)));
        };
        let result = Array.freeze(res);
        return result;
    };

}