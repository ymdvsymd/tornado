///|
pub(all) struct PlanSection {
  heading : String
  body : String
}

///|
pub(all) struct PlanDocument {
  title : String
  intro : String
  sections : Array[PlanSection]
}

///|
pub fn parse_plan(content : String) -> PlanDocument {
  let lines = @util.split_lines(content)
  let mut title = ""
  let intro_buf = StringBuilder::new()
  let mut intro_has_content = false
  let sections : Array[PlanSection] = []
  let mut current_heading : String? = None
  let current_body = StringBuilder::new()
  let mut current_body_has_content = false
  let mut seen_title = false
  let mut seen_first_section = false

  for line in lines {
    if not(seen_title) {
      if line.has_prefix("# ") {
        title = line.view(start_offset=2).to_string()
        seen_title = true
      }
      continue
    }

    if line.has_prefix("## ") {
      match current_heading {
        Some(heading) =>
          sections.push({ heading, body: current_body.to_string() })
        None => ()
      }
      current_body.reset()
      current_body_has_content = false
      current_heading = Some(line.view(start_offset=3).to_string())
      seen_first_section = true
      continue
    }

    if seen_first_section {
      current_body_has_content = append_line(
        current_body, line, current_body_has_content,
      )
    } else {
      intro_has_content = append_line(intro_buf, line, intro_has_content)
    }
  }

  match current_heading {
    Some(heading) => sections.push({ heading, body: current_body.to_string() })
    None => ()
  }

  { title, intro: intro_buf.to_string(), sections }
}

///|
fn append_line(buf : StringBuilder, line : String, has_content : Bool) -> Bool {
  if has_content {
    buf.write_char('\n')
  }
  buf.write_string(line)
  true
}
