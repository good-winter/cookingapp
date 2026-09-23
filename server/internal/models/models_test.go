package models

import "testing"

// 偏好是集合语义：库里 user_preference_crowds 的主键是 (user_id, crowd)，
// 重复值会让写入撞主键。去重收口在 NewPreferences，这里固定该保证。
func TestNewPreferencesDeduplicatesPreservingOrder(t *testing.T) {
	p := NewPreferences("normal",
		[]string{"fitness", "pregnant", "fitness"}, []string{"pork", "pork"})

	want := []string{"fitness", "pregnant"}
	if len(p.Crowds) != len(want) {
		t.Fatalf("crowds 应去重为 %v，实际 %v", want, p.Crowds)
	}
	for i, w := range want {
		if p.Crowds[i] != w {
			t.Fatalf("crowds 应保留首次出现顺序 %v，实际 %v", want, p.Crowds)
		}
	}
	if len(p.AvoidFoods) != 1 || p.AvoidFoods[0] != "pork" {
		t.Errorf("avoidFoods 应去重为 [pork]，实际 %v", p.AvoidFoods)
	}
}

// 去重后的切片必须非 nil——nil 会序列化成 null，而契约要求 []。
func TestNewPreferencesEmitsEmptyArraysNotNull(t *testing.T) {
	p := NewPreferences("normal", nil, nil)
	if p.Crowds == nil || p.AvoidFoods == nil {
		t.Fatalf("nil 输入应规整为空切片，实际 crowds=%v avoidFoods=%v",
			p.Crowds, p.AvoidFoods)
	}
	if len(p.Crowds) != 0 || len(p.AvoidFoods) != 0 {
		t.Errorf("应为空集合，实际 crowds=%v avoidFoods=%v", p.Crowds, p.AvoidFoods)
	}
}

// 规整不应改动调用方的切片。指纹函数与 Rank 有同样的约束，
// 这里漏掉的话调用方传进来的切片会被静默重排。
func TestNewPreferencesDoesNotMutateInput(t *testing.T) {
	crowds := []string{"b", "a", "b"}
	NewPreferences("normal", crowds, nil)
	if crowds[0] != "b" || crowds[1] != "a" || crowds[2] != "b" {
		t.Fatalf("不应改动入参，实际 %v", crowds)
	}
}

// PreferenceOptions 的空数组保证，与 Preferences 是两套实现，一并固定。
func TestPreferenceOptionsNormalizedEmitsEmptyArraysNotNull(t *testing.T) {
	got := PreferenceOptions{}.Normalized()
	if got.DietModes == nil || got.Crowds == nil || got.AvoidFoods == nil {
		t.Fatalf("三个字段都应规整为空切片，实际 %+v", got)
	}
}
