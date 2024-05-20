import IcWebSocketCdk "mo:ic-websocket-cdk";
import IcWebSocketCdkState "mo:ic-websocket-cdk/State";
import IcWebSocketCdkTypes "mo:ic-websocket-cdk/Types";

// open 和 close 接口都是仅有一个client_principal的参数，所以需要建立双向绑定关系
// user_principal : cid-index
// cid-index : user_principals
actor {

    // user edit group cache : cid-index : users
    private 

    // sys err logs

    // cid-index : content

    type Partner = {
        name : Text;
        pid : Text;
        uid : Text;
    };

    type PartnersMsg = {
        partners : [Partner];
    };

    type ClientEditMeta = {
        cid : Text;
        index : Text;
    };

    // 开启链接后消息类型
    type AppMessage = {
        // 初始化参与者、新加入的参与者、退出的参与者
        // 加入之前需要和workspace确认成员权限
        #InitPartners : partners;
        #JoinPartner : Partner;
        #LeavePartner : Text; // pid

        // 全量消息推送、更新步骤推送
        #FullContent : Text;
        #UpdateStep : Text;

        // 客户端主动推送
        #Join: ClientEditMeta;
        #Leave: ClientEditMeta;
    };

    // server send msg to client
    public func send_app_message(client_principal : IcWebSocketCdk.ClientPrincipal, msg : AppMessage) : async () {
        await IcWebSocketCdk.send(ws_state, client_principal, to_candid (msg))
    };

    // cached client conn info and collection user edit room
    public func on_open(args : IcWebSocketCdk.OnOpenCallbackArgs) : async () {
        connected_clients.add(args.client_principal);
    };

    // receive client msg , switch msg type and send to other partners
    public func on_message(args : IcWebSocketCdk.OnMessageCallbackArgs) : async () {
        let clientmsg : ?AppMessage = from_candid (args.message);
    };

    // remove from partner collection , and send new partners to other partners
    public func on_close(args : IcWebSocketCdk.OnCloseCallbackArgs) : async () {
        
    };

    let params = IcWebSocketCdkTypes.WsInitParams(null, null);
    let ws_state = IcWebSocketCdkState.IcWebSocketState(params);
    let handlers = IcWebSocketCdkTypes.WsHandlers(
        ?on_open,
        ?on_message,
        ?on_close,
    );
    let ws = IcWebSocketCdk.IcWebSocket(ws_state, params, handlers);

    // websocket gateway api, called by websocket . and cdk call on open / on message  / on close local function 
    public shared ({ caller }) func ws_open(args : IcWebSocketCdk.CanisterWsOpenArguments) : async IcWebSocketCdk.CanisterWsOpenResult {
        await ws.ws_open(caller, args);
    };

    // method called by the Ws Gateway when closing the IcWebSocket connection
    public shared ({ caller }) func ws_close(args : IcWebSocketCdk.CanisterWsCloseArguments) : async IcWebSocketCdk.CanisterWsCloseResult {
        await ws.ws_close(caller, args);
    };

    // method called by the frontend SDK to send a message to the canister
    public shared ({ caller }) func ws_message(args : IcWebSocketCdk.CanisterWsMessageArguments, msg_type : ?AppMessage) : async IcWebSocketCdk.CanisterWsMessageResult {
        await ws.ws_message(caller, args, msg_type);
    };

    // method called by the WS Gateway to get messages for all the clients it serves
    public shared query ({ caller }) func ws_get_messages(args : IcWebSocketCdk.CanisterWsGetMessagesArguments) : async IcWebSocketCdk.CanisterWsGetMessagesResult {
        ws.ws_get_messages(caller, args);
    };


}