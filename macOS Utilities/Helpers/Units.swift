public struct Units {
    
    public let bytes: Int64
    
    public var kilobytes: Double {
        return (Double(bytes) / 1_024).rounded()
    }
    
    public var megabytes: Double {
        return (kilobytes / 1_024).rounded()
    }
    
    public var gigabytes: Double {
        return (megabytes / 1_024).rounded()
    }
    
    public var terabytes: Double {
        return (gigabytes / 1_024).rounded()
    }
    
    public init(bytes: Int64) {
        self.bytes = bytes
    }
    
    public func getReadableUnit() -> String {
        
        switch bytes {
        case 0..<1_024:
            return "\(bytes) B."
        case 1_024..<(1_024 * 1_024):
            return "\(String(format: "%.f", kilobytes)) KB"
        case 1_024..<(1_024 * 1_024 * 1_024):
            return "\(String(format: "%.f", megabytes)) MB"
        case 1_024..<(1_024 * 1_024 * 1_024 * 1024):
            return "\(String(format: "%.f", gigabytes)) GB"
        case (1_024 * 1_024 * 1_024 * 1024)...Int64.max:
            return "\(String(format: "%.f", terabytes)) TB"
        default:
            return "\(bytes) B."
        }
    }
    
}

