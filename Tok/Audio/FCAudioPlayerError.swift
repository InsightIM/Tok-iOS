import Foundation

enum FCAudioPlayerError: _ObjectiveCBridgeableError {
    
    public var _domain: String {
        return FCAudioPlayerErrorDomain
    }
    
    public init?(_bridgedNSError error: NSError) {
        guard error.domain == FCAudioPlayerErrorDomain else {
            return nil
        }
        switch error.code {
        case Int(FCAudioPlayerErrorCode.newOutput.rawValue):
            self = .newOutput
        case Int(FCAudioPlayerErrorCode.allocateBuffers.rawValue):
            self = .allocateBuffers
        case Int(FCAudioPlayerErrorCode.addPropertyListener.rawValue):
            self = .addPropertyListener
        case Int(FCAudioPlayerErrorCode.stop.rawValue):
            self = .stop
        case Int(FCAudioPlayerErrorCode.cancelled.rawValue):
            self = .cancelled
        default:
            return nil
        }
    }
    
    case newOutput
    case allocateBuffers
    case addPropertyListener
    case stop
    case cancelled
    
}
