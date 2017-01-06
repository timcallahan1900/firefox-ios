/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import GCDWebServers

class WebServer {
    static let WebServerSharedInstance = WebServer()

    class var sharedInstance: WebServer {
        return WebServerSharedInstance
    }

    let server: GCDWebServer = GCDWebServer()

    var base: String {
        return "http://localhost:\(server.port)"
    }

    /// The private credentials for accessing resources on this Web server.
    let credentials: NSURLCredential

    /// A random, transient token used for authenticating requests.
    /// Other apps are able to make requests to our local Web server,
    /// so this prevents them from accessing any resources.
    private let sessionToken = NSUUID().UUIDString

    init() {
        credentials = NSURLCredential(user: sessionToken, password: "", persistence: .ForSession)
    }

    func start() throws -> Bool {
        if !server.running {
            try server.startWithOptions([
                GCDWebServerOption_Port: 6571,
                GCDWebServerOption_BindToLocalhost: true,
                GCDWebServerOption_AutomaticallySuspendInBackground: true,
                GCDWebServerOption_AuthenticationMethod: GCDWebServerAuthenticationMethod_Basic,
                GCDWebServerOption_AuthenticationAccounts: [sessionToken: ""]
            ])
        }
        return server.running
    }

    /// Convenience method to register a dynamic handler. Will be mounted at $base/$module/$resource
    func registerHandlerForMethod(method: String, module: String, resource: String, handler: (request: GCDWebServerRequest!) -> GCDWebServerResponse!) {
        // Prevent serving content if the requested host isn't a whitelisted local host.
        let wrappedHandler = {(request: GCDWebServerRequest!) -> GCDWebServerResponse! in
            guard request.URL.isLocal else {
                return GCDWebServerResponse(statusCode: 403)
            }

            return handler(request: request)
        }

        server.addHandlerForMethod(method, path: "/\(module)/\(resource)", requestClass: GCDWebServerRequest.self, processBlock: wrappedHandler)
    }

    /// Convenience method to register a resource in the main bundle. Will be mounted at $base/$module/$resource
    func registerMainBundleResource(resource: String, module: String) {
        if let path = NSBundle.mainBundle().pathForResource(resource, ofType: nil) {
            server.addGETHandlerForPath("/\(module)/\(resource)", filePath: path, isAttachment: false, cacheAge: UInt.max, allowRangeRequests: true)
        }
    }

    /// Convenience method to register all resources in the main bundle of a specific type. Will be mounted at $base/$module/$resource
    func registerMainBundleResourcesOfType(type: String, module: String) {
        for path: NSString in NSBundle.pathsForResourcesOfType(type, inDirectory: NSBundle.mainBundle().bundlePath) {
            let resource = path.lastPathComponent
            server.addGETHandlerForPath("/\(module)/\(resource)", filePath: path as String, isAttachment: false, cacheAge: UInt.max, allowRangeRequests: true)
        }
    }

    /// Return a full url, as a string, for a resource in a module. No check is done to find out if the resource actually exist.
    func URLForResource(resource: String, module: String) -> String {
        return "\(base)/\(module)/\(resource)"
    }

    func baseReaderModeURL() -> String {
        return WebServer.sharedInstance.URLForResource("page", module: "reader-mode")
    }
}
