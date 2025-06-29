import Foundation
import Network

class MulticastServiceClient: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let serviceType = "_dunduAPP._tcp."
    private let serviceDomain = "local."
    private let serviceName = "dundu2Splendor"

    private var serviceBrowser: NetServiceBrowser?
    private var resolvingService: NetService?
    private var connection: NWConnection? // For sending UDP packets
    private var isConnectionReady = false

    private var listener: NWListener? // For listening for incoming UDP packets
    private let listeningPort: NWEndpoint.Port // Port for incoming UDP data

    // MARK: - Callbacks for Network Events

    /// Called when the NWConnection successfully establishes and is ready to send data.
    var onConnectionReady: (() -> Void)?

    /// Called when the NWConnection transitions to a failed state. Provides the error.
    var onConnectionFailed: ((NWError) -> Void)?

    /// Called when data sending fails. Provides the error.
    var onSendError: ((NWError) -> Void)?

    /// Called when the NetServiceBrowser finds a service.
    var onServiceFound: ((NetService) -> Void)?

    /// Called when the NetServiceBrowser removes a service.
    var onServiceRemoved: ((NetService) -> Void)?

    /// Called when the target NetService (matching `serviceName`) has successfully resolved its address.
    var onServiceResolved: ((NetService) -> Void)?

    /// Called when new UDP data is received on the listening port.
    var onDataReceived: ((Data, NWEndpoint) -> Void)? // Pass sender's endpoint for context

    /// NEW: Called when the listener is restarted after a failure.
    var onListenerRestarted: (() -> Void)?

    // MARK: - Initialization (Modified to accept listeningPort)

    // Default listening port 50000, but can be customized
    init(listeningPort: UInt16 = 50000) {
        self.listeningPort = NWEndpoint.Port(rawValue: listeningPort)!
        super.init()
        setupListener() // Setup listener immediately on initialization
    }

    // MARK: - Private Listener Methods

    private func setupListener() {
        do {
            listener = try NWListener(using: .udp, on: listeningPort)

            // Listener state updates
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[Listener] Listener ready on port \(self.listeningPort)")
                case .failed(let error):
                    print("[Listener] Listener failed: \(error.localizedDescription)")
                    self.listener?.cancel() // Cancel the failed listener
                    self.setupListener() // Attempt to set it up again
                    self.onListenerRestarted?() // NEW: Call the callback
                case .cancelled:
                    print("[Listener] Listener cancelled.")
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { connection in
                print("[Listener] New UDP inbound connection handler established.")
                connection.start(queue: .main)
                self.receiveIncomingUDPData(on: connection)
            }

            listener?.start(queue: .main)
        } catch {
            print("[Listener] Failed to create listener on port \(listeningPort): \(error.localizedDescription)")
            // Handle fatal listener setup error, e.g., port already in use
        }
    }

    private func receiveIncomingUDPData(on connection: NWConnection) {
        connection.receiveMessage { (content, contentContext, isComplete, error) in
            if let content = content, !content.isEmpty {
                print("[Listener] Received data: \(content.count) bytes from \(connection.currentPath?.remoteEndpoint?.debugDescription ?? "unknown")")
                self.onDataReceived?(content, connection.currentPath?.remoteEndpoint ?? NWEndpoint.hostPort(host: "unknown", port: 0))
            }

            if let error = error {
                print("[Listener] Receive error: \(error.localizedDescription)")
            }

            if connection.state == .ready && !isComplete {
                self.receiveIncomingUDPData(on: connection)
            }
        }
    }

    // MARK: - Public API (Updated stopSearching to also stop listener if desired)

    func startSearching() {
        print("[Search] Starting service search for \(serviceType)\(serviceDomain)")
        serviceBrowser = NetServiceBrowser()
        serviceBrowser?.delegate = self
        serviceBrowser?.searchForServices(ofType: serviceType, inDomain: serviceDomain)
    }

    func stopSearching() {
        print("[Search] Stopping service search")
        serviceBrowser?.stop()
        serviceBrowser = nil
    }

    func sendData(_ data: Data) {
        guard isConnectionReady else {
            print("[Send] Connection not ready. Data send aborted.")
            return
        }
        print("[Send] Sending data: \(data.count) bytes.")
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let networkError = error {
                print("[Send] Send failed: \(networkError.localizedDescription)")
                self.onSendError?(networkError)
                self.reconnect()
            } else {
                print("[Send] Data sent successfully.")
            }
        }))
    }

    // MARK: - Private Connection Methods

    private func setupConnection(host: String, port: UInt16) {
        print("[Connect] Setting up UDP connection to \(host):\(port)")

        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        connection = NWConnection(host: nwHost, port: nwPort, using: .udp)
        isConnectionReady = false

        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.isConnectionReady = true
                print("[Connect] Sending connection is ready.")
                self.onConnectionReady?() // Trigger callback
            case .setup:
                print("[Connect] Sending connection setup.")
            case .preparing:
                print("[Connect] Sending connection preparing.")
            case .waiting(let error):
                print("[Connect] Sending connection waiting: \(error.localizedDescription)")
            case .failed(let error):
                self.isConnectionReady = false
                print("[Connect] Sending connection failed: \(error.localizedDescription)")
                self.onConnectionFailed?(error) // Trigger callback with error
                self.reconnect()
            case .cancelled:
                self.isConnectionReady = false
                print("[Connect] Sending connection cancelled.")
            @unknown default:
                print("[Connect] Unknown sending connection state.")
            }
        }

        connection?.start(queue: .main)
    }

    private func reconnect() {
        print("[Reconnect] Cleaning up sending connection and restarting service search.")
        connection?.cancel()     // 1. Closes the existing UDP socket (cancels the NWConnection)
        connection = nil         // 2. Releases the old connection object
        resolvingService = nil   // 3. Resets service resolution state
        isConnectionReady = false // 4. Marks connection as not ready
        startSearching()         // 5. Goes back to the searching state
    }
    
    
    // MARK: - NetServiceBrowserDelegate

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("[Browser] Browser started searching.")
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("[Browser] Browser stopped searching.")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("[Browser] Found service: \(service.name)")
        self.onServiceFound?(service) // Trigger callback for any found service

        if service.name == serviceName {
            print("[Browser] Matching service found: \(service.name). Resolving...")
            stopSearching() // Stop searching once target found
            resolvingService = service
            service.delegate = self
            service.resolve(withTimeout: 5)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("[Browser] Service removed: \(service.name)")
        self.onServiceRemoved?(service) // Trigger callback for removed service

        if service.name == serviceName {
            print("[Browser] Target service removed. Reconnecting sending connection...")
            reconnect() // Trigger reconnection logic for sending
        }
    }

    // MARK: - NetServiceDelegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        print("[Resolve] Resolved service: \(sender.name)")
        self.onServiceResolved?(sender) // Trigger callback for resolved service

        guard let addresses = sender.addresses else {
            print("[Resolve] No addresses found.")
            return
        }

        for addressData in addresses {
            if let (host, port) = NWEndpoint.Host.portFromSockAddr(data: addressData) {
                print("[Resolve] Connecting sending connection to resolved host: \(host):\(port)")
                setupConnection(host: host, port: port)
                break // Connect to the first valid address
            } else {
                print("[Resolve] Skipping invalid address.")
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("[Resolve] Failed to resolve service: \(errorDict)")
        reconnect() // Trigger reconnection logic for sending
    }
}
