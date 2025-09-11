import { 
  File, 
  FileWithResults, 
  ScanFolder, 
  ScanStatus, 
  OverviewStats, 
  CategoryStats, 
  TimelineStats,
  Trigger,
  NLPModel,
  ModelCategory
} from '../types';

const API_BASE = process.env.REACT_APP_API_URL || '/api';

class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

async function fetchApi<T>(endpoint: string, options?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  });

  if (!response.ok) {
    throw new ApiError(response.status, `API Error: ${response.statusText}`);
  }

  return response.json();
}

// Scanner control
export const scannerApi = {
  startScan: () => fetchApi('/scan/start', { method: 'POST' }),
  stopScan: () => fetchApi('/scan/stop', { method: 'POST' }),
  getStatus: (): Promise<ScanStatus> => fetchApi('/scan/status'),
  addFolder: (path: string, priority: number = 1) => 
    fetchApi('/scan/folder', {
      method: 'POST',
      body: JSON.stringify({ path, priority }),
    }),
  removeFolder: (id: number) => fetchApi(`/scan/folder/${id}`, { method: 'DELETE' }),
  getFolders: (): Promise<ScanFolder[]> => fetchApi('/scan/folders'),
};

// Results
export const resultsApi = {
  getResults: (params?: {
    page?: number;
    limit?: number;
    severity?: string;
    category?: string;
  }): Promise<{
    files: FileWithResults[];
    total: number;
    page: number;
    limit: number;
    total_pages: number;
  }> => {
    const searchParams = new URLSearchParams();
    if (params?.page) searchParams.append('page', params.page.toString());
    if (params?.limit) searchParams.append('limit', params.limit.toString());
    if (params?.severity) searchParams.append('severity', params.severity);
    if (params?.category) searchParams.append('category', params.category);
    
    return fetchApi(`/results?${searchParams}`);
  },
  
  getFileResult: (fileId: number): Promise<FileWithResults> => 
    fetchApi(`/results/${fileId}`),
    
  triggerRescan: (fileId: number) => 
    fetchApi(`/results/${fileId}/rescan`, { method: 'POST' }),
    
  overrideResult: (fileId: number, override: {
    overall_risk_score: number;
    highest_severity: string;
    notes: string;
  }) => fetchApi(`/results/${fileId}/override`, {
    method: 'PUT',
    body: JSON.stringify(override),
  }),
};

// Triggers
export const triggersApi = {
  getFileTriggers: (fileId: number): Promise<Trigger[]> => 
    fetchApi(`/triggers/${fileId}`),
    
  updateTrigger: (triggerId: number, update: {
    severity?: string;
    confidence_score?: number;
    notes?: string;
  }) => fetchApi(`/triggers/${triggerId}`, {
    method: 'PUT',
    body: JSON.stringify(update),
  }),
};

// Statistics
export const statsApi = {
  getOverview: (): Promise<OverviewStats> => fetchApi('/stats/overview'),
  getCategories: (): Promise<CategoryStats[]> => fetchApi('/stats/categories'),
  getTimeline: (): Promise<TimelineStats[]> => fetchApi('/stats/timeline'),
};

// Model Management
export const modelsApi = {
  getModels: (): Promise<NLPModel[]> => fetchApi('/models'),
  getCategories: (): Promise<ModelCategory[]> => fetchApi('/models/categories'),
  addCustomModel: (model: {
    name: string;
    huggingface_id: string;
    task_type?: string;
    categories: string[];
    weight?: number;
    config?: Record<string, any>;
  }) => fetchApi('/models', {
    method: 'POST',
    body: JSON.stringify(model),
  }),
  updateModel: (modelId: number, update: {
    weight?: number;
    is_active?: boolean;
    config?: Record<string, any>;
  }) => fetchApi(`/models/${modelId}`, {
    method: 'PUT',
    body: JSON.stringify(update),
  }),
  removeModel: (modelId: number) => 
    fetchApi(`/models/${modelId}`, { method: 'DELETE' }),
  reloadModel: (modelId: number) => 
    fetchApi(`/models/${modelId}/reload`, { method: 'POST' }),
  getModelStatus: (modelId: number): Promise<NLPModel> => 
    fetchApi(`/models/${modelId}/status`),
};