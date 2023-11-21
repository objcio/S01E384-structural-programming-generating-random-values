//

import Foundation
import SwiftUI

public protocol Edit: Representation {
    associatedtype E: View

    @ViewBuilder
    func edit(_ binding: Binding<Value>) -> E
}

extension Struct: Edit where Properties: Edit {
    public func edit(_ binding: Binding<Value>) -> some View {
        properties.edit(binding)
    }
}

extension Empty: Edit {
    public func edit(_ binding: Binding<Value>) -> some View {
        EmptyView()
    }
}

extension List: Edit where Head: Edit, Tail: Edit {
    public func edit(_ binding: Binding<Value>) -> some View {
        head.edit(binding.0)
        tail.edit(binding.1)
    }
}

extension Property: Edit where Value: EditPrimitive {
    public func edit(_ binding: Binding<Value>) -> some View {
        Value.edit(title: .init(name), binding)
    }
}

public protocol EditPrimitive {
    associatedtype E: View

    static func edit(title: LocalizedStringKey, _ binding: Binding<Self>) -> E
}

extension String: EditPrimitive {
    public static func edit(title: LocalizedStringKey, _ binding: Binding<String>) -> some View {
        TextField(title, text: binding)
    }
}

extension Bool: EditPrimitive {
    public static func edit(title: LocalizedStringKey, _ binding: Binding<Bool>) -> some View {
        Toggle(title, isOn: binding)
    }
}

extension Date: EditPrimitive {
    public static func edit(title: LocalizedStringKey, _ binding: Binding<Date>) -> some View {
        DatePicker(title, selection: binding)
    }
}

extension Structural {
    fileprivate var structure: Structure.Value {
        get { to }
        set { self = .from(newValue) }
    }
}

extension Structural where Structure: Edit {
    public static func edit(_ binding: Binding<Self>) -> some View {
        structure.edit(binding.structure)
    }
}
