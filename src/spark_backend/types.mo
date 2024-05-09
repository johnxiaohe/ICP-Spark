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
        id: Text; // user canister id
        pid: Text; // user principal id
        name: Text;
        avatar: Text;
        desc: Text;
        ctime: Time.Time;
    };

    public type UserDetail = {
        id: Text; // user canister id
        pid: Text; // user principal id
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
        wid: Text;
        wName: Text;
        index: Nat;
        name: Text;
    };

    public type MyWorkspace = {
        wid: Text;
        owner: Bool;
        start: Bool;
    };

    public type MyWorkspaceResp = {
        wid: Text;
        name: Text;
        desc: Text;
        owner: Bool;
        start: Bool;
    };

    public type RecentWork = {
        wid: Text;
        name: Text;
        owner: Bool;
        time: Time.Time;
    };

    public type RecentEdit = {
        wid: Text;
        wname: Text;
        index: Nat;
        cname: Text;
        etime: Time.Time;
    };

    // work api types -----------------------------------
    public type WorkSpaceInfo = {
        id: Text;
        super: Text;
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
        sort : Nat;
        utime: Time.Time;
        uid: Text;
        coAuthors: List.List<Text>;
    };

    public type SummaryResp = {
        id: Nat;
        pid: Nat;
        name: Text;
        sort : Nat;
    };

    public type ContentResp = {
        id: Nat;
        pid: Nat;
        name: Text;
        content: Text;
        utime: Time.Time;
        uAuthor: ?User;
        coAuthors: List.List<User>;
        viewCount: Nat;
    };

    public type Auth = {
        uid: Text;
        name: Text;
        avator: Text;
    };

    public type ShowModel = {
        #Public;
        #Subscribe;
        #Payment;
        #Private;
    };

    public type Log = {
        time: Time.Time;
        info: Text;
        opeater: Text;
    };

    public type FundsLog = {
        time: Time.Time;
        info: Text;
        opeater: Text;
        opType: Text;
        token: Text;
        balance: Nat;
    };

    public type ContentLog = {
        time : Time.Time;
        opeater : Text;
        opType : Text;
        index : Nat;
        name : Text;
    };

    public type EditorRanking = {
        pid: Text;
        count: Nat;
    };

    public type ViewRanking = {
        id: Nat;
        name : Text;
        count : Nat;
    };

    public type SpaceData = {
        income: Nat;
        outgiving: Nat;
        editcount: Nat;
        viewcount: Nat;
        membercount: Nat;
        subscribecount: Nat;
    };

    // portal models
    public type ContentTrait = {
        index : Nat;
        wid : Text;
        name : Text;
        plate : Text;
        desc : Text;
        tag : [Text];
        view: Nat;
        like: Nat;
    };

    public type ViewResp = {
        index: Nat;
        view: Nat;
    };

    // cyclesmanage
    public type UserPreSaveInfo = {
        uid: Text; // user canister id
        account: Text;
        cycles: Nat; // cycles
        icp: Nat;
        presaveLogs: List.List<Text>;
    };

    public type CanisterInfo = {
        name : Text;
        cid: Text;
    };

    public type Rule = {
        amount: Nat;
        threshold: Nat;
    };

    public type CanisterMetaData = {
        cid: Text;
        currentCycles: Nat;
        historyCycles: List.List<Nat>;
        rules: List.List<Rule>;
        topUpLogs: List.List<Text>;
    };

    // actors api
    public type SparkActor = actor {
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
        quitSubscribe: shared() -> async();
    };

    public type WorkActor = actor {
        info: shared() -> async(Resp<WorkSpaceInfo>);
        subscribe: shared() -> async(Resp<Bool>);
        unSubscribe: shared() -> async(Resp<Bool>);
        collectionCall: shared(index: Nat) -> async(Resp<Collection>);
        quit: shared() -> async(Bool);
        views: shared(indexs: [Nat]) -> async([ViewResp]);
    };

    public type PortalActor = actor {
        push: shared(ContentTrait) -> async();
    };

    public type CyclesManageActor = actor {
        preSaveInfo: shared() -> async (Resp<UserPreSaveInfo>);
    };
}