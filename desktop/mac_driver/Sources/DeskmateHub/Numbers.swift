import Foundation

/// A decimal number that serialises to JSON exactly as written ("39.7", not "39.700000000000003"),
/// which keeps Bluetooth messages small.
func dec(_ value: Double, _ places: Int = 1) -> NSDecimalNumber {
    NSDecimalNumber(string: String(format: "%.\(places)f", value))
}
