/// Public invite base. Must match the `https` host in AndroidManifest and the
/// associated domains in the iOS project; change all three together.
const String kInviteBaseUrl = 'https://whotook.party/j';

/// Public site and legal links. The support inbox is hosted by Zoho Mail.
const String kSiteUrl = 'https://whotook.party';
const String kSupportEmail = 'hello@whotook.party';
const String kSupportUrl = '$kSiteUrl/support';
const String kTermsUrl = '$kSiteUrl/terms';
const String kPrivacyUrl = '$kSiteUrl/privacy';

/// Keep these in step with pubspec `version:` and the Android versionCode on
/// every release. They are what the room compares between phones.
const String kAppVersion = '1.9.1';
const int kAppBuildNumber = 14;

const String kAndroidStoreUrl =
    'https://play.google.com/store/apps/details?id=party.whotook.app';
const String kIosStoreUrl = 'https://whotook.party';

/// Small corner mark on exported memes.
const String kWatermark = 'whotook.party';
