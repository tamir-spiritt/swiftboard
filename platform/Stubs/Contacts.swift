// Swiftboard platform (MIT): the slice of Apple's Contacts framework apps read for name display settings.
import Foundation

public enum CNContactSortOrder: Int { case none = 0, userDefault, givenName, familyName }
public enum CNContactDisplayNameOrder: Int { case userDefault = 0, givenNameFirst, familyNameFirst }
public final class CNContactsUserDefaults: NSObject {
    nonisolated(unsafe) static let instance = CNContactsUserDefaults()
    public class func shared() -> CNContactsUserDefaults { instance }
    public var sortOrder: CNContactSortOrder { .givenName }
    public var countryCode: String { "US" }
}
