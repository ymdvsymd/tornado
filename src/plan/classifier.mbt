///|
pub(all) enum SectionClass {
  Info
  Milestone
  Uncertain
} derive(Eq, Show)

///|
let info_keywords : Array[String] = [
  "context", "背景", "background", "経緯", "前提", "対象ファイル", "修正対象",
  "変更対象", "参照ファイル", "target file", "設計判断", "設計方針",
  "design decision", "方針", "推定原因", "root cause", "問題分析", "調査結果",
  "結論", "conclusion", "results", "summary", "現状", "current",
]

///|
let milestone_keywords : Array[String] = [
  "step", "phase", "手順", "実装", "修正内容", "変更内容", "検証",
  "verification",
]

///|
pub fn classify_section(heading : String) -> SectionClass {
  let normalized = heading.to_lower()
  if contains_any_keyword(normalized, info_keywords) {
    Info
  } else if contains_any_keyword(normalized, milestone_keywords) {
    Milestone
  } else {
    Uncertain
  }
}

///|
fn contains_any_keyword(heading : String, keywords : Array[String]) -> Bool {
  keywords.iter().any(fn(keyword) { heading.contains(keyword) })
}
