// NetworkMonitor.swift
// meeting-iOS
//
// Observes network reachability using the modern Network framework.

import Foundation
import Network
import Combine

// MARK: - Protocol

protocol NetworkMonitorProtocol: AnyObject {
    var isConnected: Bool { get }
    var connectionType: NetworkMonitor.ConnectionType { get }
}

// MARK: - Implementation

final class NetworkMonitor: ObservableObject, NetworkMonitorProtocol {

    // MARK: - Types

    enum ConnectionType {
        case wifi, cellular, ethernet, unknown, none
    }

    // MARK: - Singleton

    static let shared = NetworkMonitor()

    // MARK: - Published

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    // MARK: - Private

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "io.median.networkmonitor", qos: .utility)

    // MARK: - Init

    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                self?.connectionType = Self.connectionType(from: path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Helpers

    private static func connectionType(from path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else { return .none }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        return .unknown
    }
}
