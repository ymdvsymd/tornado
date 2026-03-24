///|
pub fn build_classification_prompt(sections : Array[PlanSection]) -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "Classify each section as \"info\" (background context) or \"milestone\" (implementation step).\n\n",
  )
  buf.write_string("Sections:\n")
  for i, section in sections {
    let snippet = trim_trailing_whitespace(
      @util.substring(section.body, 0, min_int(section.body.length(), 100)),
    )
    buf.write_string("\{i + 1}. \"\{section.heading}\" -- \{snippet}\n")
  }
  buf.write_string("\n")
  buf.write_string("Output (one per line):\n")
  for i in 0..<sections.length() {
    let example = if i % 2 == 0 { "info" } else { "milestone" }
    buf.write_string("\{i + 1}: \{example}\n")
  }
  buf.to_string()
}

///|
pub fn parse_classification_response(
  output : String,
  count : Int,
) -> Array[SectionClass] {
  let lines = @util.split_lines(output)
  let classes : Array[SectionClass] = []
  for i in 0..<count {
    classes.push(find_classification(lines, i + 1))
  }
  classes
}

///|
fn find_classification(
  lines : Array[String],
  expected_index : Int,
) -> SectionClass {
  for line in lines {
    match parse_classification_line(line) {
      Some((index, class)) if index == expected_index => return class
      _ => ()
    }
  }
  SectionClass::Milestone
}

///|
fn parse_classification_line(line : String) -> (Int, SectionClass)? {
  let parts : Array[String] = []
  for part_view in line.split(": ") {
    parts.push(part_view.to_string())
  }
  if parts.length() != 2 {
    return None
  }
  let index = parse_positive_int(parts[0])
  let class = match parts[1] {
    "info" => Some(SectionClass::Info)
    "milestone" => Some(SectionClass::Milestone)
    _ => None
  }
  match (index, class) {
    (Some(n), Some(parsed)) => Some((n, parsed))
    _ => None
  }
}

///|
fn parse_positive_int(s : String) -> Int? {
  if s.is_empty() {
    return None
  }
  let mut value = 0
  for ch in s {
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn trim_trailing_whitespace(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 &&
        (
          chars[end - 1] == ' ' ||
          chars[end - 1] == '\t' ||
          chars[end - 1] == '\n' ||
          chars[end - 1] == '\r'
        ) {
    end -= 1
  }
  String::from_array(chars[:end])
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
