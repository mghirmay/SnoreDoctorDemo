//
//  NWEndpoint+SockAddr.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 13.05.25.
//
import Foundation
import Network

extension NWEndpoint.Host {
    /// Extracts (host, port) tuple from sockaddr data (IPv4 or IPv6).
    static func portFromSockAddr(data: Data) -> (String, UInt16)? {
        data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> (String, UInt16)? in
            guard let sockaddrPtr = pointer.bindMemory(to: sockaddr.self).baseAddress else {
                return nil
            }

            switch Int32(sockaddrPtr.pointee.sa_family) {
            case AF_INET:
                var addr = sockaddr_in()
                memcpy(&addr, sockaddrPtr, MemoryLayout<sockaddr_in>.size)
                let ip = String(cString: inet_ntoa(addr.sin_addr))
                let port = UInt16(bigEndian: addr.sin_port)
                return (ip, port)

            case AF_INET6:
                var addr = sockaddr_in6()
                memcpy(&addr, sockaddrPtr, MemoryLayout<sockaddr_in6>.size)
                var ipBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                let ipCString = withUnsafePointer(to: &addr.sin6_addr) {
                    inet_ntop(AF_INET6, $0, &ipBuffer, socklen_t(INET6_ADDRSTRLEN))
                }
                guard let cString = ipCString else { return nil }
                let ip = String(cString: cString)
                let port = UInt16(bigEndian: addr.sin6_port)
                return (ip, port)

            default:
                return nil
            }
        }
    }
}
