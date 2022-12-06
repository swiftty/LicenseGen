import Foundation
import Logging

public protocol ProxyRequest {
    associatedtype Response

    func send(using io: any ProcessIO) async throws -> Response
}
