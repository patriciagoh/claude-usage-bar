import Testing

/// Tests that read or write OrgIDStore (backed by UserDefaults) must be tagged
/// with `.orgIDShared` so they run serially and don't race each other.
extension Tag {
    @Tag static var orgIDShared: Self
}
