import Time "mo:base/Time";
import Text "mo:base/Text";
import Principal "mo:base/Principal";

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

    public type Spark = actor {
        userUpdateCall : shared (id: Principal, name: Text, avatar: Text, desc: Text) -> async ();
    };

    public type UserActor = actor {
        info : shared() -> async(User);
        detail : shared() -> async (UserDetail);
        addFans : shared () -> async ();
    };

    public type WorkActor = actor {
        info: shared() -> async(WorkSpaceInfo);
    }
}