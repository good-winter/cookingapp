-- 选项字典。新增选项只需在此表加行，前端无需发版。
INSERT INTO diet_modes (code, label, sort_order) VALUES
  ('normal',     '正常人',   1),
  ('vegetarian', '素食主义', 2);

INSERT INTO crowds (code, label, sort_order) VALUES
  ('pregnant', '孕妇',     1),
  ('student',  '学生',     2),
  ('fitness',  '健身人群', 3),
  ('elderly',  '老人',     4),
  ('athlete',  '运动员',   5);

INSERT INTO avoid_foods (code, label, sort_order) VALUES
  ('pork',     '猪肉', 1),
  ('beef',     '牛肉', 2),
  ('seafood',  '海鲜', 3),
  ('cilantro', '香菜', 4),
  ('spicy',    '辛辣', 5);

-- 测试用户。头像用文字代替图片。timezone 决定统计的自然日切分。
INSERT INTO users (id, nickname, avatar_text, timezone) VALUES
  ('u_1', '美食家',   '美', 'Asia/Shanghai'),
  ('u_2', '健身狂人B', '健', 'Asia/Shanghai'),
  ('u_3', '厨房小白C', '厨', 'Asia/Shanghai');

INSERT INTO user_preferences (user_id, diet_mode) VALUES
  ('u_1', 'normal'),
  ('u_2', 'normal'),
  ('u_3', 'normal');

INSERT INTO user_preference_crowds (user_id, crowd) VALUES
  ('u_2', 'fitness'),
  ('u_3', 'student');

-- 开发期 token。多个 token 是为了让前端能验证关注流（关注是用户之间的动作）。
INSERT INTO api_tokens (token, user_id) VALUES
  ('dev-token-user-1', 'u_1'),
  ('dev-token-user-2', 'u_2'),
  ('dev-token-user-3', 'u_3');

-- 菜谱库。营养数据是统计与自动入账的数据源。
-- ⚠️ 以下热量与营养比例为演示用估值，不是营养学准确数据；
--    上线前必须替换为可靠来源（见契约「未决事项」）。
INSERT INTO recipes
  (id, name, emoji, cook_time_minutes, is_vegetarian, calories,
   carbs_percent, protein_percent, fat_percent) VALUES
  ('r_01', '番茄炒蛋',   '🍲', 10, 1, 180, 50, 25, 25),
  ('r_02', '红烧肉',     '🥩', 45, 0, 450, 20, 20, 60),
  ('r_03', '香煎鸡胸肉', '🍗', 15, 0, 250, 15, 55, 30),
  ('r_04', '清蒸鲈鱼',   '🐟', 20, 0, 200, 10, 60, 30),
  ('r_05', '麻婆豆腐',   '🌶️', 15, 0, 280, 25, 25, 50),
  ('r_06', '白灼西兰花', '🥦',  8, 1,  80, 60, 30, 10),
  ('r_07', '清炒时蔬',   '🥬',  8, 1,  90, 65, 20, 15),
  ('r_08', '小米南瓜粥', '🥣', 30, 1, 150, 75, 15, 10),
  ('r_09', '黑椒牛柳',   '🥘', 20, 0, 320, 20, 45, 35),
  ('r_10', '蒜蓉粉丝虾', '🦐', 25, 0, 220, 40, 35, 25),
  ('r_11', '凉拌黄瓜',   '🥒',  5, 1,  60, 70, 15, 15),
  ('r_12', '西红柿牛腩', '🍅', 90, 0, 380, 25, 35, 40);

INSERT INTO recipe_crowds (recipe_id, crowd) VALUES
  ('r_01', 'pregnant'), ('r_01', 'student'),
  ('r_03', 'fitness'),  ('r_03', 'athlete'),
  ('r_04', 'elderly'),  ('r_04', 'pregnant'),
  ('r_05', 'student'),
  ('r_06', 'fitness'),  ('r_06', 'elderly'),
  ('r_08', 'elderly'),  ('r_08', 'pregnant'),
  ('r_09', 'athlete'),
  ('r_11', 'fitness');

INSERT INTO recipe_avoid_tags (recipe_id, avoid_tag) VALUES
  ('r_02', 'pork'),
  ('r_05', 'pork'), ('r_05', 'spicy'),
  ('r_04', 'seafood'),
  ('r_10', 'seafood'),
  ('r_09', 'beef'),
  ('r_12', 'beef');

-- 帖子。created_at 用固定时间而非 NOW()，保证种子数据可复现。
INSERT INTO posts (id, author_id, content, image_emoji, like_count, comment_count, created_at) VALUES
  ('p_01', 'u_2',
   '今天用App的AI识别挑的西红柿，做的番茄炒蛋太香了！AI提示我孕妇要少吃某种香料，真的帮了大忙。',
   '🍲', 128, 45, '2026-09-21 12:00:00'),
  ('p_02', 'u_2',
   '求问：健身完吃这个热量超了吗？App统计说这顿大概350大卡，我觉得还行？',
   '🥗', 12, 89, '2026-09-21 11:00:00'),
  ('p_03', 'u_3',
   '跟着沉浸式做饭模式一步一步来，居然没翻车！语音播报太适合我这种手忙脚乱的人了。',
   '🍳', 56, 23, '2026-09-21 10:00:00');

INSERT INTO post_hashtags (post_id, hashtag) VALUES
  ('p_01', '孕妇餐'),    ('p_01', '快手菜'),     ('p_01', '番茄炒蛋'),
  ('p_02', '减脂餐'),    ('p_02', '低卡'),       ('p_02', '健身'),
  ('p_03', '学生党'),    ('p_03', '新手做饭'),   ('p_03', '沉浸式做饭');

-- u_1 关注 u_2，让「关注」feed 一开始就有内容可验证。
INSERT INTO follows (follower_id, followee_id) VALUES ('u_1', 'u_2');
