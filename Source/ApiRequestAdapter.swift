//
//  ApiRequestAdapter.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2018/01/01.
//  Copyright © 2018 kumabook. All rights reserved.
//

import Foundation

import Foundation
import Alamofire

public class ApiRequestAdapter: RequestAdapter {
    public var apiVersion: String
    public var accessToken: String?
    init(apiVersion: String, accessToken: String?) {
        self.apiVersion  = apiVersion
        self.accessToken = accessToken
    }
    
    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequest = urlRequest
        guard let token = accessToken else { return urlRequest }
        urlRequest.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "X-Api-Version")
        return urlRequest
    }
}
