# Toodo – Implementation Roadmap

Quick checklist. Details in [BRAINSTORM.md](BRAINSTORM.md).

## Phase 1 – Foundation

- [x] Add deps: `drift`, `signals`, `signals_flutter`, `go_router`; dev: `drift_dev`, `build_runner`
- [x] Material 3 theme in `core/theme/app_theme.dart`; use in `main.dart`
- [x] Folder structure: `lib/core/`, `lib/data/`, `lib/features/lists/`, `lib/features/tasks/`
- [x] go_router: routes for home, list detail, task detail (placeholders)
- [x] Drift schema: `lists`, `tasks` tables; migrations
- [x] `ListRepository` + `TaskRepository` with **tests first (TDD)**

## Phase 2 – Lists

- [x] Lists screen (drawer/sidebar + list content)
- [x] Create / rename / delete list
- [x] Signals for lists + Drift→signal bridge (watch lists, update signal)

## Phase 3 – Tasks

- [x] Task list per list; add / edit / complete / delete
- [x] Due date, reminder (storage only)
- [x] Subtasks (`parentId`)

## Phase 4 – Polish

- [ ] Reminders → `flutter_local_notifications`
- [ ] Calendar view
- [ ] Settings

## Phase 5 – Sync (later)

- [ ] Auth; API client; sync service; conflict handling
