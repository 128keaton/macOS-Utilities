//
//  PrintHandler.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 8/27/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import Alamofire

class PrintHandler {
    private static var manager: Alamofire.SessionManager = {
        // Create the server trust policies
        let serverTrustPolicies: [String: ServerTrustPolicy] = [
            "localhost": .disableEvaluation
        ]
        
        // Create custom manager
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        let manager = Alamofire.SessionManager(
            configuration: URLSessionConfiguration.default,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies)
        )
        
        return manager
    }()
    
    static func printJSONData(_ jsonData: Data, completion: @escaping (Bool, String) -> ()) {
        if jsonData.count == 0 {
            completion(false, "Data cannot be empty")
        }
        
        if Configuration.printServerAddress == "" {
            completion(false, "Print server address cannot be empty")
            return
        }
        
        guard let requestURL = URL(string: Configuration.printServerAddress) else {
            completion(false, "Print server address URL generation failed: \(Configuration.printServerAddress)")
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        manager.request(request).responseString { response in
            switch response.result {
            case .success(let value):
                completion(true, value)
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }
}
