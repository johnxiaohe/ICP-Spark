import List "mo:base/List";

// manage all public articals 
shared({caller}) actor class(){

    private stable var contents : List.List<Principal> = List.nil();

    // 
    public shared({caller}) func pushContent(): async(){

    };

    public shared({caller}) func index(): async(){

    };

    public shared({caller}) func queryByName(name: Text): async(){

    };

}