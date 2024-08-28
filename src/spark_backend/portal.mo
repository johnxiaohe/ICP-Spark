import Nat "mo:base/Nat";
import Array "mo:base/Array";
import List "mo:base/List";
import Bool "mo:base/Bool";
import Text "mo:base/Text";
import Timer "mo:base/Timer";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Error "mo:base/Error";
import Principal "mo:base/Principal";

import Map "mo:map/Map";
import { thash } "mo:map/Map";

import types "types";
import Quicksort "quicksort";
import Utils "utils";


// 接收来自workspace 推送的内容，归类整理。
// 提供查询检索
// manage all public articals 
shared({caller}) actor class(){

    type ContentTrait = types.ContentTrait;
    type ViewResp = types.ViewResp;
    type Log = types.Log;

    type Resp<T> = types.Resp<T>;

    type WorkActor = types.WorkActor;

    public type View = {
        uuid : Text;
        view : Nat;
    };

    // 内容信息Map wid:id
    private stable var traits = Map.new<Text, ContentTrait>();
    // 缓存 workspace和推送过来的内容index，方便批量更新view，减少cycles损耗
    private stable var wids = Map.new<Text, List.List<Nat>>();
    // 最新推送 wid:id
    private stable var latests : List.List<Text> = List.nil();
    // 最热映射，拉取完毕后，排序替换到hots
    private stable var hots : [Text] = [];

    private var errlogs : List.List<Log> = List.nil();

    public shared({caller}) func version(): async (Text){
        return "v1.0.0"
    };

    public shared({caller}) func childCids(moduleName: Text): async ([Text]){
        return [];
    };

    public shared({caller}) func push(trait: ContentTrait): async(Bool){
        let callerWid = Principal.toText(caller);
        // Debug.print(debug_show(callerWid));
        if ( not Text.equal(callerWid, trait.wid)){
            return false;
        };
        if(not Utils.isCanister(caller)){
            return false;
        };

        let uuid = getUUid(trait.wid, trait.index);
        // Debug.print(debug_show(uuid));
        // 更新推送数据 以及根据tag等内容归类
        switch(Map.get(traits, thash, uuid)){
            case(null){
                latests := List.push(uuid, latests);
                // 初始化存储数据
                Map.set(traits, thash, uuid, trait);
                // 不存在的添加 wids映射
                addWids(trait.wid, trait.index);
            };
            case(?oldTrait){
                Map.set(traits, thash, uuid, trait);
            };
        };
        return true;
    };

    public shared({caller}) func delContent(id: Nat) : async(){
        let callerWid = Principal.toText(caller);

        let uuid = getUUid(callerWid, id);
        Map.delete(traits, thash, uuid);
        switch(Map.get(wids, thash, callerWid)){
            case(null){};
            case(?ids){
                // 删除空间 -- id映射
                let newIds = List.filter<Nat>(ids, func item { not Nat.equal(item, id)});
                Map.set(wids, thash, callerWid, newIds);
            };
        };

        latests := List.filter<Text>(latests, func item { not Text.equal(item, uuid) });
        // hots 不管，每五分钟重置hots数据
    };

    private func addWids(wid: Text, index: Nat) {
        var newIndexs : List.List<Nat> = List.nil();
        switch(Map.get(wids, thash, wid)){
            case(null){
                newIndexs := List.push(index, newIndexs);
                Map.set(wids, thash, wid, newIndexs);
            };
            case(?indexs){
                switch(List.find<Nat>(indexs, func x {Nat.equal(x,index)})) {
                    case(null) {
                        newIndexs := indexs;
                        newIndexs := List.push(index, newIndexs);
                        Map.set(wids, thash, wid, newIndexs);
                    };
                    case(?id) {};
                };
            };
        };
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

    // 热度排序 slice方法  前闭后开
    public shared func hot(offset: Nat, size: Nat): async(Resp<[ContentTrait]>){
        var from = offset;
        var to = offset + size;
        if (to > Array.size(hots)){
            to := Array.size(hots);
        };
        var result : List.List<ContentTrait> = List.nil();
        for (uuid in Array.slice<Text>(hots, from, to)){
            switch(Map.get(traits, thash, uuid)){
                case(null){};
                case(?trait){
                    result := List.push( trait, result);
                };
            };
        };
        result := List.reverse(result);
        return {
            code = 200;
            msg = "";
            data = List.toArray(result);
        };
    };

    // 最新排序
    public shared func latest(offset: Nat, size: Nat): async(Resp<[ContentTrait]>){
        var from = offset;
        var to = offset + size;
        if (to > List.size(latests)){
            to := List.size(latests);
        };
        var result : List.List<ContentTrait> = List.nil();
        let arr = List.toArray(latests);
        // 顺序正确，正序输出，但是便利后推送到List里相当于reverse 一次
        for (uuid in Array.slice<Text>(arr, from, to)){
            // Debug.print(debug_show(uuid));
            switch(Map.get(traits, thash, uuid)){
                case(null){
                    result := List.push( {index=0;wid="";name="not found";desc="no found";plate="";tag=[];view=0;like=0}, result);
                };
                case(?trait){
                    result := List.push( trait, result);
                };
            };
        };
        result := List.reverse(result);
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

    public shared func queryLogs (): async(Resp<[Log]>){
        return {
            code = 200;
            msg = "";
            data = List.toArray(errlogs);
        };
    };

    private func getUUid(wid: Text, index: Nat): Text{
        return wid # ":" # Nat.toText(index);
    };

    private func sortHots() {
        let traitArr : [(Text, ContentTrait)] = Map.toArray<Text, ContentTrait>(traits);
        let result : [(Text, ContentTrait)] = Quicksort.sortBy<(Text, ContentTrait)>(traitArr, func((k1, v1), (k2, v2)) { 
            if (Nat.less(v1.view, v2.view)){
                #greater;
            }else if (Nat.equal(v1.view, v2.view)){
                #equal;
            }else {
                #less;
            };
        });
        hots := Array.map<(Text,ContentTrait),Text>(result, func((key,value)) {key});
    };

    private func pullViews(): async (){
        for((wid, indexs) in Map.entries(wids)){
            try{
                let workActor : WorkActor = actor (wid);
                let views: [ViewResp] = await workActor.views(List.toArray(indexs));
                for (newView in Array.vals<ViewResp>(views)){
                    let uuid = getUUid(wid, newView.index);
                    switch(Map.get(traits, thash, uuid)) {
                        case(null) {  };
                        case(?trait) {
                            if (not Nat.equal(trait.view, newView.view)){
                                var newTrait = {
                                    wid = wid;

                                    index = trait.index;
                                    name = trait.name;
                                    desc = trait.desc;
                                    plate = trait.plate;
                                    tag = trait.tag;

                                    like = trait.like;
                                    view = newView.view;
                                };
                                Map.set(traits,thash, uuid, newTrait);
                            };
                         };
                    };
                };
            }catch (error : Error){
                let info = "pull view error : " # Error.message(error);
                errlogs := List.push({time=Time.now();info=info;opeater=wid}, errlogs);
            };
        };
        // Debug.print(debug_show(Time.now()));
    };

    // 定时拉取view 数据 并且排序 300S 一次
    private stable var processing : Bool = false;
    ignore Timer.recurringTimer<system>(#seconds (5) , func () : async(){
            if(processing){return};
            processing := true;
            await pullViews();
            sortHots();
            processing := false;
        });

}