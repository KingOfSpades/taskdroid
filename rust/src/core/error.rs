use std::error::Error;
use std::fmt::{Display, Formatter};

/// stable error contract for the task engine
#[derive(Debug, Clone)]
pub enum TaskError {
    NotFound(String),
    InvalidInput(String),
    Conflict(String),
    Storage(String),
    Sync(String),
    Busy(String),
    Internal(String),
}

pub type Result<T> = std::result::Result<T, TaskError>;

impl TaskError {
    pub fn not_found(message: impl Into<String>) -> Self {
        Self::NotFound(message.into())
    }

    pub fn invalid_input(message: impl Into<String>) -> Self {
        Self::InvalidInput(message.into())
    }

    pub fn conflict(message: impl Into<String>) -> Self {
        Self::Conflict(message.into())
    }

    pub fn storage(message: impl Into<String>) -> Self {
        Self::Storage(message.into())
    }

    pub fn sync(message: impl Into<String>) -> Self {
        Self::Sync(message.into())
    }

    pub fn busy(message: impl Into<String>) -> Self {
        Self::Busy(message.into())
    }

    pub fn internal(message: impl Into<String>) -> Self {
        Self::Internal(message.into())
    }
}

impl Display for TaskError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(message) => write!(f, "Not found: {message}"),
            Self::InvalidInput(message) => write!(f, "Invalid input: {message}"),
            Self::Conflict(message) => write!(f, "Conflict: {message}"),
            Self::Storage(message) => write!(f, "Storage error: {message}"),
            Self::Sync(message) => write!(f, "Sync error: {message}"),
            Self::Busy(message) => write!(f, "Busy: {message}"),
            Self::Internal(message) => write!(f, "Internal error: {message}"),
        }
    }
}

impl Error for TaskError {}
