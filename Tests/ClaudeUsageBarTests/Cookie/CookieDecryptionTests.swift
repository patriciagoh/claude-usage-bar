import Foundation
import CommonCrypto
import Testing
@testable import ClaudeUsageBar

@Suite("CookieDecryption")
struct CookieDecryptionTests {

    private func encrypt(_ plaintext: String, key: Data) throws -> Data {
        let ptData = plaintext.data(using: .utf8)!
        let iv = Data(repeating: 0x20, count: 16)
        var output = Data(count: ptData.count + kCCBlockSizeAES128)
        let outputCapacity = output.count
        var outputSize = 0

        let status: CCCryptorStatus = output.withUnsafeMutableBytes { outPtr in
            ptData.withUnsafeBytes { ptPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, kCCKeySizeAES128,
                            ivPtr.baseAddress,
                            ptPtr.baseAddress, ptData.count,
                            outPtr.baseAddress, outputCapacity,
                            &outputSize
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw PollerError.cookieDecryptionFailed }
        return Data([0x76, 0x31, 0x30]) + output.prefix(outputSize) // prepend "v10"
    }

    @Test func decryptCookieValue_roundTrip() throws {
        let key = Data(repeating: 0x01, count: 16)
        let plaintext = "my_session_token_value"
        let encrypted = try encrypt(plaintext, key: key)
        let result = try CookieDecryption.decrypt(encryptedValue: encrypted, key: key)
        #expect(result == plaintext)
    }

    @Test func decryptCookieValue_throws_onWrongKey() throws {
        let key = Data(repeating: 0x01, count: 16)
        let wrongKey = Data(repeating: 0x02, count: 16)
        let encrypted = try encrypt("secret", key: key)
        #expect(throws: PollerError.cookieDecryptionFailed) {
            try CookieDecryption.decrypt(encryptedValue: encrypted, key: wrongKey)
        }
    }

    @Test func pbkdf2_producesCorrectLength() throws {
        let key = try CookieDecryption.pbkdf2Key(password: "test_password")
        #expect(key.count == 16)
    }
}
