import Foundation
import CommonCrypto

enum CookieDecryption {

    // Decrypt a Chrome cookie encrypted_value (AES-128-CBC, "v10" prefix, PKCS7).
    // key must be 16 bytes (produced by pbkdf2Key).
    static func decrypt(encryptedValue: Data, key: Data) throws -> String {
        guard encryptedValue.count > 3 else {
            throw PollerError.cookieDecryptionFailed
        }

        let ciphertext = encryptedValue.dropFirst(3)  // strip "v10" prefix
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)

        var decrypted = Data(count: ciphertext.count + kCCBlockSizeAES128)
        let decryptedCapacity = decrypted.count
        var decryptedSize = 0

        let status: CCCryptorStatus = decrypted.withUnsafeMutableBytes { decPtr in
            ciphertext.withUnsafeBytes { ctPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, kCCKeySizeAES128,
                            ivPtr.baseAddress,
                            ctPtr.baseAddress, ciphertext.count,
                            decPtr.baseAddress, decryptedCapacity,
                            &decryptedSize
                        )
                    }
                }
            }
        }

        guard status == CCCryptorStatus(kCCSuccess) else {
            throw PollerError.cookieDecryptionFailed
        }

        decrypted = decrypted.prefix(decryptedSize)
        guard let result = String(data: decrypted, encoding: .utf8) else {
            throw PollerError.cookieDecryptionFailed
        }
        return result
    }

    // Derive the 16-byte AES key from Chrome's Keychain password using PBKDF2-SHA1.
    // Chrome parameters: salt="saltysalt", iterations=1003, keyLength=16
    static func pbkdf2Key(password: String) throws -> Data {
        let passwordData = password.data(using: .utf8)!
        let salt = "saltysalt".data(using: .utf8)!
        var key = Data(count: 16)

        let status: Int32 = key.withUnsafeMutableBytes { keyPtr in
            passwordData.withUnsafeBytes { pwPtr in
                salt.withUnsafeBytes { saltPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        1003,
                        keyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        16
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw PollerError.cookieDecryptionFailed
        }
        return key
    }
}
