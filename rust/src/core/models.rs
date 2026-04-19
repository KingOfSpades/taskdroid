use serde::{Deserialize, Serialize};
use taskchampion::Status as TcStatus;

/// task lifecycle states exposed by the engine
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum TaskStatus {
    Pending,
    Completed,
    Deleted,
    Recurring,
}

impl From<TcStatus> for TaskStatus {
    fn from(s: TcStatus) -> Self {
        match s {
            TcStatus::Pending => TaskStatus::Pending,
            TcStatus::Completed => TaskStatus::Completed,
            TcStatus::Deleted => TaskStatus::Deleted,
            TcStatus::Recurring => TaskStatus::Recurring,
            _ => TaskStatus::Pending,
        }
    }
}

impl From<TaskStatus> for TcStatus {
    fn from(s: TaskStatus) -> Self {
        match s {
            TaskStatus::Pending => TcStatus::Pending,
            TaskStatus::Completed => TcStatus::Completed,
            TaskStatus::Deleted => TcStatus::Deleted,
            TaskStatus::Recurring => TcStatus::Recurring,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskAnnotation {
    pub entry: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UdaPair {
    pub key: String,
    pub value: String,
}

/// raw task data mapped from TaskChampion
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskCore {
    pub uuid: String,
    pub description: String,
    pub status: TaskStatus,
    pub project: Option<String>,
    pub priority: Option<String>,
    pub tags: Vec<String>,
    pub entry: String,
    pub modified: String,
    pub due: Option<String>,
    pub wait: Option<String>,
    pub start: Option<String>,
    pub end: Option<String>,
    pub scheduled: Option<String>,
    pub until: Option<String>,
    pub depends: Vec<String>,
    pub recurrence: Option<String>,
    pub annotations: Vec<TaskAnnotation>,
    pub udas: Vec<UdaPair>,
    pub parent_uuid: Option<String>,
    pub recurrence_index: Option<usize>,
}

/// derived, time-sensitive metadata computed at query time
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskComputed {
    pub urgency: f32,
    pub is_active: bool,
    pub is_blocked: bool,
    pub is_blocking: bool,
    pub is_waiting: bool,
    pub is_recurring_template: bool,
    pub is_recurring_instance: bool,
    pub series_root_uuid: Option<String>,
}

/// stable engine snapshot that combines raw task data with derived metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskSnapshot {
    pub core: TaskCore,
    pub computed: TaskComputed,
}

#[derive(Debug, Clone)]
pub struct CreateTaskParams {
    pub description: String,
    pub status: TaskStatus,
    pub project: Option<String>,
    pub priority: Option<String>,
    pub tags: Vec<String>,
    pub due: Option<String>,
    pub wait: Option<String>,
    pub scheduled: Option<String>,
    pub recurrence: Option<String>,
    pub until: Option<String>,
    pub udas: Vec<UdaPair>,
}

#[derive(Debug, Clone)]
pub struct UpdateTaskParams {
    pub description: Option<String>,
    pub status: Option<TaskStatus>,
    pub project: Option<String>,
    pub priority: Option<String>,
    pub due: Option<String>,
    pub wait: Option<String>,
    pub scheduled: Option<String>,
    pub recurrence: Option<String>,
    pub until: Option<String>,
    pub add_tags: Vec<String>,
    pub remove_tags: Vec<String>,
    pub add_annotation: Option<String>,
    pub remove_annotations: Vec<String>,
    pub add_depends: Vec<String>,
    pub remove_depends: Vec<String>,
    pub start: Option<bool>,
    pub set_udas: Vec<UdaPair>,
}
