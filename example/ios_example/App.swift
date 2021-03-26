import Authgear
import SwiftUI

struct UserInfo {
    var userID: String
    var isAnonymous: Bool
    var isVerified: Bool
}

class App: ObservableObject {
    static let redirectURI = "com.authgear.example://host/path"
    static let weChatUniversalLink = "https://authgear-demo.pandawork.com/wechat/"
    static let weChatRedirectURI = "https://authgear-demo.pandawork.com/authgear/open_wechat_app"
    static let weChatAppID = "wxa2f631873c63add1"

    @Published var container: Authgear?
    @Published var sessionState = SessionState.unknown
    @Published var user: UserInfo?
    @Published var page: String = ""
    @Published var authgearActionErrorMessage: String?
    @Published var successAlertMessage: String?
    @Published var biometricSupported: Bool = false
    @Published var biometricEnabled: Bool = false

    func configure(clientId: String, endpoint: String, isThirdParty: Bool, page: String) {
        guard clientId != "", endpoint != "" else {
            authgearActionErrorMessage = "Please input client ID and endpoint"
            return
        }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            authgearActionErrorMessage = "Failed to configure Authgear"
            return
        }
        UserDefaults.standard.set(clientId, forKey: "authgear.demo.clientID")
        UserDefaults.standard.set(endpoint, forKey: "authgear.demo.endpoint")
        UserDefaults.standard.set(page, forKey: "authgear.demo.page")
        UserDefaults.standard.set(!isThirdParty, forKey: "authgear.demo.isFirstParty")
        appDelegate.configureAuthgear(clientId: clientId, endpoint: endpoint, isThirdParty: isThirdParty)
        successAlertMessage = "Configured Authgear successfully"
        self.page = page
        self.updateBiometricState()
    }

    private func updateBiometricState() {
        do {
            try self.container?.checkBiometricSupported()
            self.biometricSupported = true
        } catch {
            authgearActionErrorMessage = "\(error)"
        }

        if self.biometricSupported {
            do {
                if let enabled = try self.container?.isBiometricEnabled() {
                    self.biometricEnabled = enabled
                }
            } catch {
                authgearActionErrorMessage = "\(error)"
            }
        }
    }

    private func handleAuthorizeResult(_ result: Result<AuthorizeResult, Error>, errorMessage: String) -> Bool {
        self.updateBiometricState()
        switch result {
        case let .success(authResult):
            let userInfo = authResult.userInfo
            user = UserInfo(
                userID: userInfo.sub,
                isAnonymous: userInfo.isAnonymous,
                isVerified: userInfo.isVerified
            )
            return true
        case let .failure(error):
            print(error)
            authgearActionErrorMessage = errorMessage
            return false
        }
    }

    func login() {
        container?.authorize(
            redirectURI: App.redirectURI,
            prompt: "login",
            weChatRedirectURI: App.weChatRedirectURI,
            page: page
        ) { result in
            let success = self.handleAuthorizeResult(result, errorMessage: "Failed to login")
            if success {
                self.successAlertMessage = "Logged in successfully"
            }
        }
    }

    func enableBiometric() {
        container?.enableBiometric(
            localizedReason: "Enable biometric!",
            constraint: .biometryCurrentSet
        ) { result in
            if case let .failure(error) = result {
                print(error)
                self.authgearActionErrorMessage = "\(error)"
            }
            self.updateBiometricState()
        }
    }

    func disableBiometric() {
        do {
            try container?.disableBiometric()
        } catch {
            print(error)
            self.authgearActionErrorMessage = "\(error)"
        }
        self.updateBiometricState()
    }

    func loginBiometric() {
        container?.authenticateBiometric { result in
            let success = self.handleAuthorizeResult(result, errorMessage: "Failed to login with biometric")
            if success {
                self.successAlertMessage = "Logged in with biometric"
            }
        }
    }

    func loginAnonymously() {
        container?.authenticateAnonymously { result in
            let success = self.handleAuthorizeResult(result, errorMessage: "Failed to login anonymously")
            if success {
                self.successAlertMessage = "Logged in anonymously"
            }
        }
    }

    func openSetting() {
        container?.open(
            page: .settings,
            wechatRedirectURI: App.weChatRedirectURI
        )
    }

    func promoteAnonymousUser() {
        container?.promoteAnonymousUser(
            redirectURI: App.redirectURI,
            weChatRedirectURI: App.weChatRedirectURI
        ) { result in
            let success = self.handleAuthorizeResult(result, errorMessage: "Failed to promote anonymous user")
            if success {
                self.successAlertMessage = "Successfully promoted to normal authenticated user"
            }
        }
    }

    func fetchUserInfo() {
        container?.fetchUserInfo { userInfoResult in
            switch userInfoResult {
            case let .success(userInfo):
                self.user = UserInfo(
                    userID: userInfo.sub,
                    isAnonymous: userInfo.isAnonymous,
                    isVerified: userInfo.isVerified
                )
                self.successAlertMessage = [
                    "User Info:",
                    "",
                    "User ID: \(userInfo.sub)",
                    "Is Verified: \(userInfo.isVerified)",
                    "Is Anonymous: \(userInfo.isAnonymous)",
                    "ISS: \(userInfo.iss)"
                ].joined(separator: "\n")
            case let .failure(error):
                print(error)
                self.authgearActionErrorMessage = "Failed to fetch user info"
            }
        }
    }

    func logout() {
        container?.logout { result in
            switch result {
            case .success():
                self.user = nil
                self.successAlertMessage = "Logged out successfully"
            case let .failure(error):
                print(error)
                self.authgearActionErrorMessage = "Failed to logout"
            }
        }
    }
}
