// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Oromo (`om`).
class AppLocalizationsOm extends AppLocalizations {
  AppLocalizationsOm([String locale = 'om']) : super(locale);

  @override
  String get appName => 'Fikir';

  @override
  String get tagline => 'Jaalallee keessan Itoophiyaa keessaa barbaadaa';

  @override
  String get navDiscover => 'Barbaadi';

  @override
  String get navLikes => 'Kan na jaallatan';

  @override
  String get navMatches => 'Kan wal fakkaatan';

  @override
  String get navChat => 'Ergaa';

  @override
  String get navProfile => 'Piroofayilii';

  @override
  String get like => 'Jaalladhu';

  @override
  String get pass => 'Darbii';

  @override
  String get superLike => 'Baay\'ee Jaalladhu';

  @override
  String get rewind => 'Deebisi';

  @override
  String get save => 'Olkaayi';

  @override
  String get cancel => 'Haqi';

  @override
  String get continueAction => 'Itti fufi';

  @override
  String get back => 'Duubatti';

  @override
  String get retry => 'Irra deebi\'i';

  @override
  String get delete => 'Balleessi';

  @override
  String get logout => 'Ba\'i';

  @override
  String get loginTitle => 'Baga gara Fikir dhuftan';

  @override
  String get loginSubtitle =>
      'Itti fufuuf lakkoofsa bilbilaa Itoophiyaa galchaa';

  @override
  String get phonePlaceholder => '09xxxxxxxx ykn 07xxxxxxxx';

  @override
  String get sendOtp => 'Koodii Ergi';

  @override
  String get verifyOtp => 'Koodii Mirkaneessi';

  @override
  String get enterCode => 'Koodii dijiitii 6 bilbila keessaniif ergame galchaa';

  @override
  String get resendCode => 'Koodii Lamuu Ergi';

  @override
  String get invalidPhone =>
      'Maaloo lakkoofsa bilbilaa Itoophiyaa sirrii galchaa (09... ykn 07...)';

  @override
  String get invalidOtp => 'Maaloo koodii dijiitii 6 sirrii galchaa';

  @override
  String get noMoreProfiles => 'Piroofayiliin naannoo keessanii hin jiru';

  @override
  String get noMoreProfilesDesc =>
      'Namoota dabalataa argachuuf filannoo fageenyaa ykn umrii bal\'isaa.';

  @override
  String get expandPreferences => 'Filannoo Bal\'isi';

  @override
  String get itsAMatch => 'Wal argattaniittu! 🎉';

  @override
  String get startChat => 'Ergaa Jalqabi';

  @override
  String get editProfile => 'Piroofayilii Gulaali';

  @override
  String get aboutMe => 'Waa\'ee koo';

  @override
  String get interests => 'Fedhiiwwan';

  @override
  String get languages => 'Afaanota';

  @override
  String get city => 'Magaalaa';

  @override
  String get birthdate => 'Guyyaa Dhalootaa';

  @override
  String get selectBirthdate => 'Guyyaa Dhalootaa Filadhu';

  @override
  String get useEthiopianCalendar => 'Kalandara Itoophiyaa Fayyadami';

  @override
  String get useEthiopicNumerals => 'Lakkoofsa Ge\'ez Fayyadami';

  @override
  String get settings => 'Qindaa\'ina';

  @override
  String get language => 'Afaan';

  @override
  String get theme => 'Bifa';

  @override
  String get darkMode => 'Dukkana';

  @override
  String get lightMode => 'Ifaa';

  @override
  String get systemMode => 'Sirna';

  @override
  String get offlineBanner =>
      'Interneetii hin jiru - Daataa kuufame mul\'isaa jira';

  @override
  String get connecting => 'Walqunnamaa jira...';

  @override
  String get connectionError => 'Dogoggora interneetii';

  @override
  String get timeoutError => 'Yeroon darbeera; irra deebi\'aa yaalaa.';

  @override
  String get termsNotice =>
      'Itti fufuun seera fi imaammata dhuunfaa keenya waliigaluu keessan agarsiisa.';

  @override
  String get termsOfService => 'Waliigaltee Tajaajilaa';

  @override
  String get privacyPolicy => 'Imaammata Dhuunfaa';

  @override
  String get continueWithPhone => 'Bilbilaan Itti Fufi';

  @override
  String get chooseLanguage => 'Afaan Filadhu';

  @override
  String get myNumberIs => 'Lakkoofsi Koo';

  @override
  String get phoneNotice =>
      'Koodii mirkaneessaa dijiitii 6 SMS dhaan isiniif ergina.';

  @override
  String get verificationCode => 'Koodii Mirkaneessaa';

  @override
  String codeSentTo(String phone) {
    return 'Koodii $phone dhaan ergame galchaa';
  }

  @override
  String attemptsRemaining(int count) {
    return 'Yaalii hafe: $count';
  }

  @override
  String get tooManyAttempts =>
      'Yaalii baay\'ee dogoggortaniittu. Maaloo koodii haaraa gaafadhaa.';

  @override
  String onboardingProgress(int current, int total) {
    return 'Tarkaanfii $current / $total';
  }

  @override
  String get whatsYourName => 'Maqaan kee eenyu?';

  @override
  String get nameNotice => 'Kun piroofayilii kee irratti kan mul\'atu ta\'a.';

  @override
  String get firstName => 'Maqaa Duraa';

  @override
  String get enterNameError => 'Maaloo maqaa kee galchi';

  @override
  String get whensYourBirthday => 'Guyyaan dhalootaa kee yoomi?';

  @override
  String get birthdayNotice =>
      'Umriin kee ifatti mul\'ata. Fikir fayyadamuuf waggaa 18 guutuu qabda.';

  @override
  String get underageError =>
      'Fikir fayyadamuuf yoo xiqqaate waggaa 18 ta\'uu qabda.';

  @override
  String get iAmA => 'Ani...';

  @override
  String get woman => 'Dubartii';

  @override
  String get man => 'Dhiira';

  @override
  String get otherGender => 'Biroo';

  @override
  String get interestedIn => 'Kan na hawwatu...';

  @override
  String get women => 'Dubartoota';

  @override
  String get men => 'Dhiirota';

  @override
  String get everyone => 'Hunda';

  @override
  String get addPhotosTitle => 'Suuraa keessan dabalaa';

  @override
  String get addPhotosSubtitle =>
      'Itti fufuuf yoo xiqqaate suuraa 1 dabalaa. Suuraan duraa kan gubbaa ta\'a.';

  @override
  String get addPhoto => 'Suuraa Dabali';

  @override
  String get mainPhoto => 'Guddaa';

  @override
  String get minPhotosError => 'Maaloo yoo xiqqaate suuraa 1 dabalaa';

  @override
  String get compressingImage => 'Suuraan qophaa\'aa jira...';

  @override
  String get uploadingImage => 'Suuraan fe\'amaa jira...';

  @override
  String get uploadFailed => 'Fe\'uun hin danda\'amne. Irra deebi\'uuf tuqi.';

  @override
  String get selectInterestsTitle => 'Fedhiiwwan Kee';

  @override
  String get selectInterestsSubtitle =>
      'Namoota fedhii kee qooddatan argachuuf yoo xiqqaate fedhii 3 filadhu.';

  @override
  String get minInterestsError => 'Maaloo yoo xiqqaate fedhii 3 filadhu';

  @override
  String get enableLocationTitle => 'Bakka jirtu agarsiisi';

  @override
  String get enableLocationSubtitle =>
      'Fikir namoota naannoo kee jiran argachuuf bakka kee fayyadama.';

  @override
  String get allowLocation => 'Bakka GPS Eeyyami';

  @override
  String get pickCityManually => 'Yookiin magaalaa harkaaniin filadhu';

  @override
  String get selectCity => 'Magaalaa Filadhu';

  @override
  String get moreDetailsTitle => 'Ibsa Dabalataa (Filannoo)';

  @override
  String get moreDetailsSubtitle =>
      'Piroofayilii kee bareechuuf dabalata kenni.';

  @override
  String get religion => 'Amantaa';

  @override
  String get bio => 'Waa\'ee koo gabaabinaan';

  @override
  String get bioPlaceholder => 'Waa\'ee kee waan tokko barreessi...';

  @override
  String get jobTitle => 'Hojii';

  @override
  String get finishOnboarding => 'Xumuri & Barbaadi';

  @override
  String get skipForNow => 'Ammaaf darbi';

  @override
  String get deleteAccount => 'Akkaawuntii Balleessi';

  @override
  String get deleteAccountConfirm =>
      'Akkaawuntii keessan balleessuu barbaadduu? Piroofayiliin keessan yeroodhaaf ni dhokata, guyyoota 30 keessatti yoo hin seenne guutummaatti ni bada.';

  @override
  String get confirmDelete => 'Akkaawuntii Koo Balleessi';

  @override
  String get accountDeleted => 'Akkaawuntiin keessan akka badu gaafatameera.';

  @override
  String get likeStamp => 'JAALLADHEERA';

  @override
  String get nopeStamp => 'HIN JAALLANNE';

  @override
  String get superLikeStamp => 'BAAY\'EE JAALLADHEERA';

  @override
  String get boostAction => 'Daran Guddisi';

  @override
  String get matchCelebrationTitle => 'Wal Qabattaniittu! 🎉';

  @override
  String matchSubtitle(String name) {
    return 'Atii fi $name wal jaallattaniittu.';
  }

  @override
  String get keepSwiping => 'Itti fufi sakatta\'i';

  @override
  String get sendMessage => 'Ergaa ergi';

  @override
  String distanceKmAway(int km) {
    return 'Km $km fagaata';
  }

  @override
  String get enableGps => 'GPS Bani';

  @override
  String get locationDisabledTitle => 'Tajaajila Bakkaa Barbaachisa';

  @override
  String get locationDisabledDesc => 'Namoota dhihoo jiran argachuuf GPS bani.';

  @override
  String get dailyLimitTitle => 'Daangaan jaallachuu har\'aa dhumateera!';

  @override
  String get dailyLimitDesc =>
      'Daangaa jaallachuu guyyaa geesseetta. Fikir Gold fudhadhu ykn hanga haaromutti eegi.';

  @override
  String resetsIn(String time) {
    return 'Gidduu ${time}tti haaroma';
  }

  @override
  String get getFikirGold => 'Fikir Gold Argadhu';

  @override
  String get discoverySettings => 'Qindaa\'ina Sakatta\'iinsaa';

  @override
  String maximumDistance(int distance) {
    return 'Fageenya Ol\'aanaa: $distance km';
  }

  @override
  String ageRangePreference(int min, int max) {
    return 'Umurii: $min - $max';
  }

  @override
  String get showMe => 'Natti Agarsiisi';

  @override
  String get verifiedProfilesOnly => 'Kanneen Mirkanaa\'an Qofa';

  @override
  String get applyFilters => 'Hojiirra Oolchi';

  @override
  String get reportUser => 'Kasaaraa Himadhu';

  @override
  String get blockUser => 'Cufi';

  @override
  String get reportReasonInappropriate => 'Suuraa ykn ibsa hin taane';

  @override
  String get reportReasonSpam => 'Akkaawuntii sobaa';

  @override
  String get reportReasonHarassment => 'Arrabsoo ykn miidhaa';

  @override
  String get reportReasonFake => 'Eenyummaa sobaa';

  @override
  String get reportSubmitted => 'Himannaan dhiyaateera. Galatoomaa.';

  @override
  String get userBlocked => 'Cufameera.';

  @override
  String get soundEnabled => 'Sagaleen Banaadha';

  @override
  String get soundDisabled => 'Sagaleen Cufaadha';

  @override
  String get pullToRefresh => 'Haaromsuuf harkisi';

  @override
  String get likesYouTitle => 'Kanneen Si Jaallatan';

  @override
  String get seeWhoLikesYou => 'Eenyu akka si jaallate ilaali';

  @override
  String get upgradeToGoldLikes =>
      'Hunda argachuuf gara Fikir Gold tti guddisi';

  @override
  String get seeEveryone => 'Hunda Ilaali';

  @override
  String get noLikesYet => 'Ammaaf jaallataan hin jiru';

  @override
  String get noLikesDesc => 'Piroofayilii keessan sochoosaa turaa!';

  @override
  String get newMatches => 'Kanneen Haaraa Wal Qabatan';

  @override
  String get messages => 'Ergaawwan';

  @override
  String get noMatchesYet => 'Hundumti hin jiru';

  @override
  String get noMatchesDesc => 'Namoota dhihoo argachuuf sakatta\'aa!';

  @override
  String get noChatsYet => 'Haasofni hin jiru';

  @override
  String get noChatsDesc => 'Yeroo wal qabattan haasofni asitti mul\'ata.';

  @override
  String get unmatch => 'Addaan Baasi';

  @override
  String unmatchConfirm(String name) {
    return '$name waliin addaan ba\'uu barbaaddaa?';
  }

  @override
  String get typing => 'barreessaa jira...';

  @override
  String get online => 'Toora Irra Jira';

  @override
  String get safetyBannerTitle => 'Gorsa Nageenyaa';

  @override
  String get safetyBannerText =>
      'Qarshii hin erginaa ykn lakkoofsa baankii hin qoodinaa.';

  @override
  String get statusSending => 'Ergamaa jira...';

  @override
  String get statusSent => 'Ergameera';

  @override
  String get statusDelivered => 'Dhaqqabeera';

  @override
  String get statusRead => 'Dubbifameera';

  @override
  String get statusFailed => 'Hin danda\'amne. Irra deebi\'ii.';

  @override
  String get voiceMessage => 'Ergaa Sagalee';

  @override
  String get holdToRecord => 'Waraabuuf qabi, erguuf gad-dhiisi';

  @override
  String recordingVoice(int seconds) {
    return 'Waraabamaa jira... (${seconds}s)';
  }

  @override
  String replyingTo(String name) {
    return '${name}f deebii';
  }

  @override
  String get typeMessage => 'Ergaa barreessi...';

  @override
  String get profileCompleteness => 'Guutummaa Piroofayilii';

  @override
  String get verifyProfile => 'Mirkaneessi';

  @override
  String get verifiedBadge => 'Mirkanaa\'e';

  @override
  String get pendingVerification => 'Gamaaggama Irra';

  @override
  String get verifySubtitle => 'Milikkita buluu argachuuf suuraa ka\'i.';

  @override
  String get takeSelfie => 'Selfie Ka\'i';

  @override
  String get selfieSubmitted => 'Suuraan dhiyaateera. Dhihootti ni ilaalla.';

  @override
  String get dataSaverMode => 'Daataa Qusachuu';

  @override
  String get dataSaverDesc => 'Fayyadamina daataa xiqqeessa';

  @override
  String get notificationSettings => 'Beeksisa';

  @override
  String get notifyNewMatches => 'Kanneen Haaraa';

  @override
  String get notifyNewMessages => 'Ergaawwan Haaraa';

  @override
  String get notifySuperLikes => 'Super Likes';

  @override
  String get privacySettings => 'Iccitii';

  @override
  String get hideDistance => 'Fageenya Dhoksi';

  @override
  String get hideOnlineStatus => 'Toora Irra Dhoksi';

  @override
  String get blockedUsers => 'Kanneen Cufaman';

  @override
  String get noBlockedUsers => 'Eenyullee hin cufne.';

  @override
  String get unblock => 'Bani';

  @override
  String get safetyCenter => 'Wiirtuu Nageenyaa';

  @override
  String get safetyCenterDesc => 'Gorsa nageenyaa Itoophiyaa keessatti';

  @override
  String get emergencyPolice => 'Poolisii Itoophiyaa: 991';

  @override
  String get emergencyRedCross => 'Fannoo Diimaa: 907';

  @override
  String get muteMatch => 'Sagalee Cufi';

  @override
  String get unmuteMatch => 'Sagalee Bani';
}
