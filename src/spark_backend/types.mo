import Time "mo:base/Time";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import List "mo:base/List";

module{
    public type User = {
        id: Principal; // user principal id
        uid: Principal; // user canister principal id
        name: Text;
        avatar: Text;
        desc: Text;
        ctime: Time.Time;
    };

    public type WorkSpaceInfo = {
        id: Principal;
        name: Text;
        avatar: Text;
        desc: Text;
        ctime: Time.Time;
    };

    public type UserDetail = {
        id: Principal; // user principal id
        uid: Principal; // user canister principal id
        name: Text;
        avatar: Text;
        desc: Text;
        ctime: Time.Time;
        followSum: Nat;
        fansSum: Nat;
        collectionSum: Nat;
        subscribeSum: Nat;
    };

    // artical
    public type Collection = {
        wid: Principal;
        wName: Text;
        index: Nat;
        name: Text;
    };

    public type Content = {
        id: Nat;
        pid: Nat;
        name: Text;
        content: Text;
        utime: Time.Time;
        coAuthors: List.List<Principal>;
    };

    public type MyWorkspace = {
        wid: Principal;
        owner: Bool;
        start: Bool;
    };

    public type MyWorkspaceResp = {
        wid: Principal;
        name: Text;
        desc: Text;
        cycles: Nat;
        owner: Bool;
        start: Bool;
    };

    public type Spark = actor {
        userUpdateCall : shared (id: Principal, name: Text, avatar: Text, desc: Text) -> async ();
    };

    public type UserActor = actor {
        info : shared() -> async(User);
        detail : shared() -> async (UserDetail);
        addFans : shared () -> async ();
        delFans: shared() -> async();
    };

    public type WorkActor = actor {
        info: shared() -> async(WorkSpaceInfo);
        subscribe: shared() -> async();
        unSubscribe: shared() -> async();
        quit: shared() -> async();
    };
}