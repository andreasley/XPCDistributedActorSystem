import Foundation
@preconcurrency import XPC

final class XPCMessageWithObject: Sendable
{
    enum Error: Swift.Error {
        case failedToConvertData
        case failedToCreateMessageDictionary
    }

    let raw: xpc_object_t
    
    init<T>(from objectToSend: T, replyTo request: XPCMessageWithObject? = nil) throws where T: Encodable
    {
        let encodedObject = try Self.encoder.encode(objectToSend)
        
        let message = if let request {
            xpc_dictionary_create_reply(request.raw)
        } else {
            xpc_dictionary_create(nil, nil, 0)
        }
        
        guard let message else {
            throw Error.failedToCreateMessageDictionary
        }

        try encodedObject.withUnsafeBytes { pointer in
            guard let rawPointer = pointer.baseAddress else { throw Error.failedToConvertData }
            xpc_dictionary_set_data(message, "data", rawPointer, encodedObject.count)
        }
        
        raw = message
    }

    init(raw: xpc_object_t)
    {
        self.raw = raw
    }

    func extract<T>(_ type: T.Type) throws -> sending T where T: Decodable
    {
        let messageType = xpc_get_type(raw)
        
        guard messageType != XPC_TYPE_ERROR else {
            throw XPCError(error: raw)
        }
        
        guard messageType == XPC_TYPE_DICTIONARY else {
            print("Unexpected message type:", messageType, String(cString: xpc_type_get_name(messageType)))
            throw XPCError(.unexpectedMessageType)
        }
        
        var dataLength = 0
        
        guard let dataPointer: UnsafeRawPointer = xpc_dictionary_get_data(raw, "data", &dataLength) else {
            throw XPCError(.failedToGetDataFromXPCDictionary)
        }
        
        let data = Data(bytes: dataPointer, count: dataLength)
        
        nonisolated(unsafe) let object = try Self.decoder.decode(T.self, from: data)
        return object
    }
}

extension XPCMessageWithObject
{
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
}
