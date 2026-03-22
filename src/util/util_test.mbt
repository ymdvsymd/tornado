///|
test "get_string returns value when present" {
  let json : Json = { "name": "hello" }
  inspect(@util.get_string(json, "name", "default"), content="hello")
}

///|
test "get_string returns default when missing" {
  let json : Json = { "other": "value" }
  inspect(@util.get_string(json, "name", "default"), content="default")
}

///|
test "get_string returns default for non-object" {
  let json : Json = "not an object"
  inspect(@util.get_string(json, "name", "default"), content="default")
}

///|
test "get_int returns value when present" {
  let json : Json = { "count": 42 }
  inspect(@util.get_int(json, "count", 0), content="42")
}

///|
test "get_int returns default when missing" {
  let json : Json = { "other": 1 }
  inspect(@util.get_int(json, "count", 0), content="0")
}

///|
test "get_bool returns value when present" {
  let json : Json = { "enabled": true }
  inspect(@util.get_bool(json, "enabled", false), content="true")
}

///|
test "get_bool returns default when missing" {
  let json : Json = {}
  inspect(@util.get_bool(json, "enabled", false), content="false")
}

///|
test "get_string_opt returns Some when present" {
  let json : Json = { "name": "hello" }
  inspect(@util.get_string_opt(json, "name"), content="Some(\"hello\")")
}

///|
test "get_string_opt returns None when missing" {
  let json : Json = {}
  inspect(@util.get_string_opt(json, "name"), content="None")
}

///|
test "split_lines splits on newlines" {
  let lines = @util.split_lines("a\nb\nc")
  assert_true(lines.length() == 3)
  inspect(lines[0], content="a")
  inspect(lines[1], content="b")
  inspect(lines[2], content="c")
}

///|
test "split_lines handles carriage returns" {
  let lines = @util.split_lines("a\r\nb\r\nc")
  assert_true(lines.length() == 3)
  inspect(lines[0], content="a")
  inspect(lines[1], content="b")
  inspect(lines[2], content="c")
}

///|
test "trim removes leading and trailing whitespace" {
  inspect(@util.trim("  hello  "), content="hello")
  inspect(@util.trim("\thello\t"), content="hello")
  inspect(@util.trim("hello"), content="hello")
  inspect(@util.trim("   "), content="")
}

///|
test "join_strings joins with separator" {
  inspect(@util.join_strings(["a", "b", "c"], ", "), content="a, b, c")
  inspect(@util.join_strings(["only"], ", "), content="only")
  inspect(@util.join_strings([], ", "), content="")
}

///|
test "json_escape escapes special characters" {
  inspect(@util.json_escape("hello"), content="\"hello\"")
  inspect(@util.json_escape("he\"llo"), content="\"he\\\"llo\"")
  inspect(@util.json_escape("he\\llo"), content="\"he\\\\llo\"")
  inspect(@util.json_escape("he\nllo"), content="\"he\\nllo\"")
  inspect(@util.json_escape("he\tllo"), content="\"he\\tllo\"")
}

///|
test "find_substring finds needle in haystack" {
  inspect(@util.find_substring("hello world", "world"), content="6")
  inspect(@util.find_substring("hello world", "xyz"), content="-1")
  inspect(@util.find_substring("hello", "hello"), content="0")
}

///|
test "find_substring_from finds from offset" {
  inspect(@util.find_substring_from("abcabc", "abc", 1), content="3")
  inspect(@util.find_substring_from("abcabc", "abc", 0), content="0")
  inspect(@util.find_substring_from("abcabc", "abc", 4), content="-1")
}

///|
test "substring extracts substring" {
  inspect(@util.substring("hello world", 0, 5), content="hello")
  inspect(@util.substring("hello world", 6, 11), content="world")
  inspect(@util.substring("hello", 5, 5), content="")
}

///|
test "substring handles out of bounds" {
  inspect(@util.substring("hello", -1, 3), content="hel")
  inspect(@util.substring("hello", 0, 100), content="hello")
}
