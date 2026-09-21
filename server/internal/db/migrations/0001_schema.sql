-- 用户。timezone 为 IANA 标识，统计接口按它切分自然日。
CREATE TABLE IF NOT EXISTS users (
  id          VARCHAR(32)  NOT NULL PRIMARY KEY,
  nickname    VARCHAR(64)  NOT NULL,
  avatar_text VARCHAR(8)   NOT NULL,
  timezone    VARCHAR(64)  NOT NULL DEFAULT 'Asia/Shanghai',
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 开发期测试 token。将来换成 JWT 时替换本表与中间件实现即可，接口形状不变。
CREATE TABLE IF NOT EXISTS api_tokens (
  token      VARCHAR(128) NOT NULL PRIMARY KEY,
  user_id    VARCHAR(32)  NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 偏好选项字典：下发到前端，新增选项属数据变更，无需发版。
CREATE TABLE IF NOT EXISTS diet_modes (
  code       VARCHAR(32) NOT NULL PRIMARY KEY,
  label      VARCHAR(32) NOT NULL,
  sort_order INT         NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS crowds (
  code       VARCHAR(32) NOT NULL PRIMARY KEY,
  label      VARCHAR(32) NOT NULL,
  sort_order INT         NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS avoid_foods (
  code       VARCHAR(32) NOT NULL PRIMARY KEY,
  label      VARCHAR(32) NOT NULL,
  sort_order INT         NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id    VARCHAR(32) NOT NULL PRIMARY KEY,
  diet_mode  VARCHAR(32) NOT NULL DEFAULT 'normal',
  updated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_prefs_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_preference_crowds (
  user_id VARCHAR(32) NOT NULL,
  crowd   VARCHAR(32) NOT NULL,
  PRIMARY KEY (user_id, crowd),
  CONSTRAINT fk_upc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_preference_avoids (
  user_id    VARCHAR(32) NOT NULL,
  avoid_food VARCHAR(32) NOT NULL,
  PRIMARY KEY (user_id, avoid_food),
  CONSTRAINT fk_upa_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 菜谱库。营养数据为统计与自动入账的数据源，不可为空。
CREATE TABLE IF NOT EXISTS recipes (
  id                VARCHAR(32)  NOT NULL PRIMARY KEY,
  name              VARCHAR(64)  NOT NULL,
  emoji             VARCHAR(16)  NOT NULL,
  image_url         VARCHAR(255) NULL,
  cook_time_minutes INT          NOT NULL,
  is_vegetarian     TINYINT(1)   NOT NULL DEFAULT 0,
  calories          INT          NOT NULL,
  carbs_percent     INT          NOT NULL,
  protein_percent   INT          NOT NULL,
  fat_percent       INT          NOT NULL,
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recipe_crowds (
  recipe_id VARCHAR(32) NOT NULL,
  crowd     VARCHAR(32) NOT NULL,
  PRIMARY KEY (recipe_id, crowd),
  CONSTRAINT fk_rc_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recipe_avoid_tags (
  recipe_id VARCHAR(32) NOT NULL,
  avoid_tag VARCHAR(32) NOT NULL,
  PRIMARY KEY (recipe_id, avoid_tag),
  CONSTRAINT fk_rat_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS posts (
  id            VARCHAR(32)  NOT NULL PRIMARY KEY,
  author_id     VARCHAR(32)  NOT NULL,
  content       TEXT         NOT NULL,
  image_emoji   VARCHAR(16)  NOT NULL DEFAULT '',
  image_url     VARCHAR(255) NULL,
  like_count    INT          NOT NULL DEFAULT 0,
  comment_count INT          NOT NULL DEFAULT 0,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_posts_author FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_posts_created (created_at DESC, id DESC),
  INDEX idx_posts_author (author_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS post_hashtags (
  post_id  VARCHAR(32) NOT NULL,
  hashtag  VARCHAR(64) NOT NULL,
  PRIMARY KEY (post_id, hashtag),
  CONSTRAINT fk_ph_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS follows (
  follower_id VARCHAR(32) NOT NULL,
  followee_id VARCHAR(32) NOT NULL,
  created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (follower_id, followee_id),
  CONSTRAINT fk_follows_follower FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_follows_followee FOREIGN KEY (followee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 饮食记录。created_at 是全序排序键（游标分页依赖它）；
-- eaten_on 是用户本地时区的自然日，供统计聚合使用。
-- 营养百分比在入账时快照下来，避免日后改菜谱导致历史数据漂移。
CREATE TABLE IF NOT EXISTS meal_records (
  id                VARCHAR(32) NOT NULL PRIMARY KEY,
  user_id           VARCHAR(32) NOT NULL,
  recipe_id         VARCHAR(32) NULL,
  recipe_name       VARCHAR(64) NOT NULL,
  emoji             VARCHAR(16) NOT NULL DEFAULT '',
  calories          INT         NOT NULL,
  carbs_percent     INT         NOT NULL,
  protein_percent   INT         NOT NULL,
  fat_percent       INT         NOT NULL,
  nutrition_source  VARCHAR(16) NOT NULL,
  eaten_on          DATE        NOT NULL,
  created_at        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_meals_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_meals_user_created (user_id, created_at DESC, id DESC),
  INDEX idx_meals_user_date (user_id, eaten_on)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 记录已执行的迁移，保证重复启动幂等。
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename   VARCHAR(128) NOT NULL PRIMARY KEY,
  applied_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
