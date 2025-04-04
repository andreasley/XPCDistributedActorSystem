@preconcurrency import XPC

public actor XPCDaemonListener
{
    let actorSystem: XPCDistributedActorSystem
    var lastConnection: XPCConnection?
    private var listener: xpc_connection_t?
    
    public init(daemonServiceName: String, actorSystem: XPCDistributedActorSystem) throws
    {
        self.actorSystem = actorSystem
        let listener = xpc_connection_create_mach_service(daemonServiceName, nil, UInt64(XPC_CONNECTION_MACH_SERVICE_LISTENER))
        self.listener = listener

        xpc_connection_set_event_handler(listener) { event in
            if event === XPC_ERROR_CONNECTION_INVALID {
                print("XPCDaemonListener received XPC_ERROR_CONNECTION_INVALID")
                // TODO: Invalidate listener?
                return
            } else if event === XPC_ERROR_CONNECTION_INTERRUPTED {
                print("XPCDaemonListener received XPC_ERROR_CONNECTION_INTERRUPTED")
                return
            }
            
            let connection = XPCConnection(incomingConnection: event, actorSystem: actorSystem, codeSigningRequirement: actorSystem.codeSigningRequirement)
            Task {
                await self.setConnection(connection)
            }
        }
        xpc_connection_activate(listener)
    }
    
    func setConnection(_ connection: XPCConnection) async
    {
        if let lastConnection {
            await lastConnection.close()
        }
        self.lastConnection = connection
    }
}
