import Time "mo:base/Time";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import List "mo:base/List";
import Result "mo:base/Result";

module{

    // user api types --------------------------------
    public type User = {
        id: Principal; // user canister id
        pid: Principal; // user principal id
        name: Text;
        avatar: Text;
        desc: Text;
        ctime: Time.Time;
    };

    public type UserDetail = {
        id: Principal; // user canister id
        pid: Principal; // user principal id
        name: Text;
        avatar: Text;
        desc: Text;
        ctime: Time.Time;
        followSum: Nat;
        fansSum: Nat;
        collectionSum: Nat;
        subscribeSum: Nat;
        showfollow: Bool;
        showfans: Bool;
        showcollection: Bool;
        showsubscribe: Bool;
    };

    // artical
    public type Collection = {
        wid: Principal;
        wName: Text;
        index: Nat;
        name: Text;
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
        owner: Bool;
        start: Bool;
    };

    public type WorkSpaceInfo = {
        id: Principal;
        owner: Principal;
        name: Text;
        avatar: Text;
        desc: Text;
        ctime: Time.Time;
    };

    public type RecentWork = {
        wid: Principal;
        name: Text;
        owner: Bool;
    };

    public type RecentEdit = {
        wid: Principal;
        wname: Text;
        cid: Nat;
        cname: Text;
        etime: Time.Time;
    };

    // work api types -----------------------------------
    public type Content = {
        id: Nat;
        pid: Nat;
        name: Text;
        content: Text;
        utime: Time.Time;
        coAuthors: List.List<Principal>;
    };

    // actors api
    public type Spark = actor {
        userUpdateCall : shared (owner: Principal, name: Text, avatar: Text, desc: Text) -> async ();
    };

    public type UserActor = actor {
        info : shared() -> async(User);
        detail : shared() -> async (UserDetail);
        addFans : shared () -> async ();
        delFans: shared() -> async();
        reciveWns: shared() -> async Result.Result<Bool, Text>;
        addWorkNs: shared() -> async(Bool);
        leaveWorkNs: shared() -> async();
    };

    public type WorkActor = actor {
        info: shared() -> async(WorkSpaceInfo);
        subscribe: shared() -> async();
        unSubscribe: shared() -> async();
        quit: shared() -> async();
        transfer: shared(target: Principal) -> async();
    };
}