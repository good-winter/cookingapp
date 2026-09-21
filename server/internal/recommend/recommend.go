package recommend

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"sort"

	"github.com/good-winter/cookingapp/server/internal/models"
)

var ErrInvalidCursor = errors.New("游标非法或已失效")

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

// cursorPayload 的内容对调用方不透明，只有本包能解释。
type cursorPayload struct {
	Score int    `json:"s"`
	ID    string `json:"i"`
}

func encodeCursor(score int, id string) string {
	raw, _ := json.Marshal(cursorPayload{Score: score, ID: id})
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeCursor(raw string) (cursorPayload, error) {
	data, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil {
		return cursorPayload{}, ErrInvalidCursor
	}
	var p cursorPayload
	if err := json.Unmarshal(data, &p); err != nil || p.ID == "" {
		return cursorPayload{}, ErrInvalidCursor
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
func Page(ranked []Scored, limit int, cursor string) ([]models.Recipe, *string, error) {
	if limit <= 0 {
		limit = DefaultLimit
	}
	if limit > MaxLimit {
		limit = MaxLimit
	}

	start := 0
	if cursor != "" {
		cur, err := decodeCursor(cursor)
		if err != nil {
			return nil, nil, err
		}
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
	next := encodeCursor(last.Score, last.Recipe.ID)
	return items, &next, nil
}
