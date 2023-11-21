//

import Foundation

public protocol RandomValue: Representation {
    static func random() -> Value
}

public protocol RandomPrimitive {
    static func random() -> Self
}

extension List: RandomValue where Head: RandomValue, Tail: RandomValue {
    public static func random() -> Value {
        (Head.random(), Tail.random())
    }
}

extension Struct: RandomValue where Properties: RandomValue {
    public static func random() -> Value {
        Properties.random()
    }
}

extension Nothing: RandomValue {
    public static func random() -> Never {
        fatalError()
    }
}

extension Empty: RandomValue {
    public static func random() -> () {
    }
}

extension Property: RandomValue where Value: RandomPrimitive {
    public static func random() -> Value {
        Value.random()
    }
}

extension Structural where Structure: RandomValue {
    public static func random() -> Self {
        from(Structure.random())
    }
}

extension String: RandomPrimitive {
    public static func random() -> String {
        let length = Int.random(in: 0..<20)
        return String((0..<length).map { _ in
            "abcdefgh".randomElement()!
        })
    }
}

extension Bool: RandomPrimitive { }

extension Date: RandomPrimitive {
    public static func random() -> Date {
        Date(timeIntervalSince1970: Double.random(in: 0..<Date.now.timeIntervalSince1970))
    }
}
