///|
test "classify_section matches exact info headings" {
  inspect(@plan.classify_section("Context"), content="Info")
  inspect(@plan.classify_section("背景"), content="Info")
  inspect(@plan.classify_section("設計判断"), content="Info")
  inspect(@plan.classify_section("対象ファイル"), content="Info")
}

///|
test "classify_section matches partial info headings" {
  inspect(@plan.classify_section("背景と経緯"), content="Info")
  inspect(@plan.classify_section("Current State"), content="Info")
  inspect(@plan.classify_section("Root Cause Analysis"), content="Info")
}

///|
test "classify_section matches info headings case-insensitively" {
  inspect(@plan.classify_section("CONTEXT"), content="Info")
  inspect(@plan.classify_section("Design Decision"), content="Info")
}

///|
test "classify_section matches exact milestone headings" {
  inspect(@plan.classify_section("Step 1"), content="Milestone")
  inspect(@plan.classify_section("検証"), content="Milestone")
}

///|
test "classify_section matches partial milestone headings" {
  inspect(@plan.classify_section("Step 1: 型追加"), content="Milestone")
  inspect(@plan.classify_section("実装手順"), content="Milestone")
}

///|
test "classify_section prefers info when both keyword groups match" {
  inspect(@plan.classify_section("Current verification"), content="Info")
}

///|
test "classify_section returns uncertain for unmatched headings" {
  inspect(
    @plan.classify_section("なぜこの変更が必要か"),
    content="Uncertain",
  )
  inspect(@plan.classify_section("Overview"), content="Uncertain")
  inspect(@plan.classify_section("その他"), content="Uncertain")
  inspect(@plan.classify_section("Appendix"), content="Uncertain")
}

///|
test "classify_section returns uncertain for empty heading" {
  inspect(@plan.classify_section(""), content="Uncertain")
}
