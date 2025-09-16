"""
Structured logging configuration for MediaWarn NLP service.
Implements industry-standard structured logging with JSON format.
"""

import logging
import os
import sys
import time
from typing import Any, Dict, Optional

import structlog
from pythonjsonlogger import jsonlogger


def setup_logging() -> structlog.BoundLogger:
    """
    Configure structured logging for the NLP service.
    Returns a configured structlog logger.
    """
    # Configure log level from environment
    log_level = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, log_level, logging.INFO)

    # Create JSON formatter with custom field names (industry standard)
    json_formatter = jsonlogger.JsonFormatter(
        fmt="%(timestamp)s %(level)s %(service)s %(message)s",
        rename_fields={
            "asctime": "timestamp",
            "levelname": "level",
            "name": "logger_name",
            "funcName": "function",
            "lineno": "line_number",
        },
        datefmt="%Y-%m-%dT%H:%M:%S.%fZ"
    )

    # Configure root logger
    logging.basicConfig(
        level=level,
        stream=sys.stdout,
        format="%(message)s"
    )

    # Get root logger and apply JSON formatter
    root_logger = logging.getLogger()
    root_logger.handlers.clear()

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(json_formatter)
    root_logger.addHandler(handler)
    root_logger.setLevel(level)

    # Configure structlog
    structlog.configure(
        processors=[
            # Add service name to all log records
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            # Add service identifier
            add_service_info,
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    # Create and return bound logger
    logger = structlog.get_logger("mediawarn-nlp")
    return logger


def add_service_info(logger, method_name: str, event_dict: dict) -> dict:
    """Add service information to log records."""
    event_dict["service"] = "mediawarn-nlp"
    event_dict["version"] = os.getenv("APP_VERSION", "dev")
    return event_dict


class LoggerMixin:
    """Mixin class to add structured logging to other classes."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.logger = structlog.get_logger(self.__class__.__name__)


def log_startup(component: str, version: str, config: Dict[str, Any]) -> None:
    """Log application startup with configuration details."""
    logger = structlog.get_logger("startup")
    logger.info(
        "Service starting up",
        component=component,
        version=version,
        config=config,
        type="startup"
    )


def log_shutdown(component: str, reason: str) -> None:
    """Log application shutdown."""
    logger = structlog.get_logger("shutdown")
    logger.info(
        "Service shutting down",
        component=component,
        reason=reason,
        type="shutdown"
    )


def log_model_operation(
    operation: str,
    model_name: str,
    duration_ms: Optional[int] = None,
    input_tokens: Optional[int] = None,
    output_tokens: Optional[int] = None,
    error: Optional[str] = None
) -> None:
    """Log ML model operations with performance metrics."""
    logger = structlog.get_logger("model")

    log_data = {
        "operation": operation,
        "model_name": model_name,
        "type": "model_operation"
    }

    if duration_ms is not None:
        log_data["duration_ms"] = duration_ms
    if input_tokens is not None:
        log_data["input_tokens"] = input_tokens
    if output_tokens is not None:
        log_data["output_tokens"] = output_tokens

    if error:
        logger.error("Model operation failed", error=error, **log_data)
    else:
        logger.info("Model operation completed", **log_data)


def log_processing_operation(
    operation: str,
    file_path: str,
    duration_ms: int,
    input_size: int,
    output_size: Optional[int] = None,
    error: Optional[str] = None
) -> None:
    """Log file processing operations."""
    logger = structlog.get_logger("processing")

    log_data = {
        "operation": operation,
        "file_path": file_path,
        "duration_ms": duration_ms,
        "input_size": input_size,
        "type": "processing_operation"
    }

    if output_size is not None:
        log_data["output_size"] = output_size

    if error:
        logger.error("Processing operation failed", error=error, **log_data)
    else:
        logger.info("Processing operation completed", **log_data)


def log_api_request(
    method: str,
    path: str,
    status_code: int,
    duration_ms: int,
    client_ip: Optional[str] = None,
    user_agent: Optional[str] = None,
    request_id: Optional[str] = None
) -> None:
    """Log API requests with performance metrics."""
    logger = structlog.get_logger("api")

    logger.info(
        "HTTP request completed",
        method=method,
        path=path,
        status_code=status_code,
        duration_ms=duration_ms,
        client_ip=client_ip,
        user_agent=user_agent,
        request_id=request_id,
        type="http_request"
    )


def log_database_operation(
    operation: str,
    table: str,
    duration_ms: int,
    rows_affected: int,
    error: Optional[str] = None
) -> None:
    """Log database operations."""
    logger = structlog.get_logger("database")

    log_data = {
        "operation": operation,
        "table": table,
        "duration_ms": duration_ms,
        "rows_affected": rows_affected,
        "type": "database_operation"
    }

    if error:
        logger.error("Database operation failed", error=error, **log_data)
    else:
        logger.debug("Database operation completed", **log_data)


def log_queue_operation(
    operation: str,
    queue_name: str,
    message_count: int,
    error: Optional[str] = None
) -> None:
    """Log queue operations (Celery/Redis)."""
    logger = structlog.get_logger("queue")

    log_data = {
        "operation": operation,
        "queue_name": queue_name,
        "message_count": message_count,
        "type": "queue_operation"
    }

    if error:
        logger.error("Queue operation failed", error=error, **log_data)
    else:
        logger.debug("Queue operation completed", **log_data)


# Performance measurement decorator
def log_performance(operation_name: str):
    """Decorator to automatically log operation performance."""
    def decorator(func):
        def wrapper(*args, **kwargs):
            logger = structlog.get_logger("performance")
            start_time = time.time()

            try:
                result = func(*args, **kwargs)
                duration_ms = int((time.time() - start_time) * 1000)

                logger.info(
                    "Operation completed",
                    operation=operation_name,
                    function=func.__name__,
                    duration_ms=duration_ms,
                    type="performance"
                )
                return result

            except Exception as e:
                duration_ms = int((time.time() - start_time) * 1000)

                logger.error(
                    "Operation failed",
                    operation=operation_name,
                    function=func.__name__,
                    duration_ms=duration_ms,
                    error=str(e),
                    type="performance"
                )
                raise

        return wrapper
    return decorator


# Initialize logger when module is imported
_logger = setup_logging()

# Export the configured logger
get_logger = structlog.get_logger