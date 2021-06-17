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

import Foundation
import FunctionalSwift

/// Provides convenience methods to work with requests.
public class ApiSession {

    /// Overrides all behavior for NSURLSessionTaskDelegate method
    /// `URLSession:task:didReceiveChallenge:completionHandler:` and requires the caller to call the `completionHandler`
    public var taskDidReceiveChallengeWithCompletion: ((
        _ session: URLSession,
        _ challenge: URLAuthenticationChallenge,
        _ completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)? {
            set {
                urlSessionDelegate.taskDidReceiveChallengeWithCompletion = newValue
            }
            get {
                urlSessionDelegate.taskDidReceiveChallengeWithCompletion
            }
    }

    /// ApiSession delegate
    public private(set) weak var delegate: ApiSessionDelegate?

    // MARK: - Private properties

    private let session: URLSession
    private let hostProvider: HostProvider
    private let logger: TaskLogger?
    private let urlSessionDelegate = UrlSessionDelegate()
    private let urlEncoding = QueryParametersEncoder()
    private let jsonEncoding = JsonParametersEncoder()

    /// Creates instance of ApiSession class
    ///
    /// - Parameters:
    ///   - hostProvider: Host provider for all requests
    ///   - configuration: Instance of URLSessionConfiguration
    ///   - delegate: Delegate object
    ///   - logger: Logger for API request-response
    ///
    /// Returns: Instance of ApiSession class
    public init(
        hostProvider: HostProvider,
        configuration: URLSessionConfiguration = .default,
        delegate: ApiSessionDelegate? = nil,
        logger: Logger? = nil
    ) {
        self.hostProvider = hostProvider

        let configurationHeaders
            = (configuration.httpAdditionalHeaders as? [String: String]).map(Headers.init) ?? .mempty
        configuration.httpAdditionalHeaders
            = DefaultHeadersFactory().makeHeaders().mappend(configurationHeaders).value

        self.logger = logger.map {
            TaskLogger(
                logger: $0,
                additionalSessionHeaders: configuration.httpAdditionalHeaders as? [String: String]
            )
        }
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: urlSessionDelegate, delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    /// Performs API method
    ///
    /// - Parameters:
    ///   - apiMethod: Instance, which conforms protocol ApiMethod
    ///
    /// - Returns: Instance of Task class
    public func perform<M: ApiMethod>(apiMethod: M) -> Task<M.Response> {
        let url: URL
        do {
            url = try self.url(for: apiMethod)
        } catch let error {
            return Task(requestData: .left(error)).trace(with: logger)
        }

        let task: Task<M.Response>

        do {
            var request = URLRequest(url: url,
                                     cachePolicy: apiMethod.cachePolicy,
                                     method: apiMethod.httpMethod,
                                     headers: apiMethod.headers)
            let parametersEncoding = apiMethod.parametersEncoding
            try parametersEncoding.encode(apiMethod)
            try parametersEncoding.passParameters(to: &request)
            let requestData = RequestData(request: request)

            let dataTask = session.dataTask(
                with: request
            ) { [weak self] (data: Data?, response: URLResponse?, error: Error?) -> Void in
                guard let self = self else {
                    requestData.error = ApiSessionError.canceled
                    requestData.queue.isSuspended = false
                    return
                }
                if let headers = (response as? HTTPURLResponse)?.allHeaderFields as? [String: String] {
                    self.delegate?.apiSession(self, didReceiveResponseWith: Headers(headers))
                }
                requestData.data = data
                requestData.response = response
                requestData.error = error
                requestData.queue.isSuspended = false
            }

            requestData.task = dataTask
            dataTask.resume()

            task = Task(requestData: .right(requestData)).trace(with: logger)
        } catch {
            task = Task(requestData: .left(error)).trace(with: logger)
        }

        return task
    }

    /// Cancels all active tasks
    @available(iOS 9.0, *)
    public func cancelAllTasks() {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }

    /// Makes default HTTP headers.
    @available(*, deprecated, message: "Use DefaultHeadersFactory instead")
    public static let defaultHTTPHeaders: Headers = DefaultHeadersFactory().makeHeaders()
}

// MARK: - Private

private extension ApiSession {
    func url<M: ApiMethod>(for apiMethod: M) throws -> URL {
        switch try apiMethod.urlInfo(from: hostProvider) {
        case let .url(url):
            return url
        case let .components(host, path):
            return try url(forHost: host, andPath: path)
        }
    }

    private func url(forHost host: String, andPath path: String) throws -> URL {
        guard let components = URLComponents(string: host) else {
            throw ApiSessionError.illegalUrl(host)
        }
        var resultComponents = components
        if resultComponents.scheme?.isEmpty != false {
            resultComponents.scheme = Constants.defaultScheme
        }
        resultComponents.path = path
        guard let url = resultComponents.url else {
            throw ApiSessionError.illegalUrl(host + path)
        }
        return url
    }

    final class UrlSessionDelegate: NSObject, URLSessionDelegate {
        var taskDidReceiveChallengeWithCompletion: ((
            URLSession,
            URLAuthenticationChallenge,
            @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) -> Void)?

        func urlSession(
            _ session: URLSession,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            guard taskDidReceiveChallengeWithCompletion == nil else {
                taskDidReceiveChallengeWithCompletion?(session, challenge, completionHandler)
                return
            }
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - API request-response logger

private extension Task {
    @discardableResult func trace(with logger: TaskLogger?) -> Task {
        logger?.trace(task: self)
        return self
    }
}

// MARK: - Constants

private extension ApiSession {
    enum Constants {
        static let defaultScheme = "https"
    }
}
