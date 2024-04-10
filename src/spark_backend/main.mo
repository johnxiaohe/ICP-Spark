import Bool "mo:base/Bool";
import Text "mo:base/Text";
import List "mo:base/List";
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";
import types "types";
import utils "utils";

actor {

  type User = types.User;
  type Trie<K, V> = Trie.Trie<K, V>;
  type Key<K> = Trie.Key<K>;

  // user principal -- user info map
  private stable var userMap : Trie<Text, User> = Trie.empty();

  system func preupgrade() {};

  system func postupgrade() {};

  public shared({caller}) func initUserInfo(name: Text, avatar: Text, desc: Text): async(){
    
  };

  public shared({caller}) func queryUserInfo(): async() {

  };

  // user utils tool ---------------------------------------------------
  func userKey(t: Text) : Key<Text> { { hash = Text.hash t; key = t } };

  func getUser(id: Principal): ?User {
    Trie.get(userMap, userKey(Principal.toText(id)), Text.equal)
  };

  func putUser(user: User){
    userMap := Trie.put(userMap, userKey(user.id), Text.equal, user).0
  };

  func containUser(id: Principal) : Bool{
    switch(getUser id){
      case(null){
        return false;
      };
      case(?user){
        return true;
      };
    };
  };
}
