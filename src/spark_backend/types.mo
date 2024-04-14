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
    }
}