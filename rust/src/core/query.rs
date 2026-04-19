use super::models::{TaskSnapshot, TaskStatus};

/// field-level filter criteria applied before sorting and pagination
#[derive(Debug, Clone)]
pub struct TaskFilter {
    pub status: Option<TaskStatus>,
    pub project: Option<String>,
    pub tags: Vec<String>,
    pub search_term: Option<String>,
}

/// supported sort fields for task queries
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SortField {
    Urgency,
    Due,
    Created,
}

/// stable query ordering contract
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SortSpec {
    pub field: SortField,
    pub descending: bool,
}

impl Default for SortSpec {
    fn default() -> Self {
        Self {
            field: SortField::Urgency,
            descending: true,
        }
    }
}

/// offset-based pagination used by the current app
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Pagination {
    pub offset: usize,
    pub limit: usize,
}

impl Default for Pagination {
    fn default() -> Self {
        Self {
            offset: 0,
            limit: 100,
        }
    }
}

/// query shape for the engine
#[derive(Debug, Clone)]
pub struct Query {
    pub filter: TaskFilter,
    pub sort: SortSpec,
    pub pagination: Pagination,
}

impl Query {
    pub fn from_filter(filter: TaskFilter, offset: usize, limit: usize) -> Self {
        Self {
            filter,
            sort: SortSpec::default(),
            pagination: Pagination { offset, limit },
        }
    }
}

/// query result contract returned by the engine layer
#[derive(Debug, Clone)]
pub struct QueryResult {
    pub tasks: Vec<TaskSnapshot>,
    pub total: usize,
    pub next_offset: Option<usize>,
}
