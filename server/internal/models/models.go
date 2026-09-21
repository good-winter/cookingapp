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

// NewPreferences 保证数组字段非 nil——nil slice 会序列化成 null，
// 而契约要求空数组输出 []。
func NewPreferences(dietMode string, crowds, avoidFoods []string) Preferences {
	return Preferences{
		DietMode:   dietMode,
		Crowds:     orEmpty(crowds),
		AvoidFoods: orEmpty(avoidFoods),
	}
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

func orEmpty(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}
