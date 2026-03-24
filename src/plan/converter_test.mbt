///|
test "convert_to_milestones all info sections produce brief only and no milestones" {
  let doc : @plan.PlanDocument = {
    title: "Plan",
    intro: "Intro summary",
    sections: [
      { heading: "Context", body: "Background details" },
      {
        heading: "設計判断",
        body: "Use the planner backend only when needed",
      },
    ],
  }

  let mgr = @plan.convert_to_milestones(doc, [Info, Info])

  inspect(mgr.milestones.length(), content="0")
  inspect(
    mgr.brief,
    content="Intro summary\n\n## Context\nBackground details\n\n## 設計判断\nUse the planner backend only when needed",
  )
}

///|
test "convert_to_milestones all milestone sections produce sequential ids and empty brief without intro" {
  let doc : @plan.PlanDocument = {
    title: "Plan",
    intro: "",
    sections: [
      { heading: "Step 1", body: "Implement parser support" },
      { heading: "Step 2", body: "Add CLI wiring" },
      { heading: "検証", body: "Run the plan workflow" },
    ],
  }

  let mgr = @plan.convert_to_milestones(doc, [Milestone, Milestone, Milestone])

  inspect(mgr.brief, content="")
  inspect(mgr.milestones.length(), content="3")
  inspect(mgr.milestones[0].id, content="m1")
  inspect(mgr.milestones[1].id, content="m2")
  inspect(mgr.milestones[2].id, content="m3")
  inspect(mgr.milestones[0].goal, content="Step 1\n\nImplement parser support")
  inspect(mgr.milestones[1].goal, content="Step 2\n\nAdd CLI wiring")
  inspect(mgr.milestones[2].goal, content="検証\n\nRun the plan workflow")
}

///|
test "convert_to_milestones mixed info and milestone sections skip info when assigning milestone ids" {
  let doc : @plan.PlanDocument = {
    title: "Plan",
    intro: "Top-level intro",
    sections: [
      { heading: "Context", body: "Why this change is needed" },
      { heading: "Implementation", body: "Wire --plan into the CLI" },
      {
        heading: "Design Decision",
        body: "Use deterministic keyword matching first",
      },
      { heading: "Verification", body: "Cover parser and converter paths" },
    ],
  }

  let mgr = @plan.convert_to_milestones(doc, [Info, Milestone, Info, Milestone])

  inspect(mgr.milestones.length(), content="2")
  inspect(mgr.milestones[0].id, content="m1")
  inspect(mgr.milestones[1].id, content="m2")
  inspect(
    mgr.milestones[0].goal,
    content="Implementation\n\nWire --plan into the CLI",
  )
  inspect(
    mgr.milestones[1].goal,
    content="Verification\n\nCover parser and converter paths",
  )
  inspect(
    mgr.brief,
    content="Top-level intro\n\n## Context\nWhy this change is needed\n\n## Design Decision\nUse deterministic keyword matching first",
  )
}

///|
test "convert_to_milestones treats uncertain sections as milestones" {
  let doc : @plan.PlanDocument = {
    title: "Plan",
    intro: "",
    sections: [
      { heading: "Overview", body: "This heading is intentionally ambiguous" },
    ],
  }

  let mgr = @plan.convert_to_milestones(doc, [Uncertain])

  inspect(mgr.brief, content="")
  inspect(mgr.milestones.length(), content="1")
  inspect(mgr.milestones[0].id, content="m1")
  inspect(
    mgr.milestones[0].goal,
    content="Overview\n\nThis heading is intentionally ambiguous",
  )
  inspect(mgr.milestones[0].status, content="Pending")
}

///|
test "convert_to_milestones with only intro and no sections keeps intro as brief and no milestones" {
  let doc : @plan.PlanDocument = {
    title: "Plan",
    intro: "Only intro",
    sections: [],
  }

  let mgr = @plan.convert_to_milestones(doc, [])

  inspect(mgr.milestones.length(), content="0")
  inspect(mgr.brief, content="Only intro")
}

///|
test "convert_to_milestones goal format is heading blank-line body" {
  let doc : @plan.PlanDocument = {
    title: "Plan",
    intro: "",
    sections: [{ heading: "Step A", body: "Line 1\nLine 2" }],
  }

  let mgr = @plan.convert_to_milestones(doc, [Milestone])

  inspect(mgr.milestones[0].goal, content="Step A\n\nLine 1\nLine 2")
}

///|
test "convert_to_milestones serializes to valid JSON with brief and milestones fields" {
  let doc : @plan.PlanDocument = {
    title: "Plan",
    intro: "Brief intro",
    sections: [
      { heading: "Context", body: "Useful background" },
      { heading: "Implementation", body: "Add converter coverage" },
    ],
  }

  let mgr = @plan.convert_to_milestones(doc, [Info, Milestone])
  let serialized = mgr.to_json()
  let roundtrip = @ralph.MilestoneManager::load_from_json(serialized) catch {
    err => fail("to_json output is not valid JSON: \{err}")
  }

  assert_true(serialized.contains("\"brief\":"))
  assert_true(serialized.contains("\"milestones\":"))
  inspect(
    roundtrip.brief,
    content="Brief intro\n\n## Context\nUseful background",
  )
  inspect(roundtrip.milestones.length(), content="1")
  inspect(
    roundtrip.milestones[0].goal,
    content="Implementation\n\nAdd converter coverage",
  )
}
