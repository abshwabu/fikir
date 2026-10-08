// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appName => 'ፍቅር';

  @override
  String get tagline => 'የኢትዮጵያውያን የፍቅር ጓደኛ መፈለጊያ';

  @override
  String get navDiscover => 'መርምር';

  @override
  String get navLikes => 'የወደዱኝ';

  @override
  String get navMatches => 'የተጣመሩ';

  @override
  String get navChat => 'መልእክት';

  @override
  String get navProfile => 'መገለጫ';

  @override
  String get like => 'ውደድ';

  @override
  String get pass => 'እለፍ';

  @override
  String get superLike => 'ልዩ ውደድ';

  @override
  String get rewind => 'መልስ';

  @override
  String get save => 'አስቀምጥ';

  @override
  String get cancel => 'ሰርዝ';

  @override
  String get continueAction => 'ቀጥል';

  @override
  String get back => 'ተመለስ';

  @override
  String get retry => 'እንደገና ሞክር';

  @override
  String get delete => 'አጥፋ';

  @override
  String get logout => 'ውጣ';

  @override
  String get loginTitle => 'እንኳን ወደ ፍቅር በደህና መጡ';

  @override
  String get loginSubtitle => 'ለመቀጠል የኢትዮጵያ ስልክ ቁጥርዎን ያስገቡ';

  @override
  String get phonePlaceholder => '09xxxxxxxx ወይም 07xxxxxxxx';

  @override
  String get sendOtp => 'ኮድ ላክ';

  @override
  String get verifyOtp => 'ኮዱን አረጋግጥ';

  @override
  String get enterCode => 'በስልክዎ የተላከውን ባለ 6 አሃዝ ኮድ ያስገቡ';

  @override
  String get resendCode => 'ኮድ እንደገና ላክ';

  @override
  String get invalidPhone =>
      'እባክዎ ትክክለኛ የኢትዮጵያ የሞባይል ቁጥር ያስገቡ (09... ወይም 07...)';

  @override
  String get invalidOtp => 'እባክዎ ትክክለኛ ባለ 6 አሃዝ ኮድ ያስገቡ';

  @override
  String get noMoreProfiles => 'በአካባቢዎ ተጨማሪ ሰዎች የሉም';

  @override
  String get noMoreProfilesDesc => 'ተጨማሪ ሰዎችን ለማግኘት የርቀት ወይም የእድሜ ምርጫዎችን ያስፉ።';

  @override
  String get expandPreferences => 'ምርጫዎችን አስፋ';

  @override
  String get itsAMatch => 'ተጣማጅ ተገኝቷል! 🎉';

  @override
  String get startChat => 'መልእክት ጀምር';

  @override
  String get editProfile => 'መገለጫ አርትዕ';

  @override
  String get aboutMe => 'ስለ እኔ';

  @override
  String get interests => 'ፍላጎቶች';

  @override
  String get languages => 'ቋንቋዎች';

  @override
  String get city => 'ከተማ';

  @override
  String get birthdate => 'የልደት ቀን';

  @override
  String get selectBirthdate => 'የልደት ቀን ይምረጡ';

  @override
  String get useEthiopianCalendar => 'የኢትዮጵያ ቀን መቁጠሪያ ተጠቀም';

  @override
  String get useEthiopicNumerals => 'የግዕዝ ቁጥሮች ተጠቀም';

  @override
  String get settings => 'ቅንብሮች';

  @override
  String get language => 'ቋንቋ';

  @override
  String get theme => 'ገጽታ';

  @override
  String get darkMode => 'ጨለማ';

  @override
  String get lightMode => 'ብርሃን';

  @override
  String get systemMode => 'የስልኩ ምርጫ';

  @override
  String get offlineBanner => 'የኢንተርኔት ግንኙነት የለም - የተቀመጠ መረጃ ይታያል';

  @override
  String get connecting => 'በመገናኘት ላይ...';

  @override
  String get connectionError => 'የኔትወርክ ግንኙነት ችግር';

  @override
  String get timeoutError => 'ግንኙነቱ ዘግይቷል፤ እባክዎ እንደገና ይሞክሩ።';

  @override
  String get termsNotice => 'በመቀጠል የአገልግሎት ውላችንን እና የግላዊነት ፖሊሲያችንን ይቀበላሉ።';

  @override
  String get termsOfService => 'የአገልግሎት ውል';

  @override
  String get privacyPolicy => 'የግላዊነት ፖሊሲ';

  @override
  String get continueWithPhone => 'በስልክ ቁጥር ቀጥል';

  @override
  String get chooseLanguage => 'ቋንቋ ይምረጡ';

  @override
  String get myNumberIs => 'የስልክ ቁጥሬ';

  @override
  String get phoneNotice =>
      'ባለ 6 አሃዝ ማረጋገጫ ኮድ በኤስኤምኤስ እንልካለን። መደበኛ የኦፕሬተር ክፍያዎች ሊኖሩ ይችላሉ።';

  @override
  String get verificationCode => 'የማረጋገጫ ኮድ';

  @override
  String codeSentTo(String phone) {
    return 'ወደ $phone የተላከውን ባለ 6 አሃዝ ኮድ ያስገቡ';
  }

  @override
  String attemptsRemaining(int count) {
    return 'የቀሩት ሙከራዎች: $count';
  }

  @override
  String get tooManyAttempts => 'ብዙ የተሳሳቱ ሙከራዎች ተደርገዋል። እባክዎ አዲስ ኮድ ይጠይቁ።';

  @override
  String onboardingProgress(int current, int total) {
    return 'ደረጃ $current ከ $total';
  }

  @override
  String get whatsYourName => 'ስምዎ ማን ይባላል?';

  @override
  String get nameNotice => 'ይህ ስም በመገለጫዎ ላይ የሚታይ ሲሆን በኋላ መቀየር አይቻልም።';

  @override
  String get firstName => 'የመጀመሪያ ስም';

  @override
  String get enterNameError => 'እባክዎ ስምዎን ያስገቡ';

  @override
  String get whensYourBirthday => 'የተወለዱት መቼ ነው?';

  @override
  String get birthdayNotice =>
      'እድሜዎ በይፋ ይታያል። ፍቅርን ለመጠቀም ቢያንስ 18 ዓመት መሆን አለብዎት።';

  @override
  String get underageError => 'ፍቅርን ለመጠቀም ቢያንስ 18 ዓመት መሆን አለብዎት።';

  @override
  String get iAmA => 'እኔ...';

  @override
  String get woman => 'ሴት';

  @override
  String get man => 'ወንድ';

  @override
  String get otherGender => 'ሌላ';

  @override
  String get interestedIn => 'የምፈልገው...';

  @override
  String get women => 'ሴቶችን';

  @override
  String get men => 'ወንዶችን';

  @override
  String get everyone => 'ሁሉንም';

  @override
  String get addPhotosTitle => 'ፎቶዎችዎን ያክሉ';

  @override
  String get addPhotosSubtitle =>
      'ለመቀጠል ቢያንስ 1 ፎቶ ያክሉ። የመጀመሪያው ፎቶ ዋናው ይሆናል። በ 4:5 ይቀረጻል።';

  @override
  String get addPhoto => 'ፎቶ ጨምር';

  @override
  String get mainPhoto => 'ዋና';

  @override
  String get minPhotosError => 'እባክዎ ቢያንስ 1 ፎቶ ያክሉ';

  @override
  String get compressingImage => 'ፎቶው እየተዘጋጀ ነው...';

  @override
  String get uploadingImage => 'ፎቶው እየተጫነ ነው...';

  @override
  String get uploadFailed => 'ፎቶ መጫን አልተሳካም። እንደገና ለመሞከር ይንኩ።';

  @override
  String get selectInterestsTitle => 'የእርስዎ ፍላጎቶች';

  @override
  String get selectInterestsSubtitle =>
      'ከእርስዎ ጋር ተመሳሳይ ፍላጎት ያላቸውን ለማግኘት ቢያንስ 3 ፍላጎቶችን ይምረጡ።';

  @override
  String get minInterestsError => 'እባክዎ ቢያንስ 3 ፍላጎቶችን ይምረጡ';

  @override
  String get enableLocationTitle => 'የአካባቢ መረጃ ያጋሩ';

  @override
  String get enableLocationSubtitle =>
      'ፍቅር በአቅራቢያዎ ያሉ ሰዎችን ለማሳየት የአካባቢ መረጃዎን ይጠቀማል።';

  @override
  String get allowLocation => 'የጂፒኤስ አካባቢ ፍቀድ';

  @override
  String get pickCityManually => 'ወይም ከተማዎን በእጅ ይምረጡ';

  @override
  String get selectCity => 'ከተማ ወይም ክፍለ ከተማ ይምረጡ';

  @override
  String get moreDetailsTitle => 'ተጨማሪ መረጃ (አማራጭ)';

  @override
  String get moreDetailsSubtitle => 'መገለጫዎን የበለጠ ማራኪ ለማድረግ ተጨማሪ ዝርዝሮችን ያክሉ።';

  @override
  String get religion => 'ሃይማኖት';

  @override
  String get bio => 'ስለ እኔ አጭር መግለጫ';

  @override
  String get bioPlaceholder => 'ስለራስዎ ጥቂት ያካፍሉን...';

  @override
  String get jobTitle => 'የስራ መስክ';

  @override
  String get finishOnboarding => 'ጨርስና ማሰስ ጀምር';

  @override
  String get skipForNow => 'ለአሁን እለፍ';

  @override
  String get deleteAccount => 'መለያ አጥፋ';

  @override
  String get deleteAccountConfirm =>
      'መለያዎን ማጥፋት እርግጠኛ ነዎት? መገለጫዎ ወዲያውኑ ይደበቃል፤ በ30 ቀናት ውስጥ ካልገቡ በቋሚነት ይጠፋል።';

  @override
  String get confirmDelete => 'መለያዬን አጥፋ';

  @override
  String get accountDeleted => 'መለያዎ እንዲጠፋ ጥያቄ ቀርቧል።';

  @override
  String get likeStamp => 'ወደድኩት';

  @override
  String get nopeStamp => 'አልወደድኩም';

  @override
  String get superLikeStamp => 'ልዩ ወደድኩት';

  @override
  String get boostAction => 'አጉላ (Boost)';

  @override
  String get matchCelebrationTitle => 'ተጣመራችሁ! 🎉';

  @override
  String matchSubtitle(String name) {
    return 'እርስዎና $name ተዋደዳችሁ።';
  }

  @override
  String get keepSwiping => 'ማሰስ ቀጥል';

  @override
  String get sendMessage => 'መልዕክት ላክ';

  @override
  String distanceKmAway(int km) {
    return '$km ኪ.ሜ ርቀት';
  }

  @override
  String get enableGps => 'GPS አብራ';

  @override
  String get locationDisabledTitle => 'የአካባቢ አገልግሎት ያስፈልጋል';

  @override
  String get locationDisabledDesc => 'በአቅራቢያዎ ያሉ አጋሮችን ለማግኘት እባክዎ GPS ያብሩ።';

  @override
  String get dailyLimitTitle => 'የዛሬው የመውደድ ገደብ አልቋል!';

  @override
  String get dailyLimitDesc =>
      'የዕለቱን የመውደድ ብዛት ጨርሰዋል። በፍቅር ጎልድ ያልተገደበ ያግኙ ወይም እስኪታደስ ይጠብቁ።';

  @override
  String resetsIn(String time) {
    return 'በ$time ውስጥ ይታደሳል';
  }

  @override
  String get getFikirGold => 'ፍቅር ጎልድ አግኝ';

  @override
  String get discoverySettings => 'የፍለጋ ማስተካከያዎች';

  @override
  String maximumDistance(int distance) {
    return 'ከፍተኛ ርቀት: $distance ኪ.ሜ';
  }

  @override
  String ageRangePreference(int min, int max) {
    return 'የዕድሜ ክልል: $min - $max';
  }

  @override
  String get showMe => 'የሚታዩት';

  @override
  String get verifiedProfilesOnly => 'የተረጋገጡ መገለጫዎች ብቻ';

  @override
  String get applyFilters => 'ተግብር';

  @override
  String get reportUser => 'ተጠቃሚውን ጥቆማ ስጥ';

  @override
  String get blockUser => 'ተጠቃሚውን እገድ';

  @override
  String get reportReasonInappropriate => 'ተገቢ ያልሆነ ፎቶ ወይም መግለጫ';

  @override
  String get reportReasonSpam => 'አታላይ ወይም የማስታወቂያ መለያ';

  @override
  String get reportReasonHarassment => 'ስድብ ወይም አላስፈላጊ ባህሪ';

  @override
  String get reportReasonFake => 'የውሸት መገለጫ';

  @override
  String get reportSubmitted => 'ጥቆማዎ ደርሷል። ፍቅርን ደህንነቱ የተጠበቀ ስላደረጉ እናመሰግናለን።';

  @override
  String get userBlocked => 'ተጠቃሚው ታግዷል።';

  @override
  String get soundEnabled => 'ድምፅ በርቷል';

  @override
  String get soundDisabled => 'ድምፅ ጠፍቷል';

  @override
  String get pullToRefresh => 'ለማደስ ወደ ታች ይጎትቱ';

  @override
  String get likesYouTitle => 'የወደዱዎት';

  @override
  String get seeWhoLikesYou => 'ማን እንደወደደዎት ይመልከቱ';

  @override
  String get upgradeToGoldLikes => 'የወደዱዎትን ሁሉ ለማየት ወደ ፍቅር ጎልድ ያሳድጉ';

  @override
  String get seeEveryone => 'ሁሉንም ይመልከቱ';

  @override
  String get noLikesYet => 'እስካሁን ምንም መውደድ የለም';

  @override
  String get noLikesDesc => 'ሰዎች እንዲያዩዎት መገለጫዎን ወቅታዊ እና ንቁ ያድርጉ!';

  @override
  String get newMatches => 'አዳዲስ ጥንዶች';

  @override
  String get messages => 'መልዕክቶች';

  @override
  String get noMatchesYet => 'እስካሁን ምንም ጥንድ የለም';

  @override
  String get noMatchesDesc => 'ልዩ ሰው ለማግኘት ማሰስዎን ይቀጥሉ!';

  @override
  String get noChatsYet => 'እስካሁን ምንም ውይይት የለም';

  @override
  String get noChatsDesc => 'ከአንድ ሰው ጋር ሲጣመሩ ውይይቶችዎ እዚህ ይታያሉ።';

  @override
  String get unmatch => 'አትጣመር';

  @override
  String unmatchConfirm(String name) {
    return 'ከ$name ጋር ያለዎትን ጥምረት ማቋረጥ ይፈልጋሉ? ይህ አይቀለበስም።';
  }

  @override
  String get typing => 'እየፃፈ/ች ነው...';

  @override
  String get online => 'በመስመር ላይ';

  @override
  String get safetyBannerTitle => 'የፍቅር ደህንነት ምክሮች';

  @override
  String get safetyBannerText =>
      'በጭራሽ ገንዘብ አይላኩ ወይም የባንክ/CBE ቁጥሮችን አያጋሩ። አጠራጣሪ መለያዎችን ወዲያውኑ ጥቆማ ይስጡ።';

  @override
  String get statusSending => 'በመላክ ላይ...';

  @override
  String get statusSent => 'ተልኳል';

  @override
  String get statusDelivered => 'ደርሷል';

  @override
  String get statusRead => 'ተነቧል';

  @override
  String get statusFailed => 'አልተላከም። እንደገና ለመሞከር ይንኩ።';

  @override
  String get voiceMessage => 'የድምፅ መልዕክት';

  @override
  String get holdToRecord => 'ለመቅዳት ተጭነው ይያዙ፣ ለመላክ ይልቀቁ';

  @override
  String recordingVoice(int seconds) {
    return 'እየተቀዳ ነው... ($secondsሰ)';
  }

  @override
  String replyingTo(String name) {
    return 'ለ$name መልስ';
  }

  @override
  String get typeMessage => 'መልዕክት ይፃፉ...';

  @override
  String get profileCompleteness => 'የመገለጫ ምሉዕነት';

  @override
  String get verifyProfile => 'ይረጋገጥ';

  @override
  String get verifiedBadge => 'የተረጋገጠ';

  @override
  String get pendingVerification => 'በግምገማ ላይ';

  @override
  String get verifySubtitle => 'ሰማያዊውን የማረጋገጫ ምልክት ለማግኘት የራስ-ፎቶ (ሰልፊ) ያንሱ።';

  @override
  String get takeSelfie => 'ሰልፊ አንሳ';

  @override
  String get selfieSubmitted => 'ፎቶው ለማረጋገጫ ቀርቧል። በቅርቡ እንገመግማለን።';

  @override
  String get dataSaverMode => 'የዳታ ቆጣቢ ሁነታ';

  @override
  String get dataSaverDesc => 'አነስተኛ የፎቶ መጠን በመጫን የሞባይል ዳታ አጠቃቀምን ይቀንሳል';

  @override
  String get notificationSettings => 'ማሳወቂያዎች';

  @override
  String get notifyNewMatches => 'አዳዲስ ጥንዶች';

  @override
  String get notifyNewMessages => 'አዳዲስ መልዕክቶች';

  @override
  String get notifySuperLikes => 'ልዩ መውደዶች';

  @override
  String get privacySettings => 'ግላዊነት';

  @override
  String get hideDistance => 'ርቀቴን ደብቅ';

  @override
  String get hideOnlineStatus => 'በመስመር ላይ መሆኔን ደብቅ';

  @override
  String get blockedUsers => 'የታገዱ ተጠቃሚዎች';

  @override
  String get noBlockedUsers => 'እስካሁን ያገዱት ተጠቃሚ የለም።';

  @override
  String get unblock => 'እገዳ አንሳ';

  @override
  String get safetyCenter => 'የደህንነት ማዕከል';

  @override
  String get safetyCenterDesc =>
      'በኢትዮጵያ ውስጥ በጥንቃቄ ለመገናኘት የሚያግዙ የአደጋ ጊዜ ስልኮችና መመሪያዎች';

  @override
  String get emergencyPolice => 'የኢትዮጵያ ፖሊስ: 991';

  @override
  String get emergencyRedCross => 'ቀይ መስቀል አምቡላንስ: 907';

  @override
  String get muteMatch => 'ማሳወቂያ አጥፋ';

  @override
  String get unmuteMatch => 'ማሳወቂያ አብራ';
}
