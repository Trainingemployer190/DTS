//
//  NetworkMonitor.swift
//  DTS App
//
//  Network reachability monitoring using NWPathMonitor
//

import Foundation
import Network
import Combine

/// Monitors network connectivity status
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        print("📡 Network: Connected via WiFi")
                        self?.connectionType = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        print("📡 Network: Connected via Cellular")
                        self?.connectionType = .cellular
                    } else {
                        print("📡 Network: Connected via other interface")
                    }
                } else {
                    print("📡 Network: Disconnected")
                    self?.connectionType = nil
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    /// Returns true if connected via WiFi
    var isWiFi: Bool {
        connectionType == .wifi
    }
    
    /// Returns true if connected via cellular
    var isCellular: Bool {
        connectionType == .cellular
    }
    
    /// Returns a user-friendly connection description
    var connectionDescription: String {
        if !isConnected {
            return "No Connection"
        }
        
        if isWiFi {
            return "WiFi"
        } else if isCellular {
            return "Cellular"
        } else {
            return "Connected"
        }
    }
}
