@preconcurrency import XPC

public actor XPCServiceListener
{
    enum Error: Swift.Error {
        case previousInstanceExists
    }
    
    nonisolated(unsafe) static var shared: XPCServiceListener?

    let actorSystem: XPCDistributedActorSystem
    var lastConnection: XPCConnection? {
        didSet {
            actorSystem.setConnection(lastConnection)
        }
    }
    
    public init(actorSystem: XPCDistributedActorSystem) throws
    {
        guard Self.shared == nil else {
            throw Error.previousInstanceExists
        }
        self.actorSystem = actorSystem
        Self.shared = self
    }
    
    public nonisolated func run() -> Never
    {
        xpc_main { connection in
            guard let listener = XPCServiceListener.shared else { return }
            Task {
                let connection = XPCConnection(incomingConnection: connection, actorSystem: listener.actorSystem, codeSigningRequirement: listener.actorSystem.codeSigningRequirement)
                await listener.setConnection(connection)
            }
        }
    }
    
    func setConnection(_ connection: XPCConnection) async
    {
        if let lastConnection {
            await lastConnection.close()
        }
        self.lastConnection = connection
    }
}
