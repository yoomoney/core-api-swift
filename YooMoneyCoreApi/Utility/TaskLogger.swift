/* The MIT License
 *
 * Copyright © 2020 NBCO YooMoney LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import struct Foundation.Data
import struct Foundation.Date
import Foundation.NSURLResponse

/// API requests and Response logger
class TaskLogger {

    private let logger: Logger
    private let additionalSessionHeaders: [String: String]?

    init(logger: Logger, additionalSessionHeaders: [String: String]?) {
        self.logger = logger
        self.additionalSessionHeaders = additionalSessionHeaders
    }

    func trace<R>(task: Task<R>) {
        task.response { request, response, data, error in
            var log: [LogEntity] = []
            if let request = request {
                log += [("request", self.log(from: request))]
            }
            if let response = response {
                log += [("response", self.log(from: response, body: data))]
            }
            if let error = error {
                log += [("error", error.localizedDescription)]
            }

            self.logger.log(message: self.string(from: [("\(Date())", log)]))
        }
    }
}

// MARK: - LogEntity

private extension TaskLogger {
    typealias LogEntity = (key: String, value: Any)
}

// MARK: - Parsing objects to Log

private extension TaskLogger {
    func log(from request: URLRequest) -> [LogEntity] {
        var requestLog: [LogEntity] = []

        if let url = request.url?.absoluteString {
            requestLog += [("url", url)]
        }
        if let method = request.httpMethod {
            requestLog += [("method", method)]
        }
        var headers = additionalSessionHeaders ?? [:]
        if let requestHeadres = request.allHTTPHeaderFields {
            headers.merge(requestHeadres) { $1 }
        }
        mockOAuthToken(in: &headers)
        requestLog += [("headers", log(from: headers))]
        if let bodyData = request.httpBody, let body = String(data: bodyData, encoding: .utf8) {
            if headers["Content-Type"]?.hasPrefix("application/x-www-form-urlencoded") ?? false {
                requestLog += [("body", log(fromUrlEncoded: body))]
            } else {
                requestLog += [("body", body)]
            }
        }
        return requestLog
    }

    func log(from response: HTTPURLResponse, body: Data?) -> [LogEntity] {
        var responseLog: [LogEntity] = []
        responseLog += [("status", [
            "\(response.statusCode) (",
            HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
            ")",
            ].joined()),
        ]
        if var headers = response.allHeaderFields as? [String: String] {
            mockOAuthToken(in: &headers)
            responseLog += [("headers", log(from: headers))]
        }
        if let body = body {
            responseLog += [("body", String(data: body, encoding: .utf8) ?? "\(body)")]
        }
        return responseLog
    }

    private func log(from dictionary: [String: Any]) -> [LogEntity] {
        return dictionary.map { ($0.0, $0.1) }
    }

    private func mockOAuthToken(in dictionary: inout [String: String]) {
        guard let token = dictionary["Authorization"] else { return }
        dictionary["Authorization"] = "<\(token.count) bytes>"
    }

    private func log(fromUrlEncoded string: String) -> [LogEntity] {
        var log: [LogEntity] = []
        string.removingPercentEncoding?.split(separator: "&").map { $0.split(separator: "=") }.forEach {
            switch $0.count {
            case 0: break
            case 1: log += [(String($0[0]), "")]
            case 2: log += [(String($0[0]), String($0[1]))]
            default: assertionFailure("Error while parsing url encoded string `\(string)` in `\($0)`")
            }
        }
        return log
    }
}

// MARK: - Converting Log to string

private extension TaskLogger {
    func string(from log: [LogEntity], level: Int = 0) -> String {
        return log.map {
            [
                indent(level),
                $0.key,
                ": ",
                string(fromEntityValue: $0.value, level: level),
            ].joined()
        }.joined(separator: ",\n")
    }

    private func string(fromEntityValue value: Any, level: Int) -> String {
        switch value {
        case let string as String:
            return ["\"", string, "\""].joined()

        case let log as [LogEntity]:
            return [
                "{\n",
                string(from: log, level: level + 1), "\n",
                indent(level), "}",
            ].joined()

        default:
            return "\(value)"
        }
    }

    private func indent(_ level: Int) -> String {
        return String(repeating: "  ", count: level)
    }
}

// MARK: - Custom string tools

private extension String {
    var removingZero: String {
        return replacingOccurrences(of: "\0", with: "")
    }
}
