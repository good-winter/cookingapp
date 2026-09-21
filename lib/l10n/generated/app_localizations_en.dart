// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Cooking';

  @override
  String get navCooking => 'Cooking';

  @override
  String get navCommunity => 'Community';

  @override
  String get navStatistics => 'Stats';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingNoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get cookingSubtitle => 'What are we cooking today?';

  @override
  String get cookingCameraTitle => 'Snap to identify ingredients';

  @override
  String get cookingCameraSubtitle =>
      'Detects ingredients and freshness automatically';

  @override
  String get cookingRecommendTitle => '🔥 Recommended';

  @override
  String get cookingRecommendAll => '(General)';

  @override
  String cookingRecommendFor(String crowds) {
    return '(For: $crowds)';
  }

  @override
  String get cookingNoResults => 'No recipes match your preferences.';

  @override
  String get prefsTitle => 'Diet preferences';

  @override
  String get prefsSectionDiet => '1. Diet';

  @override
  String get prefsSectionCrowd => '2. I am (group)';

  @override
  String get prefsSectionAvoid => '3. I avoid (allergies)';

  @override
  String get prefsSave => 'Save and update';

  @override
  String get dietNormal => 'Standard';

  @override
  String get dietVegetarian => 'Vegetarian';

  @override
  String get crowdPregnant => 'Pregnant';

  @override
  String get crowdStudent => 'Student';

  @override
  String get crowdFitness => 'Fitness';

  @override
  String get crowdElderly => 'Elderly';

  @override
  String get crowdAthlete => 'Athlete';

  @override
  String get avoidPork => 'Pork';

  @override
  String get avoidBeef => 'Beef';

  @override
  String get avoidSeafood => 'Seafood';

  @override
  String get avoidCilantro => 'Cilantro';

  @override
  String get avoidSpicy => 'Spicy';

  @override
  String get followButton => '+ Follow';

  @override
  String get followingButton => 'Following';

  @override
  String get feedRecommend => 'For you';

  @override
  String get feedFollowing => 'Following';

  @override
  String get feedNearby => 'Local';

  @override
  String get publishSuccess => 'Posted!';

  @override
  String get createPostTitle => 'New post';

  @override
  String get createPostPublish => 'Post';

  @override
  String get createPostHint =>
      'Share your cooking tips, results, or questions...';

  @override
  String get createPostEmpty => 'Write something first~';

  @override
  String get createPostAddImage => 'Add photos';

  @override
  String get createPostImagePickerWip =>
      'Photo picker is not ready yet (will use image_picker)';

  @override
  String get createPostAddTopic => 'Add topics';

  @override
  String get createPostFooter => 'Be kind, share the good food ✨';

  @override
  String get statsDatePickerWip => 'Date picker is not ready yet...';

  @override
  String get statsMonth => 'September 2026';

  @override
  String get statsTodayIntake => 'Today\'s intake';

  @override
  String get statsWeekAverage => 'Weekly average';

  @override
  String get statsCalorieTrend => '📈 Calories, last two weeks';

  @override
  String get statsNutrition => '🍩 Nutrition balance';

  @override
  String get statsCarbs => 'Carbs';

  @override
  String get statsProtein => 'Protein';

  @override
  String get statsFat => 'Fat';

  @override
  String get statsHistory => '📋 History';

  @override
  String get statsRetention => 'Retention: forever (tap to change)';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get signaturePlaceholder => 'Tap to set a status';

  @override
  String get signatureEditTitle => 'Edit status';

  @override
  String get signatureEditHint => 'Say something about yourself';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClear => 'Clear';

  @override
  String get dataManagement => 'Data';

  @override
  String get dataBuiltIn => 'Built-in data';

  @override
  String get dataMine => 'My data';

  @override
  String get dataRecipeCache => 'Recipe cache';

  @override
  String get dataRecipeCacheDesc => 'Recipes will be fetched again next time';

  @override
  String get dataMediaCache => 'Image & asset cache';

  @override
  String get dataMediaCacheDesc => 'Cached recipe images and local files';

  @override
  String get dataStats => 'Statistics';

  @override
  String get dataMealRecords => 'Meal records';

  @override
  String get dataCommunity => 'Community activity';

  @override
  String get dataMyPosts => 'My posts';

  @override
  String get dataMyComments => 'My replies';

  @override
  String get dataClearConfirmTitle => 'Clear this data?';

  @override
  String dataClearConfirmMessage(String item) {
    return '\"$item\" cannot be recovered once cleared.';
  }

  @override
  String get dataCleared => 'Cleared';

  @override
  String get voice => 'Voice';

  @override
  String get voiceEnabled => 'Voice narration';

  @override
  String get voiceEnabledDesc => 'Read cooking steps aloud';

  @override
  String get voiceRate => 'Speech rate';

  @override
  String get voiceRateSlow => 'Slow';

  @override
  String get voiceRateNormal => 'Normal';

  @override
  String get voiceRateFast => 'Fast';

  @override
  String get voiceTryListen => 'Preview';

  @override
  String get voiceSampleText =>
      'Tomato scrambled eggs. Heat the pan, add oil, pour in the beaten eggs, then add the tomatoes.';

  @override
  String get voiceUnavailable =>
      'Voice narration is not supported on this device';

  @override
  String get voiceDisabledHint => 'Voice narration is turned off';

  @override
  String get language => 'Language';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceDay => 'Day';

  @override
  String get appearanceNight => 'Night';

  @override
  String get premium => 'Premium';

  @override
  String get premiumCurrentPlan => 'Current plan';

  @override
  String get premiumFreePlan => 'Free';

  @override
  String get premiumBenefits => 'What you get';

  @override
  String get premiumBenefitRecognition => 'Unlimited AI food recognition';

  @override
  String get premiumBenefitNutrition => 'Detailed nutrition reports';

  @override
  String get premiumBenefitHistory => 'Unlimited history retention';

  @override
  String get premiumBenefitAdFree => 'No ads';

  @override
  String get premiumChoosePlan => 'Choose a plan';

  @override
  String get premiumPlanMonthly => 'Monthly';

  @override
  String get premiumPlanYearly => 'Yearly';

  @override
  String get premiumPlanLifetime => 'Lifetime';

  @override
  String get premiumSubscribe => 'Subscribe';

  @override
  String get premiumComingSoon => 'Payments are not available yet';
}
