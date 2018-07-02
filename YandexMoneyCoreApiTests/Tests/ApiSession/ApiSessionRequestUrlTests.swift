/* The MIT License
 *
 * Copyright (c) 2018 NBCO Yandex.Money LLC
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
import XCTest
@testable import YandexMoneyCoreApi

class ApiSessionRequestUrlCommonTests: XCTestCase {

    fileprivate typealias Data = (
        urlInfo: URLInfo,
        expected: String
    )

    private func data(for strings: [String]) -> [Data] {
        let urls = strings.flatMap(URL.init)
        if strings.count != urls.count {
            assertionFailure("Can't parse some urls")
        }
        return zip(urls, strings)
            .map { (.url($0), $1) }
    }

    private lazy var data: [Data] = {
        return [
            (.components(host: "http://ya.ru", path: ""), "http://ya.ru"),
            (.components(host: "https://ya.ru", path: ""), "https://ya.ru"),
            (.components(host: "//ya.ru", path: ""), "https://ya.ru"),
            (.components(host: "//ya.ru", path: "/api"), "https://ya.ru/api"),
            (.components(host: "//ya.ru", path: "/api/v1"), "https://ya.ru/api/v1"),
            ] +
            self.data(for: [
                "https://ya.ru",
                "https://ya.ru/api/v1",
                "https://ya.ru/api/v1?p1=123&p2=qwe",
                ])
    }()

    func testApiMethodUrlInfo() {
        data.forEach(test)
    }

    func testHostForApiMethodWithKnownKey() {
        let hostProvider = MockHostProvider()
        let method = MockApiMethod()
        XCTCatch {
            let urlInfo = try method.urlInfo(from: hostProvider)
            guard case .components(host: "mock-host", path: "") = urlInfo else {
                XCTFail("Bad method host for valid method key")
                return
            }
        }
    }

    func testHostForApiMethodWithBadKey() {
        let hostProvider = MockHostProvider()
        let method = MockApiMethodWithBadKey()
        do {
            _ = try method.urlInfo(from: hostProvider)
            XCTFail("Getting urlInfo for not known key must throws errror")
        } catch HostProviderError.unknownKey("method-bad-key") {
            return
        } catch {
            XCTFail("Bad error type throws by getting urlInfo for api method for not known key")
        }
    }
}

private extension ApiSessionRequestUrlCommonTests {

    func test(urlInfo: URLInfo, expected: String) {
        let apiMethod = MockApiMethod(urlInfo: urlInfo)
        XCTAssertEqual(self.url(apiMethod: apiMethod), expected, "Bad url")
    }

    private func url<M: ApiMethod>(apiMethod: M) -> String? {
        let hostProvider = MockHostProvider()
        let session = ApiSession(hostProvider: hostProvider)
        let task = session.perform(apiMethod: apiMethod)
        switch task.requestData {
        case .right(let data):
            return data.request.url?.absoluteString
        case .left(let error):
            XCTFail("task error: \(error)")
            return nil
        }
    }

}

private class MockApiMethod: ApiMethod {

    fileprivate let _urlInfo: URLInfo?

    init(urlInfo: URLInfo) {
        _urlInfo = urlInfo
    }

    init() {
        _urlInfo = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encodeNil()
    }

    typealias Response = MockApiMethodResponse

    public var hostProviderKey: String {
        return "method-key"
    }

    var httpMethod: HTTPMethod {
        return .post
    }

    var parametersEncoding: ParametersEncoding {
        return QueryParametersEncoder()
    }

    func urlInfo(from hostProvider: HostProvider) throws -> URLInfo {
        if let _urlInfo = _urlInfo {
            return _urlInfo
        } else {
            let host = try hostProvider.host(for: hostProviderKey)
            return .components(host: host, path: "")
        }
    }
}

private class MockHostProvider: HostProvider {
    func host(for key: String) throws -> String {
        if key == "method-key" {
            return "mock-host"
        } else {
            throw HostProviderError.unknownKey(key)
        }
    }
}

final class MockApiMethodResponse: ApiResponse {
    class func makeResponse(response: HTTPURLResponse, data: Data) -> MockApiMethodResponse? {
        return nil
    }

    class func process(response: HTTPURLResponse?,
                       data: Data?,
                       error: Error?) -> Result<MockApiMethodResponse> {
        fatalError("process(response:data:error:) has not been implemented")
    }
}

private class MockApiMethodWithBadKey: MockApiMethod {
    public override var hostProviderKey: String {
        return "method-bad-key"
    }
}
