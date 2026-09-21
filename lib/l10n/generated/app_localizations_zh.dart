// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'AI 智能做饭';

  @override
  String get navCooking => '烹饪';

  @override
  String get navCommunity => '社区';

  @override
  String get navStatistics => '统计';

  @override
  String get greetingMorning => '早上好';

  @override
  String get greetingNoon => '中午好';

  @override
  String get greetingEvening => '晚上好';

  @override
  String get cookingSubtitle => '今天想做点什么？';

  @override
  String get cookingCameraTitle => 'AI 拍照识别食材';

  @override
  String get cookingCameraSubtitle => '自动判断荤素与新鲜度，保障饮食安全';

  @override
  String get cookingRecommendTitle => '🔥 为你推荐';

  @override
  String get cookingRecommendAll => '(综合推荐)';

  @override
  String cookingRecommendFor(String crowds) {
    return '(适配: $crowds)';
  }

  @override
  String get cookingNoResults => '没有找到符合您当前偏好的菜谱。';

  @override
  String get prefsTitle => '设置我的饮食偏好';

  @override
  String get prefsSectionDiet => '1. 饮食习惯';

  @override
  String get prefsSectionCrowd => '2. 我属于 (人群)';

  @override
  String get prefsSectionAvoid => '3. 我不吃 (忌口/过敏)';

  @override
  String get prefsSave => '保存并更新推荐';

  @override
  String get dietNormal => '正常人';

  @override
  String get dietVegetarian => '素食主义';

  @override
  String get crowdPregnant => '孕妇';

  @override
  String get crowdStudent => '学生';

  @override
  String get crowdFitness => '健身人群';

  @override
  String get crowdElderly => '老人';

  @override
  String get crowdAthlete => '运动员';

  @override
  String get avoidPork => '猪肉';

  @override
  String get avoidBeef => '牛肉';

  @override
  String get avoidSeafood => '海鲜';

  @override
  String get avoidCilantro => '香菜';

  @override
  String get avoidSpicy => '辛辣';

  @override
  String get followButton => '+ 关注';

  @override
  String get followingButton => '已关注';

  @override
  String get feedRecommend => '推荐';

  @override
  String get feedFollowing => '关注';

  @override
  String get feedNearby => '同城';

  @override
  String get publishSuccess => '发布成功！';

  @override
  String get createPostTitle => '发布动态';

  @override
  String get createPostPublish => '发布';

  @override
  String get createPostHint => '分享你的做饭心得、成果或求助...';

  @override
  String get createPostEmpty => '写点什么再发布吧~';

  @override
  String get createPostAddImage => '添加图片';

  @override
  String get createPostImagePickerWip => '图片选择器开发中（后续可接入 image_picker）';

  @override
  String get createPostAddTopic => '添加话题';

  @override
  String get createPostFooter => '友善发言，分享美好食光 ✨';

  @override
  String get statsDatePickerWip => '日期选择功能开发中...';

  @override
  String get statsMonth => '2026年9月';

  @override
  String get statsTodayIntake => '今日摄入';

  @override
  String get statsWeekAverage => '本周平均';

  @override
  String get statsCalorieTrend => '📈 近两周热量趋势';

  @override
  String get statsNutrition => '🍩 营养均衡度';

  @override
  String get statsCarbs => '碳水';

  @override
  String get statsProtein => '蛋白质';

  @override
  String get statsFat => '脂肪';

  @override
  String get statsHistory => '📋 历史记录';

  @override
  String get statsRetention => '数据保存时间: 永久保存 (点击修改)';

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
