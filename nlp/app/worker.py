import asyncio
import json
import logging
import time
from typing import Optional

import redis.asyncio as redis
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from app.models import analyze_subtitle_text
from app.subtitle_parser import parse_subtitle_file
import os

logger = logging.getLogger(__name__)

class NLPWorker:
    def __init__(self):
        self.redis_client = None
        self.db_session = None
        self.running = False
        
    async def initialize(self):
        """Initialize Redis and Database connections"""
        redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
        database_url = os.getenv("DATABASE_URL", "postgresql://cws:password@localhost:5432/cws")
        
        try:
            self.redis_client = redis.from_url(redis_url)
            await self.redis_client.ping()
            logger.info("Connected to Redis")
            
            # Initialize database connection
            engine = create_engine(database_url)
            SessionLocal = sessionmaker(bind=engine)
            self.db_session = SessionLocal()
            logger.info("Connected to PostgreSQL")
            
        except Exception as e:
            logger.error(f"Failed to initialize connections: {e}")
            raise
    
    async def start(self):
        """Start the worker loop"""
        await self.initialize()
        self.running = True
        logger.info("NLP Worker started")
        
        while self.running:
            try:
                # Pop job from queue with timeout
                job_data = await self.redis_client.brpop("scan_jobs", timeout=5)
                
                if job_data:
                    _, job_json = job_data
                    job = json.loads(job_json)
                    logger.info(f"Processing job: {job['id']}")
                    
                    await self.process_job(job)
                    
            except asyncio.CancelledError:
                logger.info("Worker cancelled")
                break
            except Exception as e:
                logger.error(f"Worker error: {e}")
                await asyncio.sleep(1)
        
        await self.cleanup()
    
    async def process_job(self, job: dict):
        """Process a single scan job"""
        start_time = time.time()
        file_path = job["file_path"]
        
        try:
            # Update file status to processing
            await self.update_file_status(file_path, "processing")
            
            # Parse subtitle content
            subtitle_entries = await parse_subtitle_file(file_path)
            
            if not subtitle_entries:
                logger.warning(f"No subtitle content found in {file_path}")
                await self.update_file_status(file_path, "completed")
                return
            
            # Analyze each subtitle entry
            all_triggers = []
            
            for i, entry in enumerate(subtitle_entries):
                # Get context (previous and next entries)
                context_before = ""
                context_after = ""
                
                if i > 0:
                    context_before = subtitle_entries[i-1]["text"]
                if i < len(subtitle_entries) - 1:
                    context_after = subtitle_entries[i+1]["text"]
                
                # Analyze the text (now async)
                triggers = await analyze_subtitle_text(
                    entry["text"], 
                    context_before, 
                    context_after
                )
                
                for trigger in triggers:
                    trigger.update({
                        "timestamp_start": entry["start_time"],
                        "timestamp_end": entry["end_time"],
                        "subtitle_text": entry["text"],
                        "context_before": context_before,
                        "context_after": context_after
                    })
                    all_triggers.append(trigger)
            
            # Calculate processing time
            processing_time_ms = int((time.time() - start_time) * 1000)
            
            # Calculate overall scores
            overall_risk_score = 0
            highest_severity = "none"
            
            if all_triggers:
                # Calculate risk score as weighted average
                total_score = sum(t["score"] * t["confidence"] for t in all_triggers)
                total_weight = sum(t["confidence"] for t in all_triggers)
                overall_risk_score = total_score / total_weight if total_weight > 0 else 0
                
                # Find highest severity
                severity_levels = {"none": 0, "mild": 1, "moderate": 2, "severe": 3}
                max_severity_level = max(severity_levels[t["severity"]] for t in all_triggers)
                highest_severity = [k for k, v in severity_levels.items() if v == max_severity_level][0]
            
            # Store results in database
            await self.store_scan_results(
                file_path,
                all_triggers,
                processing_time_ms,
                overall_risk_score,
                highest_severity
            )
            
            # Update file status
            await self.update_file_status(file_path, "completed")
            
            logger.info(f"Completed processing {file_path}: {len(all_triggers)} triggers found, "
                       f"overall risk: {overall_risk_score:.2f}, highest severity: {highest_severity}")
            
        except Exception as e:
            logger.error(f"Error processing {file_path}: {e}")
            await self.update_file_status(file_path, "error")
    
    async def update_file_status(self, file_path: str, status: str):
        """Update file status in database"""
        try:
            query = text("""
                UPDATE files 
                SET scan_status = :status, 
                    last_scanned = CURRENT_TIMESTAMP 
                WHERE path = :path
            """)
            
            self.db_session.execute(query, {"status": status, "path": file_path})
            self.db_session.commit()
            
        except Exception as e:
            logger.error(f"Error updating file status: {e}")
            self.db_session.rollback()
    
    async def store_scan_results(self, file_path: str, triggers: list, processing_time_ms: int, 
                                overall_risk_score: float, highest_severity: str):
        """Store scan results in database"""
        try:
            # Get file ID
            file_query = text("SELECT id FROM files WHERE path = :path")
            result = self.db_session.execute(file_query, {"path": file_path}).fetchone()
            
            if not result:
                logger.error(f"File not found in database: {file_path}")
                return
            
            file_id = result[0]
            
            # Insert scan result
            scan_result_query = text("""
                INSERT INTO scan_results 
                (file_id, model_version, processing_time_ms, overall_risk_score, 
                 highest_severity, total_triggers, metadata)
                VALUES (:file_id, :model_version, :processing_time_ms, :overall_risk_score,
                        :highest_severity, :total_triggers, :metadata)
                RETURNING id
            """)
            
            metadata = json.dumps({"processed_at": time.time()})
            
            scan_result = self.db_session.execute(scan_result_query, {
                "file_id": file_id,
                "model_version": "v1.0",
                "processing_time_ms": processing_time_ms,
                "overall_risk_score": overall_risk_score,
                "highest_severity": highest_severity,
                "total_triggers": len(triggers),
                "metadata": metadata
            }).fetchone()
            
            scan_result_id = scan_result[0]
            
            # Insert triggers
            if triggers:
                trigger_query = text("""
                    INSERT INTO triggers
                    (scan_result_id, category, severity, confidence_score, timestamp_start,
                     timestamp_end, subtitle_text, context_before, context_after)
                    VALUES (:scan_result_id, :category, :severity, :confidence_score,
                            :timestamp_start, :timestamp_end, :subtitle_text,
                            :context_before, :context_after)
                """)
                
                for trigger in triggers:
                    self.db_session.execute(trigger_query, {
                        "scan_result_id": scan_result_id,
                        "category": trigger["category"],
                        "severity": trigger["severity"],
                        "confidence_score": trigger["confidence"],
                        "timestamp_start": trigger["timestamp_start"],
                        "timestamp_end": trigger["timestamp_end"],
                        "subtitle_text": trigger["subtitle_text"],
                        "context_before": trigger.get("context_before", ""),
                        "context_after": trigger.get("context_after", "")
                    })
            
            self.db_session.commit()
            logger.info(f"Stored scan results for {file_path}: {len(triggers)} triggers")
            
        except Exception as e:
            logger.error(f"Error storing scan results: {e}")
            self.db_session.rollback()
    
    def stop(self):
        """Stop the worker"""
        self.running = False
    
    async def cleanup(self):
        """Clean up connections"""
        if self.redis_client:
            await self.redis_client.close()
        if self.db_session:
            self.db_session.close()

async def start_worker():
    """Start the NLP worker"""
    worker = NLPWorker()
    try:
        await worker.start()
    except asyncio.CancelledError:
        worker.stop()
    except Exception as e:
        logger.error(f"Worker startup failed: {e}")
        raise