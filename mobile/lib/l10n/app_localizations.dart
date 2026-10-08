import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';
import 'app_localizations_om.dart';
import 'app_localizations_ti.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en'),
    Locale('om'),
    Locale('ti')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Fikir'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Find your Ethiopian love'**
  String get tagline;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get navLikes;

  /// No description provided for @navMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get navMatches;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @pass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get pass;

  /// No description provided for @superLike.
  ///
  /// In en, this message translates to:
  /// **'Super Like'**
  String get superLike;

  /// No description provided for @rewind.
  ///
  /// In en, this message translates to:
  /// **'Rewind'**
  String get rewind;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Fikir'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your Ethiopian phone number to continue'**
  String get loginSubtitle;

  /// No description provided for @phonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'09xxxxxxxx or 07xxxxxxxx'**
  String get phonePlaceholder;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendOtp;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyOtp;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to your phone'**
  String get enterCode;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid Ethiopian mobile number (09... or 07...)'**
  String get invalidPhone;

  /// No description provided for @invalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 6-digit code'**
  String get invalidOtp;

  /// No description provided for @noMoreProfiles.
  ///
  /// In en, this message translates to:
  /// **'No more profiles nearby'**
  String get noMoreProfiles;

  /// No description provided for @noMoreProfilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Expand your distance or age preferences to meet more people.'**
  String get noMoreProfilesDesc;

  /// No description provided for @expandPreferences.
  ///
  /// In en, this message translates to:
  /// **'Expand Preferences'**
  String get expandPreferences;

  /// No description provided for @itsAMatch.
  ///
  /// In en, this message translates to:
  /// **'It\'s a Match! 🎉'**
  String get itsAMatch;

  /// No description provided for @startChat.
  ///
  /// In en, this message translates to:
  /// **'Send a Message'**
  String get startChat;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @aboutMe.
  ///
  /// In en, this message translates to:
  /// **'About Me'**
  String get aboutMe;

  /// No description provided for @interests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interests;

  /// No description provided for @languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @birthdate.
  ///
  /// In en, this message translates to:
  /// **'Birthdate'**
  String get birthdate;

  /// No description provided for @selectBirthdate.
  ///
  /// In en, this message translates to:
  /// **'Select Birthdate'**
  String get selectBirthdate;

  /// No description provided for @useEthiopianCalendar.
  ///
  /// In en, this message translates to:
  /// **'Use Ethiopian Calendar'**
  String get useEthiopianCalendar;

  /// No description provided for @useEthiopicNumerals.
  ///
  /// In en, this message translates to:
  /// **'Use Ethiopic Numerals'**
  String get useEthiopicNumerals;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @systemMode.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemMode;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection - Showing cached content'**
  String get offlineBanner;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Network connection error'**
  String get connectionError;

  /// No description provided for @timeoutError.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Please try again.'**
  String get timeoutError;

  /// No description provided for @termsNotice.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our Terms. Learn how we process your data in our Privacy Policy.'**
  String get termsNotice;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @continueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with Phone'**
  String get continueWithPhone;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get chooseLanguage;

  /// No description provided for @myNumberIs.
  ///
  /// In en, this message translates to:
  /// **'My Number Is'**
  String get myNumberIs;

  /// No description provided for @phoneNotice.
  ///
  /// In en, this message translates to:
  /// **'We will send an SMS with a 6-digit verification code. Standard carrier rates may apply.'**
  String get phoneNotice;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCode;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {phone}'**
  String codeSentTo(String phone);

  /// No description provided for @attemptsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Attempts remaining: {count}'**
  String attemptsRemaining(int count);

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please request a new code.'**
  String get tooManyAttempts;

  /// No description provided for @onboardingProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingProgress(int current, int total);

  /// No description provided for @whatsYourName.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get whatsYourName;

  /// No description provided for @nameNotice.
  ///
  /// In en, this message translates to:
  /// **'This is how it will appear on your profile.'**
  String get nameNotice;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @enterNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get enterNameError;

  /// No description provided for @whensYourBirthday.
  ///
  /// In en, this message translates to:
  /// **'When\'s your birthday?'**
  String get whensYourBirthday;

  /// No description provided for @birthdayNotice.
  ///
  /// In en, this message translates to:
  /// **'Your age will be public. You must be at least 18 years old to join Fikir.'**
  String get birthdayNotice;

  /// No description provided for @underageError.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 18 years old to use Fikir.'**
  String get underageError;

  /// No description provided for @iAmA.
  ///
  /// In en, this message translates to:
  /// **'I am a...'**
  String get iAmA;

  /// No description provided for @woman.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get woman;

  /// No description provided for @man.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get man;

  /// No description provided for @otherGender.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get otherGender;

  /// No description provided for @interestedIn.
  ///
  /// In en, this message translates to:
  /// **'Interested in...'**
  String get interestedIn;

  /// No description provided for @women.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get women;

  /// No description provided for @men.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get men;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @addPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your photos'**
  String get addPhotosTitle;

  /// No description provided for @addPhotosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add at least 1 photo to continue. Drag to reorder. Crop is 4:5.'**
  String get addPhotosSubtitle;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @mainPhoto.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get mainPhoto;

  /// No description provided for @minPhotosError.
  ///
  /// In en, this message translates to:
  /// **'Please add at least 1 photo to continue'**
  String get minPhotosError;

  /// No description provided for @compressingImage.
  ///
  /// In en, this message translates to:
  /// **'Compressing...'**
  String get compressingImage;

  /// No description provided for @uploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploadingImage;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Tap to retry.'**
  String get uploadFailed;

  /// No description provided for @selectInterestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Interests'**
  String get selectInterestsTitle;

  /// No description provided for @selectInterestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select at least 3 interests to help us find people who share your passions.'**
  String get selectInterestsSubtitle;

  /// No description provided for @minInterestsError.
  ///
  /// In en, this message translates to:
  /// **'Please select at least 3 interests'**
  String get minInterestsError;

  /// No description provided for @enableLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you located?'**
  String get enableLocationTitle;

  /// No description provided for @enableLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fikir uses your location to discover matches nearby in Ethiopia.'**
  String get enableLocationSubtitle;

  /// No description provided for @allowLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable GPS Location'**
  String get allowLocation;

  /// No description provided for @pickCityManually.
  ///
  /// In en, this message translates to:
  /// **'Or choose your city manually'**
  String get pickCityManually;

  /// No description provided for @selectCity.
  ///
  /// In en, this message translates to:
  /// **'Select City or Sub-city'**
  String get selectCity;

  /// No description provided for @moreDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us more (Optional)'**
  String get moreDetailsTitle;

  /// No description provided for @moreDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add final details to make your profile stand out.'**
  String get moreDetailsSubtitle;

  /// No description provided for @religion.
  ///
  /// In en, this message translates to:
  /// **'Religion'**
  String get religion;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @bioPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write something sweet about yourself...'**
  String get bioPlaceholder;

  /// No description provided for @jobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get jobTitle;

  /// No description provided for @finishOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Finish & Start Swiping'**
  String get finishOnboarding;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? Your profile will be hidden immediately and permanently purged after 30 days. You can log in anytime within 30 days to cancel deletion.'**
  String get deleteAccountConfirm;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get confirmDelete;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been scheduled for deletion.'**
  String get accountDeleted;

  /// No description provided for @likeStamp.
  ///
  /// In en, this message translates to:
  /// **'LIKE'**
  String get likeStamp;

  /// No description provided for @nopeStamp.
  ///
  /// In en, this message translates to:
  /// **'NOPE'**
  String get nopeStamp;

  /// No description provided for @superLikeStamp.
  ///
  /// In en, this message translates to:
  /// **'SUPER LIKE'**
  String get superLikeStamp;

  /// No description provided for @boostAction.
  ///
  /// In en, this message translates to:
  /// **'Boost'**
  String get boostAction;

  /// No description provided for @matchCelebrationTitle.
  ///
  /// In en, this message translates to:
  /// **'It\'s a Match!'**
  String get matchCelebrationTitle;

  /// No description provided for @matchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You and {name} liked each other.'**
  String matchSubtitle(String name);

  /// No description provided for @keepSwiping.
  ///
  /// In en, this message translates to:
  /// **'Keep Swiping'**
  String get keepSwiping;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get sendMessage;

  /// No description provided for @distanceKmAway.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String distanceKmAway(int km);

  /// No description provided for @enableGps.
  ///
  /// In en, this message translates to:
  /// **'Enable GPS'**
  String get enableGps;

  /// No description provided for @locationDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Services Needed'**
  String get locationDisabledTitle;

  /// No description provided for @locationDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable GPS to discover matches close to you in Ethiopia.'**
  String get locationDisabledDesc;

  /// No description provided for @dailyLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re Out of Likes!'**
  String get dailyLimitTitle;

  /// No description provided for @dailyLimitDesc.
  ///
  /// In en, this message translates to:
  /// **'You have reached your daily swipe limit. Get unlimited likes with Fikir Gold or wait for reset.'**
  String get dailyLimitDesc;

  /// No description provided for @resetsIn.
  ///
  /// In en, this message translates to:
  /// **'Resets in {time}'**
  String resetsIn(String time);

  /// No description provided for @getFikirGold.
  ///
  /// In en, this message translates to:
  /// **'Get Fikir Gold'**
  String get getFikirGold;

  /// No description provided for @discoverySettings.
  ///
  /// In en, this message translates to:
  /// **'Discovery Settings'**
  String get discoverySettings;

  /// No description provided for @maximumDistance.
  ///
  /// In en, this message translates to:
  /// **'Maximum Distance: {distance} km'**
  String maximumDistance(int distance);

  /// No description provided for @ageRangePreference.
  ///
  /// In en, this message translates to:
  /// **'Age Range: {min} - {max}'**
  String ageRangePreference(int min, int max);

  /// No description provided for @showMe.
  ///
  /// In en, this message translates to:
  /// **'Show Me'**
  String get showMe;

  /// No description provided for @verifiedProfilesOnly.
  ///
  /// In en, this message translates to:
  /// **'Verified Profiles Only'**
  String get verifiedProfilesOnly;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyFilters;

  /// No description provided for @reportUser.
  ///
  /// In en, this message translates to:
  /// **'Report User'**
  String get reportUser;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get blockUser;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate photos or bio'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or scam account'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or offensive behavior'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonFake.
  ///
  /// In en, this message translates to:
  /// **'Fake profile or impersonation'**
  String get reportReasonFake;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you for keeping Fikir safe.'**
  String get reportSubmitted;

  /// No description provided for @userBlocked.
  ///
  /// In en, this message translates to:
  /// **'User blocked.'**
  String get userBlocked;

  /// No description provided for @soundEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sound On'**
  String get soundEnabled;

  /// No description provided for @soundDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sound Off'**
  String get soundDisabled;

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pullToRefresh;

  /// No description provided for @likesYouTitle.
  ///
  /// In en, this message translates to:
  /// **'Likes You'**
  String get likesYouTitle;

  /// No description provided for @seeWhoLikesYou.
  ///
  /// In en, this message translates to:
  /// **'See Who Likes You'**
  String get seeWhoLikesYou;

  /// No description provided for @upgradeToGoldLikes.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Fikir Gold to see everyone who likes you'**
  String get upgradeToGoldLikes;

  /// No description provided for @seeEveryone.
  ///
  /// In en, this message translates to:
  /// **'See Everyone'**
  String get seeEveryone;

  /// No description provided for @noLikesYet.
  ///
  /// In en, this message translates to:
  /// **'No likes yet'**
  String get noLikesYet;

  /// No description provided for @noLikesDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep your profile active and updated to get noticed!'**
  String get noLikesDesc;

  /// No description provided for @newMatches.
  ///
  /// In en, this message translates to:
  /// **'New Matches'**
  String get newMatches;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @noMatchesYet.
  ///
  /// In en, this message translates to:
  /// **'No matches yet'**
  String get noMatchesYet;

  /// No description provided for @noMatchesDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep swiping to find someone special!'**
  String get noMatchesDesc;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noChatsYet;

  /// No description provided for @noChatsDesc.
  ///
  /// In en, this message translates to:
  /// **'When you match with someone, your chats will appear here.'**
  String get noChatsDesc;

  /// No description provided for @unmatch.
  ///
  /// In en, this message translates to:
  /// **'Unmatch'**
  String get unmatch;

  /// No description provided for @unmatchConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unmatch {name}? This cannot be undone.'**
  String unmatchConfirm(String name);

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get typing;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @safetyBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Fikir Safety Tips'**
  String get safetyBannerTitle;

  /// No description provided for @safetyBannerText.
  ///
  /// In en, this message translates to:
  /// **'Never send money or share bank/CBE account numbers. Report suspicious accounts immediately.'**
  String get safetyBannerText;

  /// No description provided for @statusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get statusSending;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get statusRead;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed. Tap to retry.'**
  String get statusFailed;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voiceMessage;

  /// No description provided for @holdToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold to record, release to send'**
  String get holdToRecord;

  /// No description provided for @recordingVoice.
  ///
  /// In en, this message translates to:
  /// **'Recording... ({seconds}s)'**
  String recordingVoice(int seconds);

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(String name);

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @profileCompleteness.
  ///
  /// In en, this message translates to:
  /// **'Profile Completeness'**
  String get profileCompleteness;

  /// No description provided for @verifyProfile.
  ///
  /// In en, this message translates to:
  /// **'Get Verified'**
  String get verifyProfile;

  /// No description provided for @verifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedBadge;

  /// No description provided for @pendingVerification.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get pendingVerification;

  /// No description provided for @verifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a quick selfie to get the blue badge.'**
  String get verifySubtitle;

  /// No description provided for @takeSelfie.
  ///
  /// In en, this message translates to:
  /// **'Take Selfie'**
  String get takeSelfie;

  /// No description provided for @selfieSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Selfie submitted for verification. We will review it shortly.'**
  String get selfieSubmitted;

  /// No description provided for @dataSaverMode.
  ///
  /// In en, this message translates to:
  /// **'Data-Saver Mode'**
  String get dataSaverMode;

  /// No description provided for @dataSaverDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduces mobile data usage by loading smaller images and limiting prefetching'**
  String get dataSaverDesc;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationSettings;

  /// No description provided for @notifyNewMatches.
  ///
  /// In en, this message translates to:
  /// **'New Matches'**
  String get notifyNewMatches;

  /// No description provided for @notifyNewMessages.
  ///
  /// In en, this message translates to:
  /// **'New Messages'**
  String get notifyNewMessages;

  /// No description provided for @notifySuperLikes.
  ///
  /// In en, this message translates to:
  /// **'Super Likes'**
  String get notifySuperLikes;

  /// No description provided for @privacySettings.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySettings;

  /// No description provided for @hideDistance.
  ///
  /// In en, this message translates to:
  /// **'Hide My Distance'**
  String get hideDistance;

  /// No description provided for @hideOnlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Hide Online Status'**
  String get hideOnlineStatus;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsers;

  /// No description provided for @noBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'You have not blocked anyone.'**
  String get noBlockedUsers;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @safetyCenter.
  ///
  /// In en, this message translates to:
  /// **'Safety Center'**
  String get safetyCenter;

  /// No description provided for @safetyCenterDesc.
  ///
  /// In en, this message translates to:
  /// **'Emergency numbers and guidance for dating safely in Ethiopia'**
  String get safetyCenterDesc;

  /// No description provided for @emergencyPolice.
  ///
  /// In en, this message translates to:
  /// **'Ethiopian Police: 991'**
  String get emergencyPolice;

  /// No description provided for @emergencyRedCross.
  ///
  /// In en, this message translates to:
  /// **'Red Cross Ambulance: 907'**
  String get emergencyRedCross;

  /// No description provided for @muteMatch.
  ///
  /// In en, this message translates to:
  /// **'Mute Notifications'**
  String get muteMatch;

  /// No description provided for @unmuteMatch.
  ///
  /// In en, this message translates to:
  /// **'Unmute Notifications'**
  String get unmuteMatch;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en', 'om', 'ti'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
    case 'om':
      return AppLocalizationsOm();
    case 'ti':
      return AppLocalizationsTi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
