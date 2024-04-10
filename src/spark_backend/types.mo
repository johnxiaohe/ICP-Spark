import Time "mo:base/Time";
import Text "mo:base/Text";

module{
    public type User = {
        id: Text; // user principal id
        uid: Text; // user canister principal id
        name: Text;
        avatar: Text;
        desc: Text;
        ctime: Time.Time;
    }
}