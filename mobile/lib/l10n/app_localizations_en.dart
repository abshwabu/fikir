// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Fikir';

  @override
  String get tagline => 'Find your Ethiopian love';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navLikes => 'Likes';

  @override
  String get navMatches => 'Matches';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profile';

  @override
  String get like => 'Like';

  @override
  String get pass => 'Pass';

  @override
  String get superLike => 'Super Like';

  @override
  String get rewind => 'Rewind';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueAction => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Retry';

  @override
  String get delete => 'Delete';

  @override
  String get logout => 'Log Out';

  @override
  String get loginTitle => 'Welcome to Fikir';

  @override
  String get loginSubtitle => 'Enter your Ethiopian phone number to continue';

  @override
  String get phonePlaceholder => '09xxxxxxxx or 07xxxxxxxx';

  @override
  String get sendOtp => 'Send Code';

  @override
  String get verifyOtp => 'Verify Code';

  @override
  String get enterCode => 'Enter the 6-digit code sent to your phone';

  @override
  String get resendCode => 'Resend Code';

  @override
  String get invalidPhone =>
      'Please enter a valid Ethiopian mobile number (09... or 07...)';

  @override
  String get invalidOtp => 'Please enter a valid 6-digit code';

  @override
  String get noMoreProfiles => 'No more profiles nearby';

  @override
  String get noMoreProfilesDesc =>
      'Expand your distance or age preferences to meet more people.';

  @override
  String get expandPreferences => 'Expand Preferences';

  @override
  String get itsAMatch => 'It\'s a Match! 🎉';

  @override
  String get startChat => 'Send a Message';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get aboutMe => 'About Me';

  @override
  String get interests => 'Interests';

  @override
  String get languages => 'Languages';

  @override
  String get city => 'City';

  @override
  String get birthdate => 'Birthdate';

  @override
  String get selectBirthdate => 'Select Birthdate';

  @override
  String get useEthiopianCalendar => 'Use Ethiopian Calendar';

  @override
  String get useEthiopicNumerals => 'Use Ethiopic Numerals';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark';

  @override
  String get lightMode => 'Light';

  @override
  String get systemMode => 'System';

  @override
  String get offlineBanner => 'No Internet Connection - Showing cached content';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectionError => 'Network connection error';

  @override
  String get timeoutError => 'Connection timed out. Please try again.';

  @override
  String get termsNotice =>
      'By continuing, you agree to our Terms. Learn how we process your data in our Privacy Policy.';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get continueWithPhone => 'Continue with Phone';

  @override
  String get chooseLanguage => 'Choose Language';

  @override
  String get myNumberIs => 'My Number Is';

  @override
  String get phoneNotice =>
      'We will send an SMS with a 6-digit verification code. Standard carrier rates may apply.';

  @override
  String get verificationCode => 'Verification Code';

  @override
  String codeSentTo(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String attemptsRemaining(int count) {
    return 'Attempts remaining: $count';
  }

  @override
  String get tooManyAttempts =>
      'Too many failed attempts. Please request a new code.';

  @override
  String onboardingProgress(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get whatsYourName => 'What\'s your name?';

  @override
  String get nameNotice => 'This is how it will appear on your profile.';

  @override
  String get firstName => 'First name';

  @override
  String get enterNameError => 'Please enter your name';

  @override
  String get whensYourBirthday => 'When\'s your birthday?';

  @override
  String get birthdayNotice =>
      'Your age will be public. You must be at least 18 years old to join Fikir.';

  @override
  String get underageError => 'You must be at least 18 years old to use Fikir.';

  @override
  String get iAmA => 'I am a...';

  @override
  String get woman => 'Woman';

  @override
  String get man => 'Man';

  @override
  String get otherGender => 'More';

  @override
  String get interestedIn => 'Interested in...';

  @override
  String get women => 'Women';

  @override
  String get men => 'Men';

  @override
  String get everyone => 'Everyone';

  @override
  String get addPhotosTitle => 'Add your photos';

  @override
  String get addPhotosSubtitle =>
      'Add at least 1 photo to continue. Drag to reorder. Crop is 4:5.';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get mainPhoto => 'Main';

  @override
  String get minPhotosError => 'Please add at least 1 photo to continue';

  @override
  String get compressingImage => 'Compressing...';

  @override
  String get uploadingImage => 'Uploading...';

  @override
  String get uploadFailed => 'Upload failed. Tap to retry.';

  @override
  String get selectInterestsTitle => 'Your Interests';

  @override
  String get selectInterestsSubtitle =>
      'Select at least 3 interests to help us find people who share your passions.';

  @override
  String get minInterestsError => 'Please select at least 3 interests';

  @override
  String get enableLocationTitle => 'Where are you located?';

  @override
  String get enableLocationSubtitle =>
      'Fikir uses your location to discover matches nearby in Ethiopia.';

  @override
  String get allowLocation => 'Enable GPS Location';

  @override
  String get pickCityManually => 'Or choose your city manually';

  @override
  String get selectCity => 'Select City or Sub-city';

  @override
  String get moreDetailsTitle => 'Tell us more (Optional)';

  @override
  String get moreDetailsSubtitle =>
      'Add final details to make your profile stand out.';

  @override
  String get religion => 'Religion';

  @override
  String get bio => 'Bio';

  @override
  String get bioPlaceholder => 'Write something sweet about yourself...';

  @override
  String get jobTitle => 'Job Title';

  @override
  String get finishOnboarding => 'Finish & Start Swiping';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'Are you sure you want to delete your account? Your profile will be hidden immediately and permanently purged after 30 days. You can log in anytime within 30 days to cancel deletion.';

  @override
  String get confirmDelete => 'Delete My Account';

  @override
  String get accountDeleted => 'Your account has been scheduled for deletion.';

  @override
  String get likeStamp => 'LIKE';

  @override
  String get nopeStamp => 'NOPE';

  @override
  String get superLikeStamp => 'SUPER LIKE';

  @override
  String get boostAction => 'Boost';

  @override
  String get matchCelebrationTitle => 'It\'s a Match!';

  @override
  String matchSubtitle(String name) {
    return 'You and $name liked each other.';
  }

  @override
  String get keepSwiping => 'Keep Swiping';

  @override
  String get sendMessage => 'Send Message';

  @override
  String distanceKmAway(int km) {
    return '$km km away';
  }

  @override
  String get enableGps => 'Enable GPS';

  @override
  String get locationDisabledTitle => 'Location Services Needed';

  @override
  String get locationDisabledDesc =>
      'Enable GPS to discover matches close to you in Ethiopia.';

  @override
  String get dailyLimitTitle => 'You\'re Out of Likes!';

  @override
  String get dailyLimitDesc =>
      'You have reached your daily swipe limit. Get unlimited likes with Fikir Gold or wait for reset.';

  @override
  String resetsIn(String time) {
    return 'Resets in $time';
  }

  @override
  String get getFikirGold => 'Get Fikir Gold';

  @override
  String get discoverySettings => 'Discovery Settings';

  @override
  String maximumDistance(int distance) {
    return 'Maximum Distance: $distance km';
  }

  @override
  String ageRangePreference(int min, int max) {
    return 'Age Range: $min - $max';
  }

  @override
  String get showMe => 'Show Me';

  @override
  String get verifiedProfilesOnly => 'Verified Profiles Only';

  @override
  String get applyFilters => 'Apply';

  @override
  String get reportUser => 'Report User';

  @override
  String get blockUser => 'Block User';

  @override
  String get reportReasonInappropriate => 'Inappropriate photos or bio';

  @override
  String get reportReasonSpam => 'Spam or scam account';

  @override
  String get reportReasonHarassment => 'Harassment or offensive behavior';

  @override
  String get reportReasonFake => 'Fake profile or impersonation';

  @override
  String get reportSubmitted =>
      'Report submitted. Thank you for keeping Fikir safe.';

  @override
  String get userBlocked => 'User blocked.';

  @override
  String get soundEnabled => 'Sound On';

  @override
  String get soundDisabled => 'Sound Off';

  @override
  String get pullToRefresh => 'Pull to refresh';

  @override
  String get likesYouTitle => 'Likes You';

  @override
  String get seeWhoLikesYou => 'See Who Likes You';

  @override
  String get upgradeToGoldLikes =>
      'Upgrade to Fikir Gold to see everyone who likes you';

  @override
  String get seeEveryone => 'See Everyone';

  @override
  String get noLikesYet => 'No likes yet';

  @override
  String get noLikesDesc =>
      'Keep your profile active and updated to get noticed!';

  @override
  String get newMatches => 'New Matches';

  @override
  String get messages => 'Messages';

  @override
  String get noMatchesYet => 'No matches yet';

  @override
  String get noMatchesDesc => 'Keep swiping to find someone special!';

  @override
  String get noChatsYet => 'No conversations yet';

  @override
  String get noChatsDesc =>
      'When you match with someone, your chats will appear here.';

  @override
  String get unmatch => 'Unmatch';

  @override
  String unmatchConfirm(String name) {
    return 'Are you sure you want to unmatch $name? This cannot be undone.';
  }

  @override
  String get typing => 'typing...';

  @override
  String get online => 'Online';

  @override
  String get safetyBannerTitle => 'Fikir Safety Tips';

  @override
  String get safetyBannerText =>
      'Never send money or share bank/CBE account numbers. Report suspicious accounts immediately.';

  @override
  String get statusSending => 'Sending...';

  @override
  String get statusSent => 'Sent';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusRead => 'Read';

  @override
  String get statusFailed => 'Failed. Tap to retry.';

  @override
  String get voiceMessage => 'Voice note';

  @override
  String get holdToRecord => 'Hold to record, release to send';

  @override
  String recordingVoice(int seconds) {
    return 'Recording... (${seconds}s)';
  }

  @override
  String replyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get profileCompleteness => 'Profile Completeness';

  @override
  String get verifyProfile => 'Get Verified';

  @override
  String get verifiedBadge => 'Verified';

  @override
  String get pendingVerification => 'Under Review';

  @override
  String get verifySubtitle => 'Take a quick selfie to get the blue badge.';

  @override
  String get takeSelfie => 'Take Selfie';

  @override
  String get selfieSubmitted =>
      'Selfie submitted for verification. We will review it shortly.';

  @override
  String get dataSaverMode => 'Data-Saver Mode';

  @override
  String get dataSaverDesc =>
      'Reduces mobile data usage by loading smaller images and limiting prefetching';

  @override
  String get notificationSettings => 'Notifications';

  @override
  String get notifyNewMatches => 'New Matches';

  @override
  String get notifyNewMessages => 'New Messages';

  @override
  String get notifySuperLikes => 'Super Likes';

  @override
  String get privacySettings => 'Privacy';

  @override
  String get hideDistance => 'Hide My Distance';

  @override
  String get hideOnlineStatus => 'Hide Online Status';

  @override
  String get blockedUsers => 'Blocked Users';

  @override
  String get noBlockedUsers => 'You have not blocked anyone.';

  @override
  String get unblock => 'Unblock';

  @override
  String get safetyCenter => 'Safety Center';

  @override
  String get safetyCenterDesc =>
      'Emergency numbers and guidance for dating safely in Ethiopia';

  @override
  String get emergencyPolice => 'Ethiopian Police: 991';

  @override
  String get emergencyRedCross => 'Red Cross Ambulance: 907';

  @override
  String get muteMatch => 'Mute Notifications';

  @override
  String get unmuteMatch => 'Unmute Notifications';
}
