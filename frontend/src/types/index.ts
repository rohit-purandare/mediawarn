export interface File {
  id: number;
  path: string;
  filename: string;
  file_type: string;
  file_size: number;
  file_hash: string;
  last_modified: string;
  last_scanned?: string;
  scan_status: 'pending' | 'queued' | 'processing' | 'completed' | 'error';
  created_at: string;
}

export interface Trigger {
  id: number;
  scan_result_id: number;
  category: string;
  severity: 'none' | 'mild' | 'moderate' | 'severe';
  confidence_score: number;
  timestamp_start: string;
  timestamp_end: string;
  subtitle_text: string;
  context_before: string;
  context_after: string;
  created_at: string;
}

export interface ScanResult {
  id: number;
  file_id: number;
  scan_date: string;
  model_version: string;
  processing_time_ms: number;
  overall_risk_score: number;
  highest_severity: 'none' | 'mild' | 'moderate' | 'severe';
  total_triggers: number;
  metadata: string;
  created_at: string;
  triggers: Trigger[];
}

export interface FileWithResults extends File {
  scan_results: ScanResult[];
}

export interface ScanFolder {
  id: number;
  path: string;
  is_active: boolean;
  priority: number;
  created_at: string;
}

export interface ScanStatus {
  queue_length: number;
  status_counts: Array<{
    scan_status: string;
    count: number;
  }>;
  last_activity: string;
}

export interface OverviewStats {
  total_files: number;
  scanned_files: number;
  total_triggers: number;
  average_risk_score: number;
}

export interface CategoryStats {
  category: string;
  count: number;
  severity: string;
}

export interface TimelineStats {
  date: string;
  files_scanned: number;
  triggers_found: number;
}

export interface NLPModel {
  id: number;
  name: string;
  huggingface_id: string;
  task_type: string;
  categories: string[];
  weight: number;
  is_active: boolean;
  is_custom: boolean;
  model_config?: Record<string, any>;
  status: 'pending' | 'loading' | 'ready' | 'error';
  error_message?: string;
  download_progress: number;
  created_at: string;
  updated_at: string;
}

export interface ModelCategory {
  id: number;
  category_name: string;
  display_name: string;
  description: string;
  default_threshold: number;
  severity_mapping: Record<string, number>;
  is_active: boolean;
  created_at: string;
}