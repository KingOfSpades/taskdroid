# Taskdroid

> A simple, usable, and modern mobile client for [Taskwarrior](https://taskwarrior.org/).

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)
![Rust](https://img.shields.io/badge/rust-%23E05D44.svg?style=flat&logo=rust&logoColor=white)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Features

- **Full sync** – Works with Taskchampion server
- **Multi-profile** – Switch between different profile instances
- **Saved custom filters** – One tap to see your "urgent" or "work" views
- **User-friendly UI** – Built for touch, not just terminal
- **Custom attributes** – Keep your metadata intact
- **Local calendar sync** – One‑way sync to your device calendar
- **Export & import** – Move tasks in and out easily
- **Annotations support** – Add notes and updates to any task

## Screenshots

| Home                                                    | Add Task                                                        | Task Details                                                            | Profile                                                       | Settings                                                        | Export/Import                                                             |
| ------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------- |
| <img src="screenshots/home.png" alt="Home" width="200"> | <img src="screenshots/add-task.png" alt="Add Task" width="200"> | <img src="screenshots/task-details.png" alt="Task Details" width="200"> | <img src="screenshots/profile.png" alt="Profile" width="200"> | <img src="screenshots/settings.png" alt="Settings" width="200"> | <img src="screenshots/export-import.png" alt="Export/Import" width="200"> |

---

### Installation

#### Download a signed APK release (recommended)

Head to the [Releases](https://github.com/taskdroid/taskdroid/releases) page and grab the latest `.apk`.

#### Build from source

```bash
git clone https://github.com/taskdroid/taskdroid.git
cd taskdroid
./build.sh --release --split
```
