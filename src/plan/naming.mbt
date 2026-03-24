///|
pub fn generate_run_dir_name(title : String, timestamp : String) -> String {
  let slug = sanitize_title(title)
  ".runs/" + timestamp + "_" + slug
}

///|
fn sanitize_title(title : String) -> String {
  let buf = StringBuilder::new()
  let mut prev_hyphen = false

  for ch in title {
    let mapped = to_ascii_lower(ch)
    if mapped == ' ' || mapped == '_' {
      if not(prev_hyphen) {
        buf.write_char('-')
        prev_hyphen = true
      }
      continue
    }
    if is_ascii_alnum(mapped) || mapped == '-' || is_multi_byte(mapped) {
      if mapped == '-' {
        if not(prev_hyphen) {
          buf.write_char(mapped)
          prev_hyphen = true
        }
      } else {
        buf.write_char(mapped)
        prev_hyphen = false
      }
    }
  }

  let stripped = strip_edge_hyphens(buf.to_string())
  let truncated = truncate_slug(stripped, 50)
  if truncated.is_empty() {
    "plan"
  } else {
    truncated
  }
}

///|
fn to_ascii_lower(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    (ch.to_int() + ('a'.to_int() - 'A'.to_int())).unsafe_to_char()
  } else {
    ch
  }
}

///|
fn is_ascii_alnum(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')
}

///|
fn is_multi_byte(ch : Char) -> Bool {
  ch.to_int() > 0x7F
}

///|
fn strip_edge_hyphens(s : String) -> String {
  let chars = s.to_array()
  let len = chars.length()
  let mut start = 0
  while start < len && chars[start] == '-' {
    start += 1
  }
  let mut end = len
  while end > start && chars[end - 1] == '-' {
    end -= 1
  }
  if start >= end {
    ""
  } else {
    String::from_array(chars[start:end])
  }
}

///|
fn truncate_slug(s : String, max_chars : Int) -> String {
  if s.is_empty() {
    return s
  }

  let buf = StringBuilder::new()
  let mut count = 0
  for ch in s {
    if count >= max_chars {
      break
    }
    buf.write_char(ch)
    count += 1
  }

  strip_trailing_hyphen(buf.to_string())
}

///|
fn strip_trailing_hyphen(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == '-' {
    end -= 1
  }
  if end == chars.length() {
    s
  } else {
    String::from_array(chars[:end])
  }
}
