import os
import logging
import json
from typing import Dict, List, Tuple, Optional
from transformers import AutoTokenizer, AutoModelForSequenceClassification, pipeline
import torch
import asyncpg
import asyncio

logger = logging.getLogger(__name__)

class ModelManager:
    def __init__(self):
        self.models = {}
        self.categories = {}
        self.db_pool = None
        
    async def initialize(self):
        """Initialize database connection and load models"""
        await self._connect_database()
        await self._load_categories()
        await self._load_models()
        
    async def _connect_database(self):
        """Connect to PostgreSQL database"""
        database_url = os.getenv("DATABASE_URL", "postgresql://cws:password@localhost:5432/cws")
        try:
            self.db_pool = await asyncpg.create_pool(database_url, min_size=1, max_size=5)
            logger.info("Connected to database for model management")
        except Exception as e:
            logger.error(f"Failed to connect to database: {e}")
            raise
            
    async def _load_categories(self):
        """Load trigger categories from database"""
        async with self.db_pool.acquire() as conn:
            rows = await conn.fetch("""
                SELECT category_name, display_name, description, default_threshold, severity_mapping
                FROM model_categories 
                WHERE is_active = true
            """)
            
            for row in rows:
                self.categories[row['category_name']] = {
                    'display_name': row['display_name'],
                    'description': row['description'],
                    'threshold': row['default_threshold'],
                    'severity_mapping': json.loads(row['severity_mapping']) if row['severity_mapping'] else {}
                }
                
        logger.info(f"Loaded {len(self.categories)} trigger categories")
        
    async def _load_models(self):
        """Load active models from database"""
        async with self.db_pool.acquire() as conn:
            rows = await conn.fetch("""
                SELECT id, name, huggingface_id, task_type, categories, weight, model_config, status
                FROM nlp_models 
                WHERE is_active = true AND status = 'ready'
                ORDER BY weight DESC
            """)
            
        for row in rows:
            try:
                await self._load_single_model(row)
            except Exception as e:
                logger.error(f"Failed to load model {row['name']}: {e}")
                # Update model status to error in database
                await self._update_model_status(row['id'], 'error', str(e))
                
        logger.info(f"Successfully loaded {len(self.models)} models")
        
    async def _load_single_model(self, model_row):
        """Load a single model from Hugging Face"""
        model_id = model_row['id']
        name = model_row['name']
        hf_id = model_row['huggingface_id']
        task_type = model_row['task_type']
        categories = model_row['categories']
        weight = float(model_row['weight'])
        config = json.loads(model_row['model_config']) if model_row['model_config'] else {}
        
        logger.info(f"Loading model: {name} ({hf_id})")
        
        try:
            # Update status to loading
            await self._update_model_status(model_id, 'loading', None)
            
            # Load tokenizer and model
            tokenizer = AutoTokenizer.from_pretrained(hf_id)
            
            # Create pipeline based on task type
            if task_type == 'text-classification':
                pipe = pipeline(
                    "text-classification",
                    model=hf_id,
                    tokenizer=tokenizer,
                    device=-1,  # CPU
                    return_all_scores=True
                )
            else:
                # Fallback to sentiment analysis
                pipe = pipeline(
                    "sentiment-analysis",
                    model=hf_id,
                    tokenizer=tokenizer,
                    device=-1
                )
            
            # Store model with metadata
            self.models[model_id] = {
                'name': name,
                'huggingface_id': hf_id,
                'pipeline': pipe,
                'categories': categories,
                'weight': weight,
                'config': config,
                'task_type': task_type
            }
            
            # Update status to ready
            await self._update_model_status(model_id, 'ready', None)
            logger.info(f"Successfully loaded model: {name}")
            
        except Exception as e:
            await self._update_model_status(model_id, 'error', str(e))
            raise
            
    async def _update_model_status(self, model_id: int, status: str, error_message: Optional[str]):
        """Update model status in database"""
        async with self.db_pool.acquire() as conn:
            await conn.execute("""
                UPDATE nlp_models 
                SET status = $1, error_message = $2, updated_at = CURRENT_TIMESTAMP
                WHERE id = $3
            """, status, error_message, model_id)
            
    async def analyze_text(self, text: str, context_before: str = "", context_after: str = "") -> List[Dict]:
        """Analyze text for triggers using loaded models"""
        if not self.models:
            logger.warning("No models loaded for analysis")
            return []
            
        # Combine text with context
        full_text = f"{context_before} {text} {context_after}".strip()
        if len(full_text) > 512:
            full_text = full_text[:512]  # Truncate for model limits
            
        results = []
        
        # Run each model
        for model_id, model_info in self.models.items():
            try:
                model_results = await self._run_model_analysis(model_info, full_text, text)
                results.extend(model_results)
            except Exception as e:
                logger.error(f"Error running model {model_info['name']}: {e}")
                
        # Deduplicate and combine results by category
        combined_results = self._combine_results(results)
        
        return combined_results
        
    async def _run_model_analysis(self, model_info: Dict, full_text: str, original_text: str) -> List[Dict]:
        """Run analysis with a specific model"""
        pipeline_obj = model_info['pipeline']
        categories = model_info['categories']
        weight = model_info['weight']
        config = model_info['config']
        
        # Get model predictions
        predictions = pipeline_obj(full_text)
        
        results = []
        
        # Process predictions based on model type
        if isinstance(predictions, list) and len(predictions) > 0:
            if isinstance(predictions[0], dict):
                # Multi-label classification
                for pred in predictions:
                    label = pred['label'].upper()
                    score = pred['score']
                    
                    # Map model labels to our categories
                    detected_categories = self._map_label_to_categories(label, categories, config)
                    
                    for category in detected_categories:
                        if category in self.categories:
                            # Apply model weight and threshold
                            adjusted_score = score * weight
                            threshold = config.get('threshold', self.categories[category]['threshold'])
                            
                            if adjusted_score >= threshold:
                                severity = self._score_to_severity(adjusted_score, category)
                                confidence = min(adjusted_score, 1.0)
                                
                                results.append({
                                    'category': category,
                                    'severity': severity,
                                    'score': round(adjusted_score, 3),
                                    'confidence': round(confidence, 3),
                                    'model_name': model_info['name'],
                                    'model_label': label,
                                    'text': original_text
                                })
        
        return results
        
    def _map_label_to_categories(self, label: str, model_categories: List[str], config: Dict) -> List[str]:
        """Map model output labels to trigger categories"""
        label_mappings = {
            # Toxic/Hate Speech models
            'TOXIC': ['hate_speech', 'violence'],
            'SEVERE_TOXIC': ['hate_speech', 'violence'],
            'OBSCENE': ['hate_speech'],
            'THREAT': ['violence'],
            'INSULT': ['hate_speech'],
            'TOXICITY': ['hate_speech', 'violence'],
            
            # NSFW models
            'NSFW': ['sexual_assault'],
            
            # Sentiment models (fallback)
            'NEGATIVE': model_categories,  # Apply to all assigned categories
            'POSITIVE': [],  # No triggers for positive sentiment
        }
        
        # Use config mappings if provided
        if 'label_mappings' in config:
            label_mappings.update(config['label_mappings'])
            
        return label_mappings.get(label, [])
        
    def _score_to_severity(self, score: float, category: str) -> str:
        """Convert score to severity based on category settings"""
        if category not in self.categories:
            # Fallback severity mapping
            if score <= 0.3:
                return "mild"
            elif score <= 0.6:
                return "moderate"
            else:
                return "severe"
                
        mapping = self.categories[category].get('severity_mapping', {})
        
        if score >= mapping.get('severe', 0.8):
            return "severe"
        elif score >= mapping.get('moderate', 0.6):
            return "moderate"
        elif score >= mapping.get('mild', 0.3):
            return "mild"
        else:
            return "none"
            
    def _combine_results(self, results: List[Dict]) -> List[Dict]:
        """Combine results from multiple models for the same category"""
        combined = {}
        
        for result in results:
            category = result['category']
            
            if category not in combined:
                combined[category] = result
            else:
                # Combine scores using weighted average
                existing = combined[category]
                total_weight = 1.0  # Current weight
                existing_weight = 1.0  # Existing weight
                
                # Calculate weighted average
                new_score = (existing['score'] * existing_weight + result['score'] * total_weight) / (existing_weight + total_weight)
                new_confidence = max(existing['confidence'], result['confidence'])
                
                # Take the more severe result
                severities = {'none': 0, 'mild': 1, 'moderate': 2, 'severe': 3}
                if severities.get(result['severity'], 0) > severities.get(existing['severity'], 0):
                    combined[category].update({
                        'severity': result['severity'],
                        'score': round(new_score, 3),
                        'confidence': round(new_confidence, 3),
                        'model_name': f"{existing['model_name']}, {result['model_name']}"
                    })
                    
        return list(combined.values())
        
    async def add_custom_model(self, name: str, huggingface_id: str, categories: List[str], 
                             task_type: str = 'text-classification', weight: float = 1.0, 
                             config: Dict = None) -> int:
        """Add a custom model to the database and load it"""
        if config is None:
            config = {}
            
        async with self.db_pool.acquire() as conn:
            model_id = await conn.fetchval("""
                INSERT INTO nlp_models (name, huggingface_id, task_type, categories, weight, 
                                      is_custom, model_config, status, is_active)
                VALUES ($1, $2, $3, $4, $5, true, $6, 'pending', true)
                RETURNING id
            """, name, huggingface_id, task_type, categories, weight, json.dumps(config))
            
        # Try to load the model
        try:
            model_row = {
                'id': model_id,
                'name': name,
                'huggingface_id': huggingface_id,
                'task_type': task_type,
                'categories': categories,
                'weight': weight,
                'model_config': json.dumps(config),
                'status': 'pending'
            }
            await self._load_single_model(model_row)
            return model_id
        except Exception as e:
            logger.error(f"Failed to load custom model {name}: {e}")
            raise
            
    async def remove_model(self, model_id: int):
        """Remove a model from database and memory"""
        # Remove from memory
        if model_id in self.models:
            del self.models[model_id]
            
        # Update database
        async with self.db_pool.acquire() as conn:
            await conn.execute("""
                UPDATE nlp_models SET is_active = false WHERE id = $1
            """, model_id)
            
    async def get_model_status(self) -> List[Dict]:
        """Get status of all models"""
        async with self.db_pool.acquire() as conn:
            rows = await conn.fetch("""
                SELECT id, name, huggingface_id, task_type, categories, weight, 
                       status, error_message, is_custom, created_at
                FROM nlp_models 
                WHERE is_active = true
                ORDER BY weight DESC, created_at DESC
            """)
            
        return [dict(row) for row in rows]

# Global model manager instance
model_manager = ModelManager()

async def initialize_models():
    """Initialize the global model manager"""
    await model_manager.initialize()

def get_loaded_models():
    """Get list of loaded models"""
    return [info['name'] for info in model_manager.models.values()]

async def analyze_subtitle_text(text: str, context_before: str = "", context_after: str = "") -> List[Dict]:
    """Analyze subtitle text for triggers"""
    return await model_manager.analyze_text(text, context_before, context_after)

async def add_custom_model(name: str, huggingface_id: str, categories: List[str], **kwargs) -> int:
    """Add a custom Hugging Face model"""
    return await model_manager.add_custom_model(name, huggingface_id, categories, **kwargs)

async def get_model_status() -> List[Dict]:
    """Get status of all models"""
    return await model_manager.get_model_status()

async def remove_model(model_id: int):
    """Remove a model"""
    await model_manager.remove_model(model_id)