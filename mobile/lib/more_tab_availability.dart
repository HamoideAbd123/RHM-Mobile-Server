/// Returns whether server-backed destinations can safely be shown in More.
///
/// A saved API client may exist even when its first connection check failed.
/// Both a client and a confirmed connection are required.
bool shouldShowMoreServerModules({
  required bool hasApiClient,
  required bool connectionReady,
}) {
  return hasApiClient && connectionReady;
}
