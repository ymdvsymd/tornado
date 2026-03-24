///|
test "parse_plan title and intro with no sections" {
  let content = "# Title\nIntro line 1\nIntro line 2"
  let doc = @plan.parse_plan(content)

  inspect(doc.title, content="Title")
  inspect(doc.intro, content="Intro line 1\nIntro line 2")
  inspect(doc.sections.length(), content="0")
}

///|
test "parse_plan single section" {
  let content = "# Title\n## Goal\nShip parser tests"
  let doc = @plan.parse_plan(content)

  inspect(doc.title, content="Title")
  inspect(doc.intro, content="")
  inspect(doc.sections.length(), content="1")
  inspect(doc.sections[0].heading, content="Goal")
  inspect(doc.sections[0].body, content="Ship parser tests")
}

///|
test "parse_plan multiple sections with intro and body content" {
  let content = "# Release Plan\nOverview line 1\nOverview line 2\n## Context\nContext body line 1\nContext body line 2\n## Tasks\nTask A\nTask B"
  let doc = @plan.parse_plan(content)

  inspect(doc.title, content="Release Plan")
  inspect(doc.intro, content="Overview line 1\nOverview line 2")
  inspect(doc.sections.length(), content="2")
  inspect(doc.sections[0].heading, content="Context")
  inspect(
    doc.sections[0].body,
    content="Context body line 1\nContext body line 2",
  )
  inspect(doc.sections[1].heading, content="Tasks")
  inspect(doc.sections[1].body, content="Task A\nTask B")
}

///|
test "parse_plan keeps h3 headings inside current h2 section body" {
  let content = "# Title\n## Implementation\nIntro\n### Details\nStep 1\n### Notes\nStep 2"
  let doc = @plan.parse_plan(content)

  inspect(doc.title, content="Title")
  inspect(doc.intro, content="")
  inspect(doc.sections.length(), content="1")
  inspect(doc.sections[0].heading, content="Implementation")
  inspect(
    doc.sections[0].body,
    content="Intro\n### Details\nStep 1\n### Notes\nStep 2",
  )
}

///|
test "parse_plan without top-level title returns empty document" {
  let content = "Intro without title\n## Context\nIgnored section"
  let doc = @plan.parse_plan(content)

  inspect(doc.title, content="")
  inspect(doc.intro, content="")
  inspect(doc.sections.length(), content="0")
}

///|
test "parse_plan preserves trailing blank lines before end of document" {
  let content = "# Title\nIntro\n\n## Context\nBody\n\n"
  let doc = @plan.parse_plan(content)

  inspect(doc.title, content="Title")
  inspect(doc.intro, content="Intro\n")
  inspect(doc.sections.length(), content="1")
  inspect(doc.sections[0].heading, content="Context")
  inspect(doc.sections[0].body, content="Body\n")
}

///|
test "parse_plan section with empty body" {
  let content = "# Title\n## Empty"
  let doc = @plan.parse_plan(content)

  inspect(doc.title, content="Title")
  inspect(doc.intro, content="")
  inspect(doc.sections.length(), content="1")
  inspect(doc.sections[0].heading, content="Empty")
  inspect(doc.sections[0].body, content="")
}

///|
test "parse_plan consecutive sections without body between them" {
  let content = "# Title\n## First\n## Second\nSecond body"
  let doc = @plan.parse_plan(content)

  inspect(doc.title, content="Title")
  inspect(doc.intro, content="")
  inspect(doc.sections.length(), content="2")
  inspect(doc.sections[0].heading, content="First")
  inspect(doc.sections[0].body, content="")
  inspect(doc.sections[1].heading, content="Second")
  inspect(doc.sections[1].body, content="Second body")
}
