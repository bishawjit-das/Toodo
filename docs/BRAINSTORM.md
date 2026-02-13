# Toodo (TickTick Clone) – Brainstorm & Tech Decisions

## Goals

- **Exact TickTick clone**: tasks, lists, due dates, reminders, subtasks, habits, calendar, Pomodoro, etc.
- **Offline-first**: local DB first; cloud sync later (like TickTick).
- **Material 3** UI, same flows and spacing as TickTick where possible.
- **Snappy**: minimal jank, fast startup, instant UI feedback.
- **Quality**: Git, TDD, DRY, simple code.

---

## 1. Tech Stack

| Layer | Choice | Why |
|-------|--------|-----|
| **UI** | Flutter 3.x + Material 3 | Cross-platform, single codebase, M3 matches “exact clone” look. |
| **Offline DB** | **Drift** (SQLite) | Type-safe, reactive streams, migrations, good testability. Isar is faster but Drift is simpler and sync-friendly. |
| **State** | **Signals** (pragmatic middle) | Fine-grained rebuilds (snappy UI); UI/view-model state in signals. Repositories expose Drift streams; one bridge layer subscribes to streams and updates signals. TDD via injection (inject repo or signal in tests). |
| **Routing** | **go_router** | Declarative, deep links, type-safe routes. |
| **Local notifs** | **flutter_local_notifications** | Reminders, due dates. |
| **Later (sync)** | Custom REST or Firebase/Supabase | Decide when we add “v2” sync; keep repo/interface abstract so we can swap. |

**Rejected / deferred**

- **Hive / shared_prefs** for main data → not enough for relations and querying; use Drift.
- **Riverpod only** → we use Signals for reactivity (finer rebuilds); repositories + Drift bridge keep data layer clean.
- **Bloc** → more boilerplate; Signals + Drift is enough and shorter.
- **GetIt** → Signals + constructor/service injection for tests.

---

## 2. Architecture (Offline-First, Sync-Ready) – Pragmatic Middle

```
┌─────────────────────────────────────────────────────────┐
│  UI (Widgets) – Material 3; Watch(signal) for rebuilds   │
├─────────────────────────────────────────────────────────┤
│  Signals (UI state, view-models, selection, filters)     │
│  + Drift→signal bridge (subscribe to repo streams,       │
│    update signals in one place per stream)               │
├─────────────────────────────────────────────────────────┤
│  Data: Repositories (single source of truth)              │
│        → Local: Drift DAO (exposes Streams via watch())   │
│        → Later: Remote API + sync service                 │
└─────────────────────────────────────────────────────────┘
```

- **Feature-first folders**: `lib/features/tasks/`, `lists/`, `calendar/`, `settings/`, etc.
- **Shared**: `lib/core/` (theme, router, constants), `lib/data/` (Drift DB, repositories).
- **Repositories** talk to Drift (and later to sync); they expose **Streams** (e.g. Drift `watch()`). No UI in repos.
- **Drift→signal bridge**: one place (e.g. per feature or a small `*_signals.dart`) subscribes to repository streams and sets `signal.value = data`. UI only reads signals (and calls repo methods for writes).
- **TDD**: repository tests with in-memory Drift; widget tests inject repository or signal so tests can override. No BuildContext in business logic.

---

## 3. Data Model (Start Simple – TickTick-Like)

**Core entities (v1)**

- **List** – id, name, color, icon, sortOrder.
- **Task** – id, listId, title, notes, dueDate, dueTime, reminder, repeat, priority, completedAt, sortOrder, parentId (for subtasks).
- **Subtask** – same as Task with parentId set; no extra table.

**Deferred (v2+)**

- Tags, habits, Pomodoro stats, calendar view persistence, attachments.

**DB**

- One Drift database; tables: `lists`, `tasks`. Use `parentId` for subtasks. Indexes on `listId`, `completedAt`, `dueDate`, `sortOrder` for snappy queries.

---

## 4. What to Build First (Order of Work)

1. **Project setup**
   - Material 3 theme (colors, typography, component theme).
   - go_router with a few placeholder routes (home, list detail, task detail).
   - Folder structure: `core/`, `data/`, `features/`.

2. **Local DB + repositories**
   - Drift schema: `lists`, `tasks`.
   - Repositories: `ListRepository`, `TaskRepository` (CRUD).
   - TDD: repository tests with in-memory Drift DB.

3. **Lists (first feature)**
   - “All” + user lists; create / rename / delete list.
   - Signals for lists UI state; bridge: subscribe to `ListRepository.watchLists()` and update a `listsSignal`.
   - UI: list drawer/sidebar + list screen (Material 3); use `Watch` or `.watch(context)` so only list-dependent widgets rebuild.

4. **Tasks**
   - Add / edit / complete / delete task; show in list.
   - Due date, reminder (store only; notifications later).
   - Subtasks (parentId).

5. **Polish**
   - Reminders → local notifications.
   - Calendar view (read from tasks).
   - Settings (theme, default list, etc.).

6. **Later**
   - Cloud sync (auth, API, conflict resolution).

---

## 5. Making the App Snappy

- **Drift**: use `watch()` for lists/tasks so UI updates reactively without manual refresh.
- **List views**: `ListView.builder` (or `SliverList`) for long lists; avoid building all items at once.
- **Heavy work off main isolate**: run Drift in a separate isolate only if needed; for v1, main isolate is usually enough if queries are indexed.
- **Skeletons / placeholders**: show list/task skeletons while first load; then replace with data.
- **Optimistic updates**: update UI immediately on add/complete/delete; persist in background; rollback on failure.
- **No unnecessary rebuilds**: Signals give fine-grained updates—only widgets that read a signal (via `Watch` or `.watch(context)`) rebuild. Use `const` widgets where possible.

---

## 6. TDD Strategy

- **Unit tests**: repositories (with in-memory Drift), any pure business logic (e.g. sort order, recurrence). No signals required in repo tests.
- **Widget tests**: main screens (list view, task list, add task form). **Inject** repository or signal (e.g. constructor param or a small overridable container) so tests can pass a mock/fake; no “override provider scope” needed.
- **Integration tests**: one happy path (e.g. create list → add task → complete) with real in-memory DB.
- **Where**: `test/` mirroring `lib/` (e.g. `test/data/repositories/task_repository_test.dart`).
- **Rule**: write a failing test first, then implement until it passes; refactor; commit.

---

## 7. DRY & Conventions

- **Shared widgets**: buttons, input fields, list tiles in `core/widgets/` or per-feature if used only there.
- **Single place for theme**: `core/theme/` (Material 3 `ThemeData`, colors).
- **Spacing**: use `Theme.of(context).spacing` (M3) or a small `AppSpacing` class with 4/8/16/24.
- **Repositories only for data**: no UI in repositories; no direct DB in widgets.
- **Constants**: `core/constants.dart` or per-feature for magic strings/numbers.

---

## 8. Git & Version Control

- **Branches**: `main` stable; feature branches like `feature/lists`, `feature/tasks`, `feature/sync`.
- **Commits**: small, logical; message format: `feat(lists): add create list` / `fix(tasks): correct due date sort`.
- **.gitignore**: already ignores build/, .dart_tool/, etc.; add coverage/ if not already.
- **No secrets in repo**: env or config for API keys when we add sync.

---

## 9. Decisions Summary

| Topic | Decision |
|-------|----------|
| Offline DB | Drift (SQLite) |
| State | Signals (+ Drift→signal bridge, repositories) |
| Routing | go_router |
| UI | Material 3 |
| First feature | Lists, then Tasks |
| Tests | Repository + widget tests first; TDD |
| Sync | Later; repository abstraction ready |

---

## 10. Next Immediate Steps

1. Add dependencies: `drift`, `signals`, `signals_flutter`, `go_router`; dev: `drift_dev`, `build_runner`.
2. Enable Material 3 in `main.dart` and add `core/theme/app_theme.dart`.
3. Create folder structure: `core/`, `data/`, `features/lists/`, `features/tasks/`.
4. Define Drift schema and run first migration; add `ListRepository` with tests (TDD).
5. Add Drift→signal bridge for lists (e.g. subscribe to `listRepository.watchLists()` and update a `listsSignal`).
6. Implement “Lists” screen and navigation (go_router); UI reads from signals via `Watch` or `.watch(context)`.

After that we can iterate: tasks, due dates, reminders, then sync design.
