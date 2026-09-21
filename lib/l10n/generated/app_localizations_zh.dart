// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settingsTitle => '设置';

  @override
  String get signaturePlaceholder => '点击设置个性签名';

  @override
  String get signatureEditTitle => '编辑个性签名';

  @override
  String get signatureEditHint => '写点什么介绍一下自己';

  @override
  String get actionSave => '保存';

  @override
  String get actionCancel => '取消';

  @override
  String get actionClear => '清除';

  @override
  String get dataManagement => '数据管理';

  @override
  String get dataBuiltIn => 'App 自带的数据';

  @override
  String get dataMine => '我的数据';

  @override
  String get dataRecipeCache => '菜谱库缓存';

  @override
  String get dataRecipeCacheDesc => '清除后下次打开会重新拉取';

  @override
  String get dataMediaCache => '图片与资源缓存';

  @override
  String get dataMediaCacheDesc => '菜谱图片等本地缓存文件';

  @override
  String get dataStats => '统计数据';

  @override
  String get dataMealRecords => '饮食记录';

  @override
  String get dataCommunity => '社区行为';

  @override
  String get dataMyPosts => '我的帖子';

  @override
  String get dataMyComments => '我的发言';

  @override
  String get dataClearConfirmTitle => '确认清除？';

  @override
  String dataClearConfirmMessage(String item) {
    return '「$item」清除后无法恢复。';
  }

  @override
  String get dataCleared => '已清除';

  @override
  String get voice => '语音';

  @override
  String get voiceEnabled => '语音播报';

  @override
  String get voiceEnabledDesc => '做饭步骤朗读';

  @override
  String get voiceRate => '语速';

  @override
  String get voiceRateSlow => '慢';

  @override
  String get voiceRateNormal => '正常';

  @override
  String get voiceRateFast => '快';

  @override
  String get voiceTryListen => '试听';

  @override
  String get voiceSampleText => '番茄炒蛋。先热锅倒油，再下蛋液翻炒，最后加入番茄。';

  @override
  String get voiceUnavailable => '当前设备不支持语音播报';

  @override
  String get voiceDisabledHint => '语音播报已关闭';

  @override
  String get language => '语言';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get appearance => '模式';

  @override
  String get appearanceDay => '白天';

  @override
  String get appearanceNight => '晚上';

  @override
  String get premium => '付费服务';

  @override
  String get premiumCurrentPlan => '当前方案';

  @override
  String get premiumFreePlan => '免费版';

  @override
  String get premiumBenefits => '会员权益';

  @override
  String get premiumBenefitRecognition => '无限次 AI 拍照识别';

  @override
  String get premiumBenefitNutrition => '详细的营养分析报告';

  @override
  String get premiumBenefitHistory => '历史记录无限期保存';

  @override
  String get premiumBenefitAdFree => '全程无广告';

  @override
  String get premiumChoosePlan => '选择方案';

  @override
  String get premiumPlanMonthly => '按月';

  @override
  String get premiumPlanYearly => '按年';

  @override
  String get premiumPlanLifetime => '永久';

  @override
  String get premiumSubscribe => '立即开通';

  @override
  String get premiumComingSoon => '付费功能开发中';
}
