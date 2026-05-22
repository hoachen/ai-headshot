import Foundation
import RevenueCat

struct UserEntitlement {
    let isPro: Bool
    let expirationDate: Date?
    let willRenew: Bool

    init(customerInfo: CustomerInfo) {
        let proEntitlement = customerInfo.entitlements[AppConfig.proEntitlement]
        self.isPro = proEntitlement?.isActive == true
        self.expirationDate = proEntitlement?.expirationDate
        self.willRenew = proEntitlement?.willRenew == true
    }

    static var free: UserEntitlement {
        UserEntitlement(isPro: false, expirationDate: nil, willRenew: false)
    }

    private init(isPro: Bool, expirationDate: Date?, willRenew: Bool) {
        self.isPro = isPro
        self.expirationDate = expirationDate
        self.willRenew = willRenew
    }
}
