//
//  StringExtension.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/03/11.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation

extension Date {
    static let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
    var iso8601: String {
        return Date.iso8601Formatter.string(from: self)
    }
}

extension String {
    var dateFromISO8601: Date? {
        return Date.iso8601Formatter.date(from: self)
    }
    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let string  = self as NSString
        let results = regex.matches(in: self, options: [], range: NSMakeRange(0, string.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound ?
                    string.substring(with: result.range(at: $0)) : ""
            }
        }
    }
}
