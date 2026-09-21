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

  /// 设置页标题，也是底部导航第四个 Tab 的名字（底部导航暂未接入 i18n）
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
