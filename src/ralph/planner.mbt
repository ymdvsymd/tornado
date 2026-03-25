///|
/// Planner agent for the ralph loop
pub struct PlannerAgent {
  agent_id : String
  lang : String
}

///|
/// Create a new planner agent
pub fn PlannerAgent::new(
  agent_id? : String = "planner",
  lang? : String = "en",
) -> PlannerAgent {
  { agent_id, lang }
}

///|
/// Build the planning prompt for a milestone
pub fn PlannerAgent::build_plan_prompt(
  self : PlannerAgent,
  milestone : @types.Milestone,
) -> String {
  let lang_instruction = if self.lang == "ja" {
    "Respond in Japanese."
  } else {
    "Respond in English."
  }
  let prompt = StringBuilder::new()
  prompt.write_string("You are a Planner agent. ")
  prompt.write_string(lang_instruction)
  prompt.write_string("\n\n")
  prompt.write_string("## Milestone\n")
  prompt.write_string("ID: ")
  prompt.write_string(milestone.id)
  prompt.write_string("\nGoal: ")
  prompt.write_string(milestone.goal)
  prompt.write_string("\n\n")
  prompt.write_string(
    "## Scope Boundary\n" +
    "Only create tasks for work that belongs to THIS milestone.\n" +
    "The goal text may reference other milestones or other steps for context — " +
    "do NOT include tasks for work that belongs to another milestone or step.\n" +
    "If the goal mentions future steps (e.g. \"Step 9 will update ...\"), " +
    "treat those as informational context only, not as work to be planned here.\n\n" +
    "## Instructions\n" +
    "Break down this milestone into concrete, numbered tasks.\n" +
    "For each task, declare which earlier tasks it depends on using DEPENDS_ON.\n" +
    "Tasks with no dependencies can execute in parallel.\n" +
    "A task will not start until all of its dependencies have completed.\n\n" +
    "## Output Format\n" +
    "TASKS:\n" +
    "1. First task description\nSCOPE: src/foo.mbt, test/foo_test.mbt\nDEPENDS_ON: (none)\n\n" +
    "2. Second task description\nSCOPE: src/bar.mbt\nDEPENDS_ON: 1\n\n" +
    "3. Task that depends on multiple earlier tasks\nSCOPE: src/baz.mbt, src/qux.mbt\nDEPENDS_ON: 1, 2\n\n" +
    "Add a SCOPE line (comma-separated file paths expected to be modified) under each task. Omit SCOPE if unknown.\n" +
    "Add a DEPENDS_ON line with comma-separated task numbers. Use \"(none)\" if the task has no dependencies.\n",
  )
  prompt.to_string()
}

///|
/// Parse the planner output into tasks
pub fn PlannerAgent::parse_plan(
  _self : PlannerAgent,
  output : String,
  milestone_id : String,
  mgr : MilestoneManager,
) -> Array[@types.RalphTask] {
  mgr.parse_planner_output(output, milestone_id)
}

///|
/// Plan result containing parsed tasks and the raw planner output
pub struct PlanResult {
  tasks : Array[@types.RalphTask]
  raw_output : String
}

///|
/// Run the planner agent to generate tasks for a milestone
pub fn PlannerAgent::plan(
  self : PlannerAgent,
  milestone : @types.Milestone,
  backend : @agent.BoxedBackend,
  brief : String,
  milestones : Array[@types.Milestone],
  mgr : MilestoneManager,
  on_event? : (@types.AgentEvent) -> Unit = fn(_e) {  },
) -> PlanResult {
  let prompt = self.build_plan_prompt(milestone)
  let system_prompt = build_planner_system_prompt(brief, milestones)
  let result = backend.run(prompt, system_prompt, on_event)
  match result.status {
    Completed => {
      let tasks = self.parse_plan(result.content, milestone.id, mgr)
      { tasks, raw_output: result.content }
    }
    _ => { tasks: [], raw_output: result.content }
  }
}

///|
/// Check if planner output indicates the milestone is already complete
pub fn is_already_complete_signal(output : String) -> Bool {
  let lower = output.to_lower()
  lower.contains("already complete") ||
  lower.contains("already been completed") ||
  lower.contains("already done") ||
  lower.contains("既に完了")
}
