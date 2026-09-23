package recommend

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"sort"

	"github.com/good-winter/cookingapp/server/internal/models"
)

var (
	// ErrInvalidCursor 游标无法解析（不是本服务签发的、或已损坏）。
	ErrInvalidCursor = errors.New("游标非法")
	// ErrStaleCursor 游标能解析，但由另一份偏好签发。
	// 契约要求这种情况返回 400，而不是继续翻出一份错乱的顺序。
	ErrStaleCursor = errors.New("游标已失效")
)

const (
	MaxLimit     = 50
	DefaultLimit = 10
)

type Scored struct {
	Recipe models.Recipe
	Score  int
}

// Rank 按当前偏好过滤并排序菜谱。
// 排序契约：匹配人群数降序，同分按 id 升序 —— 这个全序是游标分页正确性的前提。
func Rank(recipes []models.Recipe, prefs models.Preferences) []Scored {
	out := make([]Scored, 0, len(recipes))
	for _, r := range recipes {
		if prefs.DietMode == "vegetarian" && !r.IsVegetarian {
			continue
		}
		if containsAny(r.AvoidTags, prefs.AvoidFoods) {
			continue
		}
		out = append(out, Scored{Recipe: r, Score: countMatches(r.Crowds, prefs.Crowds)})
	}

	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Score != out[j].Score {
			return out[i].Score > out[j].Score
		}
		return out[i].Recipe.ID < out[j].Recipe.ID
	})
	return out
}

func containsAny(haystack, needles []string) bool {
	for _, n := range needles {
		for _, h := range haystack {
			if h == n {
				return true
			}
		}
	}
	return false
}

func countMatches(haystack, needles []string) int {
	n := 0
	for _, h := range haystack {
		for _, needle := range needles {
			if h == needle {
				n++
				break
			}
		}
	}
	return n
}

// PreferencesFingerprint 把偏好归一化成一个稳定短串，用于把游标绑定到
// 签发它时的那份偏好。
//
// 契约（接口 2 / 接口 4）规定「偏好变更后此前签发的 cursor 失效，携带过期
// 游标返回 400 INVALID_PARAMETER」。游标里不带偏好信息时，服务端无从判断
// 失效，只能静默返回一份错乱的顺序——这正是该条款要避免的情况。
//
// 先排序再哈希：前端换个顺序提交同一组偏好，语义没变，游标不该被判失效。
func PreferencesFingerprint(prefs models.Preferences) string {
	normalized := struct {
		DietMode   string   `json:"dietMode"`
		Crowds     []string `json:"crowds"`
		AvoidFoods []string `json:"avoidFoods"`
	}{
		DietMode:   prefs.DietMode,
		Crowds:     sortedCopy(prefs.Crowds),
		AvoidFoods: sortedCopy(prefs.AvoidFoods),
	}
	raw, err := json.Marshal(normalized)
	if err != nil {
		// 结构里只有 string 与 []string，Marshal 不可能失败。
		return ""
	}
	sum := sha256.Sum256(raw)
	return base64.RawURLEncoding.EncodeToString(sum[:8])
}

// sortedCopy 排序副本，不改动入参；nil 输入返回空切片。
// 归一化后 nil 与空切片哈希一致，避免「没选任何人群」和「人群字段缺失」
// 被算成两份不同的偏好。
func sortedCopy(values []string) []string {
	out := make([]string, 0, len(values))
	out = append(out, values...)
	sort.Strings(out)
	return out
}

// cursorPayload 的内容对调用方不透明，只有本包能解释。
type cursorPayload struct {
	Score int    `json:"s"`
	ID    string `json:"i"`
	Pref  string `json:"p"` // 签发该游标时的偏好指纹
}

func encodeCursor(score int, id, prefsFingerprint string) string {
	raw, _ := json.Marshal(cursorPayload{Score: score, ID: id, Pref: prefsFingerprint})
	return base64.RawURLEncoding.EncodeToString(raw)
}

// decodeCursor 解出游标，并校验它确由当前偏好签发。
// 指纹不符说明偏好已变，返回 ErrStaleCursor 由上层映射为 400。
func decodeCursor(raw, prefsFingerprint string) (cursorPayload, error) {
	data, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil {
		return cursorPayload{}, ErrInvalidCursor
	}
	var p cursorPayload
	if err := json.Unmarshal(data, &p); err != nil || p.ID == "" {
		return cursorPayload{}, ErrInvalidCursor
	}
	if p.Pref != prefsFingerprint {
		return cursorPayload{}, ErrStaleCursor
	}
	return p, nil
}

// comesAfter 判断 item 在排序中是否严格位于 cur 之后。
func comesAfter(item Scored, cur cursorPayload) bool {
	if item.Score != cur.Score {
		return item.Score < cur.Score // 分数降序
	}
	return item.Recipe.ID > cur.ID // 同分按 id 升序
}

// Page 从已排序结果中切出一页。nextCursor 为 nil 表示没有下一页。
//
// prefs 必须与算出 ranked 的那份偏好一致：游标绑定它的指纹，偏好一变旧游标
// 即被拒（ErrStaleCursor）。把 prefs 收进签名而不是让调用方自己传指纹，
// 是为了让「忘记绑定」这件事无法发生。
func Page(
	ranked []Scored, limit int, cursor string, prefs models.Preferences,
) ([]models.Recipe, *string, error) {
	if limit <= 0 {
		limit = DefaultLimit
	}
	if limit > MaxLimit {
		limit = MaxLimit
	}

	fingerprint := PreferencesFingerprint(prefs)

	start := 0
	if cursor != "" {
		cur, err := decodeCursor(cursor, fingerprint)
		if err != nil {
			return nil, nil, err
		}
		// 按排序键定位，而不是按偏移量。菜谱库增删条目时游标仍落在正确
		// 位置，不会重复或漏页——只有排序键本身变了才需要判失效。
		for start < len(ranked) && !comesAfter(ranked[start], cur) {
			start++
		}
	}

	end := start + limit
	if end > len(ranked) {
		end = len(ranked)
	}

	items := make([]models.Recipe, 0, end-start)
	for _, s := range ranked[start:end] {
		items = append(items, s.Recipe)
	}

	if end >= len(ranked) {
		return items, nil, nil
	}
	last := ranked[end-1]
	next := encodeCursor(last.Score, last.Recipe.ID, fingerprint)
	return items, &next, nil
}
