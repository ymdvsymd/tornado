///|
/// Helper to build a minimal RalphTask for DAG tests.
fn dag_task(id : String, depends_on : Array[String]) -> @types.RalphTask {
  {
    id,
    description: id,
    scope: [],
    depends_on,
    status: @types.TaskStatus::Pending,
    result: None,
  }
}

///|
/// Helper to build a RalphTask with scope for scope-edge tests.
fn dag_task_scoped(
  id : String,
  scope : Array[String],
  depends_on : Array[String],
) -> @types.RalphTask {
  {
    id,
    description: id,
    scope,
    depends_on,
    status: @types.TaskStatus::Pending,
    result: None,
  }
}

///|
test "compute_layers: linear DAG A→B→C produces layers 0,1,2" {
  let tasks = [dag_task("A", []), dag_task("B", ["A"]), dag_task("C", ["B"])]
  let (layers, cycle_tasks, _) = @ralph.compute_layers(tasks)
  assert_true(cycle_tasks.is_empty())
  inspect(layers.get("A"), content="Some(0)")
  inspect(layers.get("B"), content="Some(1)")
  inspect(layers.get("C"), content="Some(2)")
}

///|
test "compute_layers: diamond DAG A→B,A→C,B→D,C→D produces layers 0,1,1,2" {
  let tasks = [
    dag_task("A", []),
    dag_task("B", ["A"]),
    dag_task("C", ["A"]),
    dag_task("D", ["B", "C"]),
  ]
  let (layers, cycle_tasks, _) = @ralph.compute_layers(tasks)
  assert_true(cycle_tasks.is_empty())
  inspect(layers.get("A"), content="Some(0)")
  inspect(layers.get("B"), content="Some(1)")
  inspect(layers.get("C"), content="Some(1)")
  inspect(layers.get("D"), content="Some(2)")
}

///|
test "compute_layers: wide DAG with independent tasks all in layer 0" {
  let tasks = [dag_task("A", []), dag_task("B", []), dag_task("C", [])]
  let (layers, cycle_tasks, _) = @ralph.compute_layers(tasks)
  assert_true(cycle_tasks.is_empty())
  inspect(layers.get("A"), content="Some(0)")
  inspect(layers.get("B"), content="Some(0)")
  inspect(layers.get("C"), content="Some(0)")
}

///|
test "compute_layers: cycle A→B→C→A detected and fallback to layer 0" {
  let tasks = [dag_task("A", ["C"]), dag_task("B", ["A"]), dag_task("C", ["B"])]
  let (layers, cycle_tasks, _) = @ralph.compute_layers(tasks)
  // All three are in the cycle
  assert_true(cycle_tasks.length() == 3)
  assert_true(cycle_tasks.contains("A"))
  assert_true(cycle_tasks.contains("B"))
  assert_true(cycle_tasks.contains("C"))
  // Fallback: all assigned to layer 0
  inspect(layers.get("A"), content="Some(0)")
  inspect(layers.get("B"), content="Some(0)")
  inspect(layers.get("C"), content="Some(0)")
}

///|
test "compute_layers: self-reference A→A reported as cycle error" {
  let tasks = [dag_task("A", ["A"]), dag_task("B", ["A"])]
  let (layers, cycle_tasks, warnings) = @ralph.compute_layers(tasks)
  // Self-reference is reported as a cycle error
  assert_true(cycle_tasks.length() == 1)
  assert_true(cycle_tasks.contains("A"))
  // Warning generated for self-reference
  assert_true(warnings.length() == 1)
  assert_true(warnings[0].contains("Self-reference"))
  assert_true(warnings[0].contains("A"))
  // Edge is skipped so A still processes normally at layer 0
  inspect(layers.get("A"), content="Some(0)")
  inspect(layers.get("B"), content="Some(1)")
}

///|
test "compute_layers: non-existent reference A→X produces warning" {
  let tasks = [dag_task("A", ["X"]), dag_task("B", ["A"])]
  let (layers, cycle_tasks, warnings) = @ralph.compute_layers(tasks)
  assert_true(cycle_tasks.is_empty())
  // Warning generated for non-existent reference
  assert_true(warnings.length() == 1)
  assert_true(warnings[0].contains("Non-existent reference"))
  assert_true(warnings[0].contains("A"))
  assert_true(warnings[0].contains("X"))
  // Edge is skipped so A has in-degree 0
  inspect(layers.get("A"), content="Some(0)")
  inspect(layers.get("B"), content="Some(1)")
}

///|
test "compute_layers: partial cycle with reachable root" {
  // A is independent, B→C→B forms a cycle
  let tasks = [dag_task("A", []), dag_task("B", ["C"]), dag_task("C", ["B"])]
  let (layers, cycle_tasks, _) = @ralph.compute_layers(tasks)
  // A is not in cycle
  inspect(layers.get("A"), content="Some(0)")
  // B and C form a cycle
  assert_true(cycle_tasks.length() == 2)
  assert_true(cycle_tasks.contains("B"))
  assert_true(cycle_tasks.contains("C"))
  // Fallback: cycle tasks at layer 0
  inspect(layers.get("B"), content="Some(0)")
  inspect(layers.get("C"), content="Some(0)")
}

///|
test "compute_layers: empty task list" {
  let tasks : Array[@types.RalphTask] = []
  let (layers, cycle_tasks, _) = @ralph.compute_layers(tasks)
  assert_true(layers.is_empty())
  assert_true(cycle_tasks.is_empty())
}

///|
test "compute_layers: single task with no deps" {
  let tasks = [dag_task("A", [])]
  let (layers, cycle_tasks, _) = @ralph.compute_layers(tasks)
  assert_true(cycle_tasks.is_empty())
  inspect(layers.get("A"), content="Some(0)")
}

///|
test "add_scope_edges: overlapping scopes generate chain edges" {
  let tasks = [
    dag_task_scoped("t1", ["shared.ts", "a.ts"], []),
    dag_task_scoped("t2", ["shared.ts", "b.ts"], []),
    dag_task_scoped("t3", ["shared.ts", "c.ts"], []),
  ]
  let edges = @ralph.add_scope_edges(tasks)
  // shared.ts is owned by [t1, t2, t3] → chain: t1→t2, t2→t3
  assert_true(edges.length() == 2)
  let (from1, to1) = edges[0]
  inspect(from1, content="t1")
  inspect(to1, content="t2")
  let (from2, to2) = edges[1]
  inspect(from2, content="t2")
  inspect(to2, content="t3")
}

///|
test "add_scope_edges: no overlaps returns empty" {
  let tasks = [
    dag_task_scoped("t1", ["a.ts"], []),
    dag_task_scoped("t2", ["b.ts"], []),
  ]
  let edges = @ralph.add_scope_edges(tasks)
  assert_true(edges.is_empty())
}

///|
test "add_scope_edges: empty scopes returns empty" {
  let tasks = [dag_task("t1", []), dag_task("t2", [])]
  let edges = @ralph.add_scope_edges(tasks)
  assert_true(edges.is_empty())
}

///|
test "add_scope_edges: deduplicates edges across multiple overlapping files" {
  // t1 and t2 share both shared1.ts and shared2.ts
  let tasks = [
    dag_task_scoped("t1", ["shared1.ts", "shared2.ts"], []),
    dag_task_scoped("t2", ["shared1.ts", "shared2.ts"], []),
  ]
  let edges = @ralph.add_scope_edges(tasks)
  // Both files produce the same edge t1→t2, should be deduplicated
  assert_true(edges.length() == 1)
  let (from, to) = edges[0]
  inspect(from, content="t1")
  inspect(to, content="t2")
}

///|
test "add_scope_edges: duplicate scope entries in single task do not create self-edge" {
  // t1 has duplicated scope entry — must not produce self-dependency t1→t1
  let tasks = [
    dag_task_scoped("t1", ["shared.ts", "shared.ts"], []),
    dag_task_scoped("t2", ["other.ts"], []),
  ]
  let edges = @ralph.add_scope_edges(tasks)
  // shared.ts owner is [t1] (deduplicated), no overlap → no edges
  assert_true(edges.is_empty())
}

///|
test "add_scope_edges: duplicate scope with real overlap only produces cross-task edge" {
  // t1 has duplicated scope, t2 also owns that file → one cross-task edge, no self-edge
  let tasks = [
    dag_task_scoped("t1", ["shared.ts", "shared.ts"], []),
    dag_task_scoped("t2", ["shared.ts"], []),
  ]
  let edges = @ralph.add_scope_edges(tasks)
  assert_true(edges.length() == 1)
  let (from, to) = edges[0]
  inspect(from, content="t1")
  inspect(to, content="t2")
}

///|
test "scope edges integrate with compute_layers to serialize overlapping tasks" {
  let tasks = [
    dag_task_scoped("t1", ["shared.ts"], []),
    dag_task_scoped("t2", ["shared.ts"], []),
    dag_task_scoped("t3", ["other.ts"], []),
  ]
  // Without scope edges, all tasks would be layer 0
  let (layers_before, _, _) = @ralph.compute_layers(tasks)
  inspect(layers_before.get("t1"), content="Some(0)")
  inspect(layers_before.get("t2"), content="Some(0)")
  inspect(layers_before.get("t3"), content="Some(0)")

  // After adding scope edges, t2 depends on t1
  let edges = @ralph.add_scope_edges(tasks)
  assert_true(edges.length() == 1)
  let (from, to) = edges[0]
  inspect(from, content="t1")
  inspect(to, content="t2")

  // Apply scope edges to tasks' depends_on and recompute
  let tasks_with_edges = [
    dag_task_scoped("t1", ["shared.ts"], []),
    dag_task_scoped("t2", ["shared.ts"], ["t1"]),
    dag_task_scoped("t3", ["other.ts"], []),
  ]
  let (layers_after, cycle_tasks, _) = @ralph.compute_layers(tasks_with_edges)
  assert_true(cycle_tasks.is_empty())
  inspect(layers_after.get("t1"), content="Some(0)")
  inspect(layers_after.get("t2"), content="Some(1)")
  // t3 is independent, stays at layer 0
  inspect(layers_after.get("t3"), content="Some(0)")
}
