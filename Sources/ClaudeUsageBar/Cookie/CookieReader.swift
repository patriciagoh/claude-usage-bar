import Foundation

protocol CookieReader {
    func read() throws -> String
}
