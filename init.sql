-- Content Warning Scanner Database Schema
-- Initialize database and create tables

-- Core Tables
CREATE TABLE files (
    id SERIAL PRIMARY KEY,
    path TEXT NOT NULL UNIQUE,
    filename TEXT NOT NULL,
    file_type VARCHAR(10),
    file_size BIGINT,
    file_hash VARCHAR(64),
    last_modified TIMESTAMP,
    last_scanned TIMESTAMP,
    scan_status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE scan_results (
    id SERIAL PRIMARY KEY,
    file_id INTEGER REFERENCES files(id) ON DELETE CASCADE,
    scan_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    model_version VARCHAR(50),
    processing_time_ms INTEGER,
    overall_risk_score FLOAT,
    highest_severity VARCHAR(20),
    total_triggers INTEGER DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE triggers (
    id SERIAL PRIMARY KEY,
    scan_result_id INTEGER REFERENCES scan_results(id) ON DELETE CASCADE,
    category VARCHAR(50),
    severity VARCHAR(20),
    confidence_score FLOAT,
    timestamp_start TIME,
    timestamp_end TIME,
    subtitle_text TEXT,
    context_before TEXT,
    context_after TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_preferences (
    id SERIAL PRIMARY KEY,
    profile_name VARCHAR(100) UNIQUE,
    settings JSONB,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE scan_folders (
    id SERIAL PRIMARY KEY,
    path TEXT NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT true,
    priority INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE nlp_models (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    huggingface_id VARCHAR(500) NOT NULL,
    task_type VARCHAR(100) NOT NULL DEFAULT 'text-classification',
    categories TEXT[] NOT NULL DEFAULT '{}',
    weight FLOAT NOT NULL DEFAULT 1.0,
    is_active BOOLEAN DEFAULT true,
    is_custom BOOLEAN DEFAULT false,
    model_config JSONB,
    status VARCHAR(50) DEFAULT 'pending',
    error_message TEXT,
    download_progress INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE model_categories (
    id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(200) NOT NULL,
    description TEXT,
    default_threshold FLOAT DEFAULT 0.7,
    severity_mapping JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_files_path ON files(path);
CREATE INDEX idx_files_scan_status ON files(scan_status);
CREATE INDEX idx_files_last_modified ON files(last_modified);
CREATE INDEX idx_scan_results_file_id ON scan_results(file_id);
CREATE INDEX idx_scan_results_scan_date ON scan_results(scan_date);
CREATE INDEX idx_triggers_scan_result_id ON triggers(scan_result_id);
CREATE INDEX idx_triggers_category_severity ON triggers(category, severity);
CREATE INDEX idx_triggers_confidence ON triggers(confidence_score);
CREATE INDEX idx_user_preferences_active ON user_preferences(is_active);
CREATE INDEX idx_nlp_models_active ON nlp_models(is_active);
CREATE INDEX idx_nlp_models_status ON nlp_models(status);
CREATE INDEX idx_model_categories_active ON model_categories(is_active);

-- Insert default user preference profile
INSERT INTO user_preferences (profile_name, settings, is_active) VALUES (
    'Default',
    '{
        "profile_name": "Default",
        "sensitivity_mode": "standard",
        "category_settings": {
            "sexual_assault": {
                "enabled": true,
                "thresholds": {"mild": 3, "moderate": 5, "severe": 7},
                "auto_flag_severity": "moderate"
            },
            "domestic_violence": {
                "enabled": true,
                "thresholds": {"mild": 3, "moderate": 5, "severe": 7},
                "auto_flag_severity": "moderate"
            },
            "self_harm": {
                "enabled": true,
                "thresholds": {"mild": 3, "moderate": 5, "severe": 7},
                "auto_flag_severity": "moderate"
            },
            "substance_abuse": {
                "enabled": true,
                "thresholds": {"mild": 4, "moderate": 6, "severe": 8},
                "auto_flag_severity": "severe"
            },
            "violence": {
                "enabled": true,
                "thresholds": {"mild": 4, "moderate": 6, "severe": 8},
                "auto_flag_severity": "severe"
            },
            "child_abuse": {
                "enabled": true,
                "thresholds": {"mild": 2, "moderate": 4, "severe": 6},
                "auto_flag_severity": "mild"
            },
            "eating_disorders": {
                "enabled": true,
                "thresholds": {"mild": 3, "moderate": 5, "severe": 7},
                "auto_flag_severity": "moderate"
            },
            "death_grief": {
                "enabled": true,
                "thresholds": {"mild": 4, "moderate": 6, "severe": 8},
                "auto_flag_severity": "severe"
            },
            "medical_content": {
                "enabled": true,
                "thresholds": {"mild": 5, "moderate": 7, "severe": 9},
                "auto_flag_severity": "severe"
            },
            "discrimination": {
                "enabled": true,
                "thresholds": {"mild": 3, "moderate": 5, "severe": 7},
                "auto_flag_severity": "moderate"
            },
            "animal_cruelty": {
                "enabled": true,
                "thresholds": {"mild": 3, "moderate": 5, "severe": 7},
                "auto_flag_severity": "moderate"
            },
            "body_horror": {
                "enabled": true,
                "thresholds": {"mild": 4, "moderate": 6, "severe": 8},
                "auto_flag_severity": "severe"
            }
        },
        "global_settings": {
            "skip_categories": [],
            "always_flag_categories": ["child_abuse"],
            "confidence_threshold": 0.7,
            "context_window_size": 5
        }
    }',
    true
);

-- Insert default model categories
INSERT INTO model_categories (category_name, display_name, description, default_threshold, severity_mapping, is_active) VALUES
('violence', 'Violence', 'Physical violence, fights, weapons, and aggressive behavior', 0.7, '{"mild": 0.3, "moderate": 0.6, "severe": 0.8}', true),
('sexual_assault', 'Sexual Assault', 'Sexual violence, assault, and non-consensual activities', 0.5, '{"mild": 0.2, "moderate": 0.5, "severe": 0.7}', true),
('self_harm', 'Self Harm', 'Suicide, self-injury, and self-destructive behavior', 0.6, '{"mild": 0.3, "moderate": 0.6, "severe": 0.8}', true),
('substance_abuse', 'Substance Abuse', 'Drug use, alcohol abuse, and addiction', 0.7, '{"mild": 0.4, "moderate": 0.7, "severe": 0.9}', true),
('hate_speech', 'Hate Speech', 'Discrimination, slurs, and prejudiced language', 0.6, '{"mild": 0.3, "moderate": 0.6, "severe": 0.8}', true),
('eating_disorders', 'Eating Disorders', 'Anorexia, bulimia, and disordered eating behaviors', 0.6, '{"mild": 0.3, "moderate": 0.6, "severe": 0.8}', true),
('child_abuse', 'Child Abuse', 'Harm to minors and inappropriate content involving children', 0.4, '{"mild": 0.2, "moderate": 0.4, "severe": 0.6}', true),
('domestic_violence', 'Domestic Violence', 'Intimate partner violence and family abuse', 0.6, '{"mild": 0.3, "moderate": 0.6, "severe": 0.8}', true),
('medical_content', 'Medical Content', 'Medical procedures, injuries, and health-related triggers', 0.8, '{"mild": 0.5, "moderate": 0.8, "severe": 0.9}', true),
('death_grief', 'Death & Grief', 'Death, dying, and grief-related content', 0.7, '{"mild": 0.4, "moderate": 0.7, "severe": 0.9}', true),
('animal_cruelty', 'Animal Cruelty', 'Harm to animals and animal abuse', 0.7, '{"mild": 0.4, "moderate": 0.7, "severe": 0.9}', true),
('body_horror', 'Body Horror', 'Graphic bodily harm and disturbing imagery', 0.8, '{"mild": 0.5, "moderate": 0.8, "severe": 0.9}', true);

-- Insert default NLP models
INSERT INTO nlp_models (name, huggingface_id, task_type, categories, weight, is_active, is_custom, model_config, status) VALUES
('Toxic Comment Classifier', 'martin-ha/toxic-comment-model', 'text-classification', 
 ARRAY['hate_speech', 'violence'], 0.8, true, false, 
 '{"labels": ["TOXIC", "SEVERE_TOXIC", "OBSCENE", "THREAT", "INSULT"], "threshold": 0.7}', 'ready'),

('NSFW Text Classifier', 'michellejieli/NSFW_text_classifier', 'text-classification', 
 ARRAY['sexual_assault'], 0.9, true, false,
 '{"labels": ["NSFW", "SFW"], "threshold": 0.6}', 'ready'),

('Abuse Detection Model', 'unitary/toxic-bert', 'text-classification',
 ARRAY['hate_speech', 'violence', 'domestic_violence'], 0.7, true, false,
 '{"labels": ["TOXICITY"], "threshold": 0.6}', 'ready'),

('Sentiment Analysis (Fallback)', 'cardiffnlp/twitter-roberta-base-sentiment-latest', 'text-classification',
 ARRAY['self_harm', 'eating_disorders', 'death_grief'], 0.5, true, false,
 '{"labels": ["NEGATIVE", "NEUTRAL", "POSITIVE"], "threshold": 0.7}', 'ready'),

('DistilBERT Base (General)', 'distilbert-base-uncased', 'text-classification',
 ARRAY['medical_content', 'body_horror'], 0.4, false, false,
 '{"task": "sentiment-analysis", "threshold": 0.7}', 'ready');