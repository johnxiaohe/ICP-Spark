import Nat "mo:base/Nat";
import Array "mo:base/Array";
import List "mo:base/List";
import Bool "mo:base/Bool";
import Text "mo:base/Text";
import Timer "mo:base/Timer";

import Map "mo:map/Map";
import { nhash;thash } "mo:map/Map";

import types "types";
import Quicksort "quicksort";


// 接收来自workspace 推送的内容，归类整理。
// 提供查询检索
// manage all public articals 
shared({caller}) actor class(){

    type ContentTrait = types.ContentTrait;

    type Resp<T> = types.Resp<T>;

    type WorkActor = types.WorkActor;

    public type View = {
        uuid : Text;
        view : Nat;
    };

    // 内容信息Map wid:id
    private stable var traits = Map.new<Text, ContentTrait>();
    // 最新推送 wid:id
    private stable var latests : List.List<Text> = List.nil();
    // 最热映射，拉取完毕后，排序替换到hots
    private stable var hots : [Text] = [];

    public shared func push(trait: ContentTrait): async(Bool){
        let uuid = getUUid(trait.wid, trait.index);
        // 更新推送数据 以及根据tag等内容归类
        switch(Map.get(traits, thash, uuid)){
            case(null){
                latests := List.push(uuid, latests);
                // 初始化存储数据
                Map.set(traits, thash, uuid, trait);
            };
            case(?oldTrait){
                Map.set(traits, thash, uuid, trait);
            };
        };
        return true;
    };

    public shared func getTrait(wid: Text, index: Nat): async(Resp<ContentTrait>) {
        let uuid = getUUid(wid, index);
        switch(Map.get(traits, thash, uuid)){
            case(null){
                return {
                    code =  404;
                    msg = "trait not found";
                    data = {index=0;wid="";name="";desc="";plate="";view=0;like=0;tag=[]};
                };
            };
            case(?trait){
                return {
                    code =  200;
                    msg = "";
                    data = trait;
                };
            };
        };
    };

    // 热度排序
    public shared func hot(size: Nat, offset: Nat): async(Resp<[ContentTrait]>){
        var from = offset;
        var to = Nat.sub(Nat.add(offset , size) , 1);
        var result : List.List<ContentTrait> = List.nil();
        for (uuid in Array.slice<Text>(hots, from, to)){
            switch(Map.get(traits, thash, uuid)){
                case(null){};
                case(?trait){
                    result := List.push( trait, result);
                };
            };
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    // 最新排序
    public shared func latest(size: Nat, offset: Nat): async(Resp<[ContentTrait]>){
        var from = offset;
        var to = Nat.sub(Nat.add(offset , size) , 1);
        var result : List.List<ContentTrait> = List.nil();
        for (uuid in Array.slice<Text>(List.toArray(latests), from, to)){
            switch(Map.get(traits, thash, uuid)){
                case(null){};
                case(?trait){
                    result := List.push( trait, result);
                };
            };
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    // 检索
    public shared func queryByName(keyword: Text): async(Resp<[ContentTrait]>){
        var result : List.List<ContentTrait> = List.nil();
        for(trait in Map.vals(traits)){
            if (Text.contains(trait.name, #text keyword)){
                result := List.push(trait, result);
            };
        };
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    private func getUUid(wid: Text, index: Nat): Text{
        return wid # ":" # Nat.toText(index);
    };

    private func sortHots() {
        let traitArr : [(Text, ContentTrait)] = Map.toArray<Text, ContentTrait>(traits);
        let result : [(Text, ContentTrait)] = Quicksort.sortBy<(Text, ContentTrait)>(traitArr, func((k1, v1), (k2, v2)) { 
            if (Nat.less(v1.view, v2.view)){
                #less;
            }else if (Nat.equal(v1.view, v2.view)){
                #equal;
            }else {
                #greater;
            };
        });
        hots := Array.map<(Text,ContentTrait),Text>(result, func((key,value)) {key});
    };

    private func pullViews(): async (){

    };

    ignore Timer.recurringTimer<system>(#seconds (10) , func () : async(){ await pullViews(); sortHots();});

}