public struct Units: Equatable, CustomStringConvertible {
    public var description: String{
        return self.getReadableUnit()
    }
    
    public let bytes: Int64
    
    public var kilobytes: Double {
        return (Double(bytes) / 1_024).rounded(.up)
    }
    
    public var megabytes: Double {
        return (kilobytes / 1_024).rounded(.up)
    }
    
    public var gigabytes: Double {
        return (megabytes / 1_024).rounded(.up)
    }
    
    public var terabytes: Double {
        return (gigabytes / 1_024).rounded(.up)
    }
    
    public init(bytes: Int64) {
        self.bytes = bytes
    }
    
    public init(kilobytes: Double){
        self.bytes = Int64((kilobytes * 1_024))
    }
    
    public init(megabytes: Double){
        self.bytes = Int64((megabytes * 1_024 * 1_024))
    }
    
    public init(gigabytes: Double){
        self.bytes = Int64((gigabytes * 1_024 * 1_024 * 1_024))
    }
    
    public init(terabytes: Double){
        self.bytes = Int64((terabytes * 1_024 * 1_024 * 1_024 * 1_024))
    }
    
    public func getReadableUnit() -> String {
        
        switch bytes {
        case 0..<1_024:
            return "\(bytes) B."
        case 1_024..<(1_024 * 1_024):
            return "\(String(format: "%.f", kilobytes)) KB"
        case 1_024..<(1_024 * 1_024 * 1_024):
            return "\(String(format: "%.f", megabytes)) MB"
        case 1_024..<(1_024 * 1_024 * 1_024 * 1_024):
            return "\(String(format: "%.f", gigabytes)) GB"
        case (1_024 * 1_024 * 1_024 * 1_024)...Int64.max:
            return "\(String(format: "%.f", terabytes)) TB"
        default:
            return "\(bytes) B."
        }
    }
    
}

