import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('en'),
    Locale('zh')
  ];

  /// App 名称，用于系统任务切换器
  ///
  /// In zh, this message translates to:
  /// **'AI 智能做饭'**
  String get appTitle;

  /// 底部导航第 1 个 Tab
  ///
  /// In zh, this message translates to:
  /// **'烹饪'**
  String get navCooking;

  /// 底部导航第 2 个 Tab，也是社区页标题
  ///
  /// In zh, this message translates to:
  /// **'社区'**
  String get navCommunity;

  /// 底部导航第 3 个 Tab，也是统计页标题
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get navStatistics;

  /// 5:00-11:59 的问候语
  ///
  /// In zh, this message translates to:
  /// **'早上好'**
  String get greetingMorning;

  /// 12:00-17:59 的问候语
  ///
  /// In zh, this message translates to:
  /// **'中午好'**
  String get greetingNoon;

  /// 18:00-次日 4:59 的问候语
  ///
  /// In zh, this message translates to:
  /// **'晚上好'**
  String get greetingEvening;

  /// 烹饪页问候语下方的小字
  ///
  /// In zh, this message translates to:
  /// **'今天想做点什么？'**
  String get cookingSubtitle;

  /// 拍照识别区域的主标题
  ///
  /// In zh, this message translates to:
  /// **'AI 拍照识别食材'**
  String get cookingCameraTitle;

  /// 拍照识别区域的副标题
  ///
  /// In zh, this message translates to:
  /// **'自动判断荤素与新鲜度，保障饮食安全'**
  String get cookingCameraSubtitle;

  /// 推荐区标题
  ///
  /// In zh, this message translates to:
  /// **'🔥 为你推荐'**
  String get cookingRecommendTitle;

  /// 未选人群时的推荐说明
  ///
  /// In zh, this message translates to:
  /// **'(综合推荐)'**
  String get cookingRecommendAll;

  /// 已选人群时的推荐说明
  ///
  /// In zh, this message translates to:
  /// **'(适配: {crowds})'**
  String cookingRecommendFor(String crowds);

  /// 筛完没有结果时的空态文案
  ///
  /// In zh, this message translates to:
  /// **'没有找到符合您当前偏好的菜谱。'**
  String get cookingNoResults;

  /// 饮食偏好弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'设置我的饮食偏好'**
  String get prefsTitle;

  /// 偏好弹窗第 1 栏
  ///
  /// In zh, this message translates to:
  /// **'1. 饮食习惯'**
  String get prefsSectionDiet;

  /// 偏好弹窗第 2 栏
  ///
  /// In zh, this message translates to:
  /// **'2. 我属于 (人群)'**
  String get prefsSectionCrowd;

  /// 偏好弹窗第 3 栏
  ///
  /// In zh, this message translates to:
  /// **'3. 我不吃 (忌口/过敏)'**
  String get prefsSectionAvoid;

  /// 偏好弹窗保存按钮
  ///
  /// In zh, this message translates to:
  /// **'保存并更新推荐'**
  String get prefsSave;

  /// 枚举显示名。⚠️ 只改这里不影响存储值与匹配逻辑
  ///
  /// In zh, this message translates to:
  /// **'正常人'**
  String get dietNormal;

  /// 枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'素食主义'**
  String get dietVegetarian;

  /// 人群枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'孕妇'**
  String get crowdPregnant;

  /// 人群枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'学生'**
  String get crowdStudent;

  /// 人群枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'健身人群'**
  String get crowdFitness;

  /// 人群枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'老人'**
  String get crowdElderly;

  /// 人群枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'运动员'**
  String get crowdAthlete;

  /// 忌口枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'猪肉'**
  String get avoidPork;

  /// 忌口枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'牛肉'**
  String get avoidBeef;

  /// 忌口枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'海鲜'**
  String get avoidSeafood;

  /// 忌口枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'香菜'**
  String get avoidCilantro;

  /// 忌口枚举显示名
  ///
  /// In zh, this message translates to:
  /// **'辛辣'**
  String get avoidSpicy;

  /// 帖子卡片的关注按钮
  ///
  /// In zh, this message translates to:
  /// **'+ 关注'**
  String get followButton;

  /// 已关注状态
  ///
  /// In zh, this message translates to:
  /// **'已关注'**
  String get followingButton;

  /// 社区第 1 个 Tab
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get feedRecommend;

  /// 社区第 2 个 Tab
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get feedFollowing;

  /// 社区第 3 个 Tab。契约决策 #5 已砍掉同城，接入接口时一并移除
  ///
  /// In zh, this message translates to:
  /// **'同城'**
  String get feedNearby;

  /// 发帖成功提示
  ///
  /// In zh, this message translates to:
  /// **'发布成功！'**
  String get publishSuccess;

  /// 发帖页标题
  ///
  /// In zh, this message translates to:
  /// **'发布动态'**
  String get createPostTitle;

  /// 发帖按钮
  ///
  /// In zh, this message translates to:
  /// **'发布'**
  String get createPostPublish;

  /// 发帖输入框占位
  ///
  /// In zh, this message translates to:
  /// **'分享你的做饭心得、成果或求助...'**
  String get createPostHint;

  /// 内容为空时的提示
  ///
  /// In zh, this message translates to:
  /// **'写点什么再发布吧~'**
  String get createPostEmpty;

  /// 图片区标题
  ///
  /// In zh, this message translates to:
  /// **'添加图片'**
  String get createPostAddImage;

  /// 图片选择占位提示
  ///
  /// In zh, this message translates to:
  /// **'图片选择器开发中（后续可接入 image_picker）'**
  String get createPostImagePickerWip;

  /// 话题区标题
  ///
  /// In zh, this message translates to:
  /// **'添加话题'**
  String get createPostAddTopic;

  /// 发帖页底部提示
  ///
  /// In zh, this message translates to:
  /// **'友善发言，分享美好食光 ✨'**
  String get createPostFooter;

  /// 日期选择占位提示
  ///
  /// In zh, this message translates to:
  /// **'日期选择功能开发中...'**
  String get statsDatePickerWip;

  /// 顶栏日期占位，接入接口后改为动态
  ///
  /// In zh, this message translates to:
  /// **'2026年9月'**
  String get statsMonth;

  /// 概览卡片 1
  ///
  /// In zh, this message translates to:
  /// **'今日摄入'**
  String get statsTodayIntake;

  /// 概览卡片 2
  ///
  /// In zh, this message translates to:
  /// **'本周平均'**
  String get statsWeekAverage;

  /// 柱状图标题
  ///
  /// In zh, this message translates to:
  /// **'📈 近两周热量趋势'**
  String get statsCalorieTrend;

  /// 环形图标题
  ///
  /// In zh, this message translates to:
  /// **'🍩 营养均衡度'**
  String get statsNutrition;

  /// 营养图例
  ///
  /// In zh, this message translates to:
  /// **'碳水'**
  String get statsCarbs;

  /// 营养图例
  ///
  /// In zh, this message translates to:
  /// **'蛋白质'**
  String get statsProtein;

  /// 营养图例
  ///
  /// In zh, this message translates to:
  /// **'脂肪'**
  String get statsFat;

  /// 历史记录标题
  ///
  /// In zh, this message translates to:
  /// **'📋 历史记录'**
  String get statsHistory;

  /// 数据保留策略提示，属服务端策略，暂未接入
  ///
  /// In zh, this message translates to:
  /// **'数据保存时间: 永久保存 (点击修改)'**
  String get statsRetention;

  /// 设置页标题，也是底部导航第 4 个 Tab 的名字
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// 个性签名为空时，用户信息卡里的提示文案
  ///
  /// In zh, this message translates to:
  /// **'点击设置个性签名'**
  String get signaturePlaceholder;

  /// 编辑个性签名弹窗的标题
  ///
  /// In zh, this message translates to:
  /// **'编辑个性签名'**
  String get signatureEditTitle;

  /// 个性签名输入框的占位提示
  ///
  /// In zh, this message translates to:
  /// **'写点什么介绍一下自己'**
  String get signatureEditHint;

  /// 通用保存按钮
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get actionSave;

  /// 通用取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get actionCancel;

  /// 数据管理里的清除按钮
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get actionClear;

  /// 设置页栏目名，也是子页标题
  ///
  /// In zh, this message translates to:
  /// **'数据管理'**
  String get dataManagement;

  /// 数据管理第一组：应用自带数据
  ///
  /// In zh, this message translates to:
  /// **'App 自带的数据'**
  String get dataBuiltIn;

  /// 数据管理第二组：用户产生的数据
  ///
  /// In zh, this message translates to:
  /// **'我的数据'**
  String get dataMine;

  /// 可清除项
  ///
  /// In zh, this message translates to:
  /// **'菜谱库缓存'**
  String get dataRecipeCache;

  /// 菜谱库缓存的说明
  ///
  /// In zh, this message translates to:
  /// **'清除后下次打开会重新拉取'**
  String get dataRecipeCacheDesc;

  /// 可清除项
  ///
  /// In zh, this message translates to:
  /// **'图片与资源缓存'**
  String get dataMediaCache;

  /// 图片缓存的说明
  ///
  /// In zh, this message translates to:
  /// **'菜谱图片等本地缓存文件'**
  String get dataMediaCacheDesc;

  /// 用户数据分组：统计
  ///
  /// In zh, this message translates to:
  /// **'统计数据'**
  String get dataStats;

  /// 可清除项：识别入账产生的记录
  ///
  /// In zh, this message translates to:
  /// **'饮食记录'**
  String get dataMealRecords;

  /// 用户数据分组：社区
  ///
  /// In zh, this message translates to:
  /// **'社区行为'**
  String get dataCommunity;

  /// 可清除项
  ///
  /// In zh, this message translates to:
  /// **'我的帖子'**
  String get dataMyPosts;

  /// 可清除项
  ///
  /// In zh, this message translates to:
  /// **'我的发言'**
  String get dataMyComments;

  /// 清除二次确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'确认清除？'**
  String get dataClearConfirmTitle;

  /// 清除二次确认弹窗正文
  ///
  /// In zh, this message translates to:
  /// **'「{item}」清除后无法恢复。'**
  String dataClearConfirmMessage(String item);

  /// 清除完成提示
  ///
  /// In zh, this message translates to:
  /// **'已清除'**
  String get dataCleared;

  /// 设置页栏目名，也是子页标题
  ///
  /// In zh, this message translates to:
  /// **'语音'**
  String get voice;

  /// 语音播报开关
  ///
  /// In zh, this message translates to:
  /// **'语音播报'**
  String get voiceEnabled;

  /// 语音播报开关的说明
  ///
  /// In zh, this message translates to:
  /// **'做饭步骤朗读'**
  String get voiceEnabledDesc;

  /// 语速设置分组标题
  ///
  /// In zh, this message translates to:
  /// **'语速'**
  String get voiceRate;

  /// 语速档位
  ///
  /// In zh, this message translates to:
  /// **'慢'**
  String get voiceRateSlow;

  /// 语速档位
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get voiceRateNormal;

  /// 语速档位
  ///
  /// In zh, this message translates to:
  /// **'快'**
  String get voiceRateFast;

  /// 播放一段样例语音
  ///
  /// In zh, this message translates to:
  /// **'试听'**
  String get voiceTryListen;

  /// 试听时朗读的样例文案
  ///
  /// In zh, this message translates to:
  /// **'番茄炒蛋。先热锅倒油，再下蛋液翻炒，最后加入番茄。'**
  String get voiceSampleText;

  /// TTS 初始化失败时的提示
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持语音播报'**
  String get voiceUnavailable;

  /// 开关关闭时点试听的提示
  ///
  /// In zh, this message translates to:
  /// **'语音播报已关闭'**
  String get voiceDisabledHint;

  /// 设置页栏目名，也是子页标题
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// 语言选项：中文。用中文本身书写，不随界面语言变化
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// 语言选项：英文。用英文本身书写，不随界面语言变化
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEn;

  /// 设置页栏目名，也是子页标题
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String get appearance;

  /// 浅色模式
  ///
  /// In zh, this message translates to:
  /// **'白天'**
  String get appearanceDay;

  /// 深色模式
  ///
  /// In zh, this message translates to:
  /// **'晚上'**
  String get appearanceNight;

  /// 设置页栏目名，也是子页标题
  ///
  /// In zh, this message translates to:
  /// **'付费服务'**
  String get premium;

  /// 会员卡上的标签
  ///
  /// In zh, this message translates to:
  /// **'当前方案'**
  String get premiumCurrentPlan;

  /// 未付费用户的方案名
  ///
  /// In zh, this message translates to:
  /// **'免费版'**
  String get premiumFreePlan;

  /// 权益列表标题
  ///
  /// In zh, this message translates to:
  /// **'会员权益'**
  String get premiumBenefits;

  /// 权益项
  ///
  /// In zh, this message translates to:
  /// **'无限次 AI 拍照识别'**
  String get premiumBenefitRecognition;

  /// 权益项
  ///
  /// In zh, this message translates to:
  /// **'详细的营养分析报告'**
  String get premiumBenefitNutrition;

  /// 权益项
  ///
  /// In zh, this message translates to:
  /// **'历史记录无限期保存'**
  String get premiumBenefitHistory;

  /// 权益项
  ///
  /// In zh, this message translates to:
  /// **'全程无广告'**
  String get premiumBenefitAdFree;

  /// 价格档位分组标题
  ///
  /// In zh, this message translates to:
  /// **'选择方案'**
  String get premiumChoosePlan;

  /// 价格档位
  ///
  /// In zh, this message translates to:
  /// **'按月'**
  String get premiumPlanMonthly;

  /// 价格档位
  ///
  /// In zh, this message translates to:
  /// **'按年'**
  String get premiumPlanYearly;

  /// 价格档位
  ///
  /// In zh, this message translates to:
  /// **'永久'**
  String get premiumPlanLifetime;

  /// 开通按钮
  ///
  /// In zh, this message translates to:
  /// **'立即开通'**
  String get premiumSubscribe;

  /// 点击开通后的提示，本期只做图形界面
  ///
  /// In zh, this message translates to:
  /// **'付费功能开发中'**
  String get premiumComingSoon;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
