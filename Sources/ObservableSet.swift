//
//  ObservableSet.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-12.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

public typealias SetUpdate<Element: Hashable> = Update<SetChange<Element>>
public typealias SetUpdateSource<Element: Hashable> = AnySource<SetUpdate<Element>>

public protocol ObservableSetType: ObservableType {
    associatedtype Element: Hashable
    typealias Base = Set<Element>

    var isBuffered: Bool { get }
    var count: Int { get }
    var value: Set<Element> { get }
    func contains(_ member: Element) -> Bool
    func isSubset(of other: Set<Element>) -> Bool
    func isSuperset(of other: Set<Element>) -> Bool

    var updates: SetUpdateSource<Element> { get }
    var observableCount: AnyObservableValue<Int> { get }
    var anyObservable: AnyObservableValue<Base> { get }
    var anyObservableSet: AnyObservableSet<Element> { get }
}

extension ObservableSetType {
    public var isBuffered: Bool { return false }
    public var count: Int { return value.count }
    public func contains(_ member: Element) -> Bool { return value.contains(member) }
    public func isSubset(of other: Set<Element>) -> Bool { return value.isSubset(of: other) }
    public func isSuperset(of other: Set<Element>) -> Bool { return value.isSuperset(of: other) }

    public var isEmpty: Bool { return count == 0 }

    internal var valueUpdates: ValueUpdateSource<Set<Element>> {
        var value = self.value
        return self.updates.map { event in
            event.map { change in
                let old = value
                value.apply(change)
                return ValueChange(from: old, to: value)
            }
        }.buffered()
    }

    internal var countUpdates: ValueUpdateSource<Int> {
        var count = self.count
        return self.updates.map { update in
            update.map { change in
                let old = count
                count += numericCast(change.inserted.count - change.removed.count)
                return .init(from: old, to: count)
            }
        }.buffered()
    }

    public var observableCount: AnyObservableValue<Int> {
        return AnyObservableValue(getter: { self.count }, updates: { self.countUpdates })
    }

    public var anyObservable: AnyObservableValue<Base> {
        return AnyObservableValue(getter: { self.value }, updates: { self.valueUpdates })
    }

    public var anyObservableSet: AnyObservableSet<Element> {
        return AnyObservableSet(box: ObservableSetBox(self))
    }
}

public struct AnyObservableSet<Element: Hashable>: ObservableSetType {
    public typealias Base = Set<Element>
    public typealias Change = SetChange<Element>

    let box: _AbstractObservableSet<Element>

    init(box: _AbstractObservableSet<Element>) {
        self.box = box
    }

    public var isBuffered: Bool { return box.isBuffered }
    public var count: Int { return box.count }
    public var value: Set<Element> { return box.value }
    public func contains(_ member: Element) -> Bool { return box.contains(member) }
    public func isSubset(of other: Set<Element>) -> Bool { return box.isSubset(of: other) }
    public func isSuperset(of other: Set<Element>) -> Bool { return box.isSuperset(of: other) }

    public var updates: SetUpdateSource<Element> { return box.updates }
    public var observableCount: AnyObservableValue<Int> { return box.observableCount }
    public var anyObservable: AnyObservableValue<Set<Element>> { return box.anyObservable }
    public var anyObservableSet: AnyObservableSet<Element> { return self }
}

open class _AbstractObservableSet<Element: Hashable>: ObservableSetType {
    open var value: Set<Element> { abstract() }
    open var updates: SetUpdateSource<Element> { abstract() }

    open var isBuffered: Bool { return false }
    open var count: Int { return value.count }
    open func contains(_ member: Element) -> Bool { return value.contains(member) }
    open func isSubset(of other: Set<Element>) -> Bool { return value.isSubset(of: other) }
    open func isSuperset(of other: Set<Element>) -> Bool { return value.isSuperset(of: other) }

    open var observableCount: AnyObservableValue<Int> {
        return AnyObservableValue(getter: { self.count }, updates: { self.countUpdates })
    }

    open var anyObservable: AnyObservableValue<Set<Element>> {
        return AnyObservableValue(getter: { self.value }, updates: { self.valueUpdates })
    }

    public final var anyObservableSet: AnyObservableSet<Element> {
        return AnyObservableSet(box: self)
    }
}

open class _BaseObservableSet<Element: Hashable>: _AbstractObservableSet<Element>, Signaler {
    private var state = TransactionState<SetChange<Element>>()

    public final override var updates: SetUpdateSource<Element> {
        return state.source(retaining: self)
    }

    final var isConnected: Bool {
        return state.isConnected
    }

    final func beginTransaction() {
        state.begin()
    }

    final func endTransaction() {
        state.end()
    }

    final func sendChange(_ change: SetChange<Element>) {
        state.send(change)
    }

    func activate() {
        // Do nothing
    }

    func deactivate() {
        // Do nothing
    }
}

class ObservableSetBox<Contents: ObservableSetType>: _AbstractObservableSet<Contents.Element> {
    typealias Element = Contents.Element

    let contents: Contents

    init(_ contents: Contents) {
        self.contents = contents
    }

    override var isBuffered: Bool { return contents.isBuffered }
    override var count: Int { return contents.count }
    override var value: Set<Element> { return contents.value }
    override func contains(_ member: Element) -> Bool { return contents.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return contents.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return contents.isSuperset(of: other) }

    override var updates: SetUpdateSource<Element> { return contents.updates }
    override var observableCount: AnyObservableValue<Int> { return contents.observableCount }
    override var anyObservable: AnyObservableValue<Set<Element>> { return contents.anyObservable }
}

class ObservableConstantSet<Element: Hashable>: _AbstractObservableSet<Element> {
    let contents: Set<Element>

    init(_ contents: Set<Element>) {
        self.contents = contents
    }

    override var isBuffered: Bool { return true }
    override var count: Int { return contents.count }
    override var value: Set<Element> { return contents }
    override func contains(_ member: Element) -> Bool { return contents.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return contents.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return contents.isSuperset(of: other) }

    override var updates: SetUpdateSource<Element> { return AnySource.empty() }
    override var observableCount: AnyObservableValue<Int> { return AnyObservableValue.constant(contents.count) }
    override var anyObservable: AnyObservableValue<Set<Element>> { return AnyObservableValue.constant(contents) }
}

extension ObservableSetType {
    public static func constant(_ value: Set<Element>) -> AnyObservableSet<Element> {
        return ObservableConstantSet(value).anyObservableSet
    }

    public static func emptyConstant() -> AnyObservableSet<Element> {
        return constant([])
    }
}
