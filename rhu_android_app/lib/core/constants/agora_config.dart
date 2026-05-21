class AgoraConfig {
  const AgoraConfig._();

  // Put your Agora App ID here.
  // Get this from Agora Console > Project Management.
  static const String appId = '87381a4391814c5fb00edc659d80b157';

  // For testing only:
  // If your Agora project uses App ID authentication only, leave this empty.
  // If your Agora project uses token authentication, paste a temporary token here.
  // Later, create a backend endpoint to generate tokens properly.
  static const String temporaryToken = '';
}
