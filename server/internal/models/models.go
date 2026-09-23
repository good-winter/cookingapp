package models

type User struct {
	ID          string      `json:"id"`
	Nickname    string      `json:"nickname"`
	AvatarText  string      `json:"avatarText"`
	Timezone    string      `json:"timezone"`
	Preferences Preferences `json:"preferences"`
}

type Preferences struct {
	DietMode   string   `json:"dietMode"`
	Crowds     []string `json:"crowds"`
	AvoidFoods []string `json:"avoidFoods"`
}

// NewPreferences 规整调用方传来的偏好，做两件事：
//
//  1. 保证数组字段非 nil——nil slice 会序列化成 null，而契约要求空数组输出 []。
//  2. 去重。两个数组在语义上是集合（库里 user_preference_crowds 的主键就是
//     (user_id, crowd)），重复值会撞主键让整个 PUT 事务失败并冒成 500。
//     在这里收口，比让每个调用方各自记得去重更可靠。
//
// 去重同时保证了「回显的偏好」与「落库的偏好」逐项一致——顺序保留首次出现，
// 前端不必重排。
func NewPreferences(dietMode string, crowds, avoidFoods []string) Preferences {
	return Preferences{
		DietMode:   dietMode,
		Crowds:     dedupe(crowds),
		AvoidFoods: dedupe(avoidFoods),
	}
}

// dedupe 去重并保持首次出现的顺序；nil 输入返回空切片而非 nil。
func dedupe(values []string) []string {
	out := make([]string, 0, len(values))
	seen := make(map[string]struct{}, len(values))
	for _, v := range values {
		if _, dup := seen[v]; dup {
			continue
		}
		seen[v] = struct{}{}
		out = append(out, v)
	}
	return out
}

type Nutrition struct {
	CarbsPercent   int `json:"carbsPercent"`
	ProteinPercent int `json:"proteinPercent"`
	FatPercent     int `json:"fatPercent"`
}

type Recipe struct {
	ID              string    `json:"id"`
	Name            string    `json:"name"`
	Emoji           string    `json:"emoji"`
	ImageURL        *string   `json:"imageUrl"`
	CookTimeMinutes int       `json:"cookTimeMinutes"`
	IsVegetarian    bool      `json:"isVegetarian"`
	Crowds          []string  `json:"crowds"`
	AvoidTags       []string  `json:"avoidTags"`
	Calories        int       `json:"calories"`
	Nutrition       Nutrition `json:"nutrition"`
}

type Option struct {
	Code  string `json:"code"`
	Label string `json:"label"`
}

type PreferenceOptions struct {
	DietModes  []Option `json:"dietModes"`
	Crowds     []Option `json:"crowds"`
	AvoidFoods []Option `json:"avoidFoods"`
}

// Normalized 保证三个数组字段非 nil。
// 契约要求空数组序列化为 []，而零值 struct 的三个字段都是 nil —— 会在边界上
// 输出 null。在 handler 出口调用它，使这条保证不依赖 store 实现是否记得初始化。
func (o PreferenceOptions) Normalized() PreferenceOptions {
	return PreferenceOptions{
		DietModes:  orEmptyOptions(o.DietModes),
		Crowds:     orEmptyOptions(o.Crowds),
		AvoidFoods: orEmptyOptions(o.AvoidFoods),
	}
}

func orEmptyOptions(s []Option) []Option {
	if s == nil {
		return []Option{}
	}
	return s
}
