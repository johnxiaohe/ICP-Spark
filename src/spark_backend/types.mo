import Time "mo:base/Time";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import List "mo:base/List";
import Result "mo:base/Result";
import Bool "mo:base/Bool";

module{

    public type Resp<T> = {
        code: Nat;
        msg: Text;
        data: T;
    };

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
    public type WorkSpaceInfo = {
        id: Principal;
        super: Principal;
        name: Text;
        avatar: Text;
        desc: Text;
        ctime: Time.Time;
        model: ShowModel;
        price: Nat;
    };

    public type Content = {
        id: Nat;
        pid: Nat;
        name: Text;
        content: Text;
        utime: Time.Time;
        coAuthors: List.List<Principal>;
    };

    public type ShowModel = {
        #Public;
        #Subscribe;
        #Payment;
    };

    // actors api
    public type Spark = actor {
        userUpdateCall : shared (owner: Principal, name: Text, avatar: Text, desc: Text) -> async ();
    };

    public type UserActor = actor {
        info : shared() -> async(Resp<User>);
        detail : shared() -> async (UserDetail);
        addFans : shared () -> async (Bool);
        delFans: shared() -> async(Bool);
        reciveWns: shared() -> async (Bool);
        addWorkNs: shared() -> async(Bool);
        leaveWorkNs: shared() -> async(Bool);
    };

    public type WorkActor = actor {
        info: shared() -> async(WorkSpaceInfo);
        subscribe: shared() -> async(Bool);
        unSubscribe: shared() -> async(Bool);
        quit: shared() -> async(Bool);
        transfer: shared(target: Principal) -> async(Bool);
    };
}