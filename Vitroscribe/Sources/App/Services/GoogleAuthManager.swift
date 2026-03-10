import Foundation
import AuthenticationServices
import CryptoKit
import os.log

class GoogleAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleAuthManager()
    
    private let clientId = "482650596028-2oajhd8h2qkp66enum04798af8p7ersa.apps.googleusercontent.com"
    private let clientSecret = "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"
    private let redirectURI = "com.googleusercontent.apps.482650596028-2oajhd8h2qkp66enum04798af8p7ersa:/oauth2redirect"
    
    @Published var isConnected: Bool = false
    @Published var connectedEmail: String = ""
    
    private var accessToken: String?
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "GoogleRefreshToken") }
        set { UserDefaults.standard.set(newValue, forKey: "GoogleRefreshToken") }
    }
    
    override private init() {
        super.init()
        checkExistingConnection()
    }
    
    func checkExistingConnection() {
        if let token = refreshToken, !token.isEmpty {
            refreshAccessToken(token: token) { success in
                DispatchQueue.main.async {
                    self.isConnected = success
                    if success {
                        self.fetchUserInfo()
                    }
                }
            }
        }
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? NSWindow()
    }
    
    func connect() {
        // Implement PKCE Flow
        let codeVerifier = generateRandomString(length: 64)
        let codeChallenge = generateCodeChallenge(verifier: codeVerifier)
        
        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientId)&redirect_uri=\(redirectURI)&response_type=code&scope=https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/userinfo.email&code_challenge=\(codeChallenge)&code_challenge_method=S256&access_type=offline&prompt=consent"
        
        guard let authURL = URL(string: authURLString) else { return }
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "com.googleusercontent.apps.482650596028-2oajhd8h2qkp66enum04798af8p7ersa") { callbackURL, error in
            if let error = error {
                Logger.shared.log("Auth error: \(error.localizedDescription)")
                return
            }
            
            guard let callbackURL = callbackURL,
                  let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                return
            }
            
            self.exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
        }
        
        session.presentationContextProvider = self
        session.start()
    }
    
    func disconnect() {
        refreshToken = nil
        accessToken = nil
        isConnected = false
        connectedEmail = ""
        Logger.shared.log("Google Account disconnected.")
    }
    
    private func exchangeCodeForToken(code: String, codeVerifier: String) {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let bodyString = "client_id=\(clientId)&client_secret=\(clientSecret)&code=\(code)&code_verifier=\(codeVerifier)&redirect_uri=\(redirectURI)&grant_type=authorization_code"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.accessToken = json["access_token"] as? String
                    if let refresh = json["refresh_token"] as? String {
                        self.refreshToken = refresh // Save offline token
                    }
                    
                    DispatchQueue.main.async {
                        self.isConnected = true
                        self.fetchUserInfo()
                    }
                }
            } catch {
                Logger.shared.log("Token exchange parsing error.")
            }
        }.resume()
    }
    
    private func refreshAccessToken(token: String, completion: @escaping (Bool) -> Void) {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        let bodyString = "client_id=\(clientId)&client_secret=\(clientSecret)&refresh_token=\(token)&grant_type=refresh_token"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(false)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let newAccess = json["access_token"] as? String {
                    self.accessToken = newAccess
                    completion(true)
                } else {
                    completion(false)
                }
            } catch {
                completion(false)
            }
        }.resume()
    }
    
    private func fetchUserInfo() {
        guard let token = accessToken else { return }
        let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let email = json["email"] as? String else { return }
            
            DispatchQueue.main.async {
                self.connectedEmail = email
                Logger.shared.log("Connected to Google as \(email)")
                GoogleCalendarService.shared.fetchEvents()
            }
        }.resume()
    }
    
    func getValidAccessToken(completion: @escaping (String?) -> Void) {
        if let token = accessToken {
            completion(token)
            return
        }
        
        if let refresh = refreshToken {
            refreshAccessToken(token: refresh) { success in
                completion(success ? self.accessToken : nil)
            }
        } else {
            completion(nil)
        }
    }
    
    // PKCE Helpers
    private func generateRandomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    private func generateCodeChallenge(verifier: String) -> String {
        let data = verifier.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        let base64URL = Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64URL
    }
}
