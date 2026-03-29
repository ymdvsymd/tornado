///|
test "push emits complete line on newline" {
  let buf = @agent.OutputLineBuffer::new()
  let lines : Array[String] = []
  buf.push("hello\n", fn(line) { lines.push(line) })
  assert_eq(lines.length(), 1, msg="expected 1 line")
  inspect(lines[0], content="hello")
}

///|
test "push accumulates chunks until newline" {
  let buf = @agent.OutputLineBuffer::new()
  let lines : Array[String] = []
  buf.push("hel", fn(line) { lines.push(line) })
  assert_eq(lines.length(), 0, msg="no line before newline")
  buf.push("lo\n", fn(line) { lines.push(line) })
  assert_eq(lines.length(), 1, msg="expected 1 line after newline")
  inspect(lines[0], content="hello")
}

///|
test "push emits multiple lines from single chunk" {
  let buf = @agent.OutputLineBuffer::new()
  let lines : Array[String] = []
  buf.push("line1\nline2\nline3\n", fn(line) { lines.push(line) })
  assert_eq(lines.length(), 3, msg="expected 3 lines")
  inspect(lines[0], content="line1")
  inspect(lines[1], content="line2")
  inspect(lines[2], content="line3")
}

///|
test "push strips CR from CRLF line endings" {
  let buf = @agent.OutputLineBuffer::new()
  let lines : Array[String] = []
  buf.push("hello\r\n", fn(line) { lines.push(line) })
  assert_eq(lines.length(), 1, msg="expected 1 line")
  inspect(lines[0], content="hello")
}

///|
test "flush emits remaining partial text" {
  let buf = @agent.OutputLineBuffer::new()
  let lines : Array[String] = []
  buf.push("partial", fn(line) { lines.push(line) })
  assert_eq(lines.length(), 0, msg="no line before flush")
  buf.flush(fn(line) { lines.push(line) })
  assert_eq(lines.length(), 1, msg="expected 1 line after flush")
  inspect(lines[0], content="partial")
}

///|
test "flush does nothing when buffer is empty" {
  let buf = @agent.OutputLineBuffer::new()
  let lines : Array[String] = []
  buf.flush(fn(line) { lines.push(line) })
  assert_eq(lines.length(), 0, msg="no line from empty buffer")
}

///|
test "flush strips trailing CR" {
  let buf = @agent.OutputLineBuffer::new()
  let lines : Array[String] = []
  buf.push("trailing\r", fn(line) { lines.push(line) })
  buf.flush(fn(line) { lines.push(line) })
  assert_eq(lines.length(), 1, msg="expected 1 line")
  inspect(lines[0], content="trailing")
}
