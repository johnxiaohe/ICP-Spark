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

    public type Spark = actor {
        userUpdateCall : shared (id: Principal, name: Text, avatar: Text, desc: Text) -> async ();
    };
}