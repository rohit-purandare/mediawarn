import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { 
  Folder, 
  Plus, 
  Trash2, 
  Settings as SettingsIcon,
  Save,
  AlertTriangle,
  Brain,
  Download,
  CheckCircle,
  XCircle,
  Loader,
  RefreshCw,
  Edit,
  Eye,
  EyeOff
} from 'lucide-react';
import { scannerApi, modelsApi } from '../api';
import { NLPModel, ModelCategory } from '../types';

export default function Settings() {
  const [newFolderPath, setNewFolderPath] = useState('');
  const [showAddFolder, setShowAddFolder] = useState(false);
  const [showAddModel, setShowAddModel] = useState(false);
  const [newModel, setNewModel] = useState({
    name: '',
    huggingface_id: '',
    task_type: 'text-classification',
    categories: [] as string[],
    weight: 1.0
  });
  
  const queryClient = useQueryClient();

  const { data: folders, refetch: refetchFolders } = useQuery({
    queryKey: ['scanFolders'],
    queryFn: scannerApi.getFolders,
  });

  const { data: models, refetch: refetchModels } = useQuery({
    queryKey: ['models'],
    queryFn: modelsApi.getModels,
  });

  const { data: modelCategories } = useQuery({
    queryKey: ['modelCategories'],
    queryFn: modelsApi.getCategories,
  });

  const addModelMutation = useMutation({
    mutationFn: modelsApi.addCustomModel,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['models'] });
      setShowAddModel(false);
      setNewModel({
        name: '',
        huggingface_id: '',
        task_type: 'text-classification',
        categories: [],
        weight: 1.0
      });
    }
  });

  const updateModelMutation = useMutation({
    mutationFn: ({ modelId, update }: { modelId: number; update: any }) =>
      modelsApi.updateModel(modelId, update),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['models'] });
    }
  });

  const removeModelMutation = useMutation({
    mutationFn: modelsApi.removeModel,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['models'] });
    }
  });

  const reloadModelMutation = useMutation({
    mutationFn: modelsApi.reloadModel,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['models'] });
    }
  });

  const handleAddFolder = async () => {
    if (newFolderPath.trim()) {
      try {
        await scannerApi.addFolder(newFolderPath.trim());
        setNewFolderPath('');
        setShowAddFolder(false);
        refetchFolders();
      } catch (error) {
        console.error('Error adding folder:', error);
      }
    }
  };

  const handleRemoveFolder = async (id: number) => {
    try {
      await scannerApi.removeFolder(id);
      refetchFolders();
    } catch (error) {
      console.error('Error removing folder:', error);
    }
  };

  const handleAddModel = async () => {
    if (newModel.name && newModel.huggingface_id && newModel.categories.length > 0) {
      addModelMutation.mutate(newModel);
    }
  };

  const handleToggleModel = (model: NLPModel) => {
    updateModelMutation.mutate({
      modelId: model.id,
      update: { is_active: !model.is_active }
    });
  };

  const handleUpdateModelWeight = (modelId: number, weight: number) => {
    updateModelMutation.mutate({
      modelId,
      update: { weight }
    });
  };

  const handleRemoveModel = (modelId: number) => {
    if (window.confirm('Are you sure you want to remove this model?')) {
      removeModelMutation.mutate(modelId);
    }
  };

  const handleReloadModel = (modelId: number) => {
    reloadModelMutation.mutate(modelId);
  };

  const getStatusIcon = (status: NLPModel['status']) => {
    switch (status) {
      case 'ready':
        return <CheckCircle className="h-5 w-5 text-success-600" />;
      case 'loading':
        return <Loader className="h-5 w-5 text-primary-600 animate-spin" />;
      case 'error':
        return <XCircle className="h-5 w-5 text-danger-600" />;
      default:
        return <Download className="h-5 w-5 text-gray-400" />;
    }
  };

  const getStatusText = (status: NLPModel['status']) => {
    switch (status) {
      case 'ready':
        return 'Ready';
      case 'loading':
        return 'Loading...';
      case 'error':
        return 'Error';
      case 'pending':
        return 'Pending';
      default:
        return 'Unknown';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center space-x-3">
        <SettingsIcon className="h-8 w-8 text-primary-600" />
        <h1 className="text-2xl font-bold text-gray-900">Settings</h1>
      </div>

      {/* Scan Folders */}
      <div className="card p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold text-gray-900">Scan Folders</h2>
          <button
            onClick={() => setShowAddFolder(true)}
            className="btn-primary"
          >
            <Plus className="h-4 w-4 mr-2" />
            Add Folder
          </button>
        </div>

        {/* Add Folder Form */}
        {showAddFolder && (
          <div className="mb-6 p-4 bg-gray-50 rounded-lg">
            <h3 className="text-sm font-medium text-gray-900 mb-3">Add New Scan Folder</h3>
            <div className="flex space-x-3">
              <input
                type="text"
                value={newFolderPath}
                onChange={(e) => setNewFolderPath(e.target.value)}
                placeholder="/path/to/media/folder"
                className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
              <button
                onClick={handleAddFolder}
                className="btn-primary"
              >
                Add
              </button>
              <button
                onClick={() => {
                  setShowAddFolder(false);
                  setNewFolderPath('');
                }}
                className="btn-secondary"
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        {/* Folders List */}
        <div className="space-y-3">
          {folders && folders.length > 0 ? (
            folders.map((folder) => (
              <div
                key={folder.id}
                className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
              >
                <div className="flex items-center space-x-3">
                  <Folder className="h-5 w-5 text-gray-600" />
                  <div>
                    <p className="text-sm font-medium text-gray-900">{folder.path}</p>
                    <p className="text-xs text-gray-600">
                      Priority: {folder.priority} • 
                      {folder.is_active ? (
                        <span className="text-success-600"> Active</span>
                      ) : (
                        <span className="text-gray-500"> Inactive</span>
                      )}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => handleRemoveFolder(folder.id)}
                  className="p-2 text-gray-400 hover:text-danger-600 transition-colors"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))
          ) : (
            <div className="text-center py-8">
              <Folder className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600">No scan folders configured</p>
              <p className="text-sm text-gray-500">Add a folder to start scanning</p>
            </div>
          )}
        </div>
      </div>

      {/* Model Management */}
      <div className="card p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-3">
            <Brain className="h-6 w-6 text-primary-600" />
            <h2 className="text-lg font-semibold text-gray-900">AI Models</h2>
          </div>
          <button
            onClick={() => setShowAddModel(true)}
            className="btn-primary"
          >
            <Plus className="h-4 w-4 mr-2" />
            Add Custom Model
          </button>
        </div>

        {/* Add Model Form */}
        {showAddModel && (
          <div className="mb-6 p-4 bg-gray-50 rounded-lg">
            <h3 className="text-sm font-medium text-gray-900 mb-4">Add Custom Hugging Face Model</h3>
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Model Name
                  </label>
                  <input
                    type="text"
                    value={newModel.name}
                    onChange={(e) => setNewModel({ ...newModel, name: e.target.value })}
                    placeholder="My Custom Model"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Hugging Face Model ID
                  </label>
                  <input
                    type="text"
                    value={newModel.huggingface_id}
                    onChange={(e) => setNewModel({ ...newModel, huggingface_id: e.target.value })}
                    placeholder="unitary/toxic-bert"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  />
                </div>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Task Type
                  </label>
                  <select
                    value={newModel.task_type}
                    onChange={(e) => setNewModel({ ...newModel, task_type: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  >
                    <option value="text-classification">Text Classification</option>
                    <option value="sentiment-analysis">Sentiment Analysis</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Weight (0.1 - 2.0)
                  </label>
                  <input
                    type="number"
                    min="0.1"
                    max="2.0"
                    step="0.1"
                    value={newModel.weight}
                    onChange={(e) => setNewModel({ ...newModel, weight: parseFloat(e.target.value) })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Target Categories
                </label>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
                  {modelCategories?.map((category) => (
                    <label key={category.category_name} className="flex items-center">
                      <input
                        type="checkbox"
                        checked={newModel.categories.includes(category.category_name)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setNewModel({
                              ...newModel,
                              categories: [...newModel.categories, category.category_name]
                            });
                          } else {
                            setNewModel({
                              ...newModel,
                              categories: newModel.categories.filter(c => c !== category.category_name)
                            });
                          }
                        }}
                        className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
                      />
                      <span className="ml-2 text-sm text-gray-700">{category.display_name}</span>
                    </label>
                  ))}
                </div>
              </div>

              <div className="flex justify-end space-x-3">
                <button
                  onClick={() => {
                    setShowAddModel(false);
                    setNewModel({
                      name: '',
                      huggingface_id: '',
                      task_type: 'text-classification',
                      categories: [],
                      weight: 1.0
                    });
                  }}
                  className="btn-secondary"
                  disabled={addModelMutation.isPending}
                >
                  Cancel
                </button>
                <button
                  onClick={handleAddModel}
                  className="btn-primary"
                  disabled={addModelMutation.isPending || !newModel.name || !newModel.huggingface_id || newModel.categories.length === 0}
                >
                  {addModelMutation.isPending ? (
                    <>
                      <Loader className="h-4 w-4 mr-2 animate-spin" />
                      Adding...
                    </>
                  ) : (
                    <>
                      <Plus className="h-4 w-4 mr-2" />
                      Add Model
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Models List */}
        <div className="space-y-3">
          {models && models.length > 0 ? (
            models.map((model) => (
              <div
                key={model.id}
                className={`p-4 rounded-lg border-2 transition-colors ${
                  model.is_active ? 'border-primary-200 bg-primary-50' : 'border-gray-200 bg-gray-50'
                }`}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3 mb-2">
                      {getStatusIcon(model.status)}
                      <div>
                        <h3 className="text-sm font-medium text-gray-900">{model.name}</h3>
                        <p className="text-xs text-gray-600">{model.huggingface_id}</p>
                      </div>
                      {model.is_custom && (
                        <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                          Custom
                        </span>
                      )}
                    </div>
                    
                    <div className="flex items-center space-x-4 text-xs text-gray-600 mb-3">
                      <span>Status: {getStatusText(model.status)}</span>
                      <span>Task: {model.task_type}</span>
                      <span>Weight: {model.weight}</span>
                      <span>Categories: {model.categories.join(', ')}</span>
                    </div>

                    {model.status === 'error' && model.error_message && (
                      <div className="mb-3 p-2 bg-danger-50 border border-danger-200 rounded text-xs text-danger-700">
                        Error: {model.error_message}
                      </div>
                    )}

                    {model.status === 'loading' && model.download_progress > 0 && (
                      <div className="mb-3">
                        <div className="flex justify-between text-xs text-gray-600 mb-1">
                          <span>Downloading...</span>
                          <span>{model.download_progress}%</span>
                        </div>
                        <div className="w-full bg-gray-200 rounded-full h-2">
                          <div
                            className="bg-primary-600 h-2 rounded-full transition-all duration-300"
                            style={{ width: `${model.download_progress}%` }}
                          ></div>
                        </div>
                      </div>
                    )}

                    {model.is_active && (
                      <div className="mb-3">
                        <label className="block text-xs font-medium text-gray-700 mb-1">
                          Weight: {model.weight}
                        </label>
                        <input
                          type="range"
                          min="0.1"
                          max="2.0"
                          step="0.1"
                          value={model.weight}
                          onChange={(e) => handleUpdateModelWeight(model.id, parseFloat(e.target.value))}
                          className="w-full"
                        />
                        <div className="flex justify-between text-xs text-gray-500 mt-1">
                          <span>0.1x</span>
                          <span>1.0x</span>
                          <span>2.0x</span>
                        </div>
                      </div>
                    )}
                  </div>

                  <div className="flex items-center space-x-2 ml-4">
                    <button
                      onClick={() => handleToggleModel(model)}
                      className={`p-2 rounded transition-colors ${
                        model.is_active 
                          ? 'text-primary-600 hover:text-primary-700' 
                          : 'text-gray-400 hover:text-gray-600'
                      }`}
                      title={model.is_active ? 'Disable model' : 'Enable model'}
                    >
                      {model.is_active ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
                    </button>
                    
                    {(model.status === 'error' || model.status === 'pending') && (
                      <button
                        onClick={() => handleReloadModel(model.id)}
                        className="p-2 text-gray-400 hover:text-primary-600 transition-colors"
                        title="Reload model"
                        disabled={reloadModelMutation.isPending}
                      >
                        <RefreshCw className={`h-4 w-4 ${reloadModelMutation.isPending ? 'animate-spin' : ''}`} />
                      </button>
                    )}
                    
                    {model.is_custom && (
                      <button
                        onClick={() => handleRemoveModel(model.id)}
                        className="p-2 text-gray-400 hover:text-danger-600 transition-colors"
                        title="Remove model"
                        disabled={removeModelMutation.isPending}
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    )}
                  </div>
                </div>
              </div>
            ))
          ) : (
            <div className="text-center py-8">
              <Brain className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600">No AI models configured</p>
              <p className="text-sm text-gray-500">Add a custom model to enhance content detection</p>
            </div>
          )}
        </div>

        <div className="mt-6 p-4 bg-blue-50 rounded-lg">
          <h4 className="text-sm font-medium text-blue-900 mb-2">Model Configuration Tips</h4>
          <ul className="text-xs text-blue-800 space-y-1">
            <li>• Higher weights give more influence to a model's predictions</li>
            <li>• Multiple models can target the same categories for better accuracy</li>
            <li>• Specialized models (e.g., toxic-comment-model) work better than general ones</li>
            <li>• Models are downloaded automatically when added</li>
          </ul>
        </div>
      </div>

      {/* Sensitivity Settings */}
      <div className="card p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-6">Sensitivity Settings</h2>
        
        <div className="space-y-6">
          {/* Global Sensitivity */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Global Sensitivity
            </label>
            <select className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent">
              <option value="low">Low - Only severe content</option>
              <option value="standard" selected>Standard - Moderate and severe content</option>
              <option value="high">High - All potentially triggering content</option>
              <option value="custom">Custom - Configure per category</option>
            </select>
          </div>

          {/* Category Settings */}
          <div>
            <h3 className="text-sm font-medium text-gray-700 mb-4">Category-Specific Settings</h3>
            <div className="space-y-4">
              {[
                'Sexual Assault',
                'Domestic Violence', 
                'Self Harm',
                'Substance Abuse',
                'Violence',
                'Child Abuse',
                'Eating Disorders',
                'Death/Grief',
                'Medical Content',
                'Discrimination',
                'Animal Cruelty',
                'Body Horror'
              ].map((category) => (
                <div key={category} className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <div>
                    <p className="text-sm font-medium text-gray-900">{category}</p>
                    <p className="text-xs text-gray-600">Detect and flag content related to {category.toLowerCase()}</p>
                  </div>
                  <div className="flex items-center space-x-4">
                    <label className="flex items-center">
                      <input
                        type="checkbox"
                        defaultChecked
                        className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
                      />
                      <span className="ml-2 text-sm text-gray-700">Enabled</span>
                    </label>
                    <select className="px-2 py-1 text-xs border border-gray-300 rounded">
                      <option value="mild">Mild+</option>
                      <option value="moderate" selected>Moderate+</option>
                      <option value="severe">Severe only</option>
                    </select>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="flex justify-end">
            <button className="btn-primary">
              <Save className="h-4 w-4 mr-2" />
              Save Settings
            </button>
          </div>
        </div>
      </div>

      {/* Scanner Configuration */}
      <div className="card p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-6">Scanner Configuration</h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Scan Interval (seconds)
            </label>
            <input
              type="number"
              defaultValue="300"
              min="60"
              max="3600"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            />
            <p className="text-xs text-gray-500 mt-1">How often to check for new files</p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Worker Threads
            </label>
            <input
              type="number"
              defaultValue="4"
              min="1"
              max="16"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            />
            <p className="text-xs text-gray-500 mt-1">Number of parallel processing workers</p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Confidence Threshold
            </label>
            <input
              type="range"
              defaultValue="70"
              min="0"
              max="100"
              className="w-full"
            />
            <div className="flex justify-between text-xs text-gray-500 mt-1">
              <span>0% (Show all)</span>
              <span>70%</span>
              <span>100% (High confidence only)</span>
            </div>
          </div>

          <div className="flex items-center">
            <label className="flex items-center">
              <input
                type="checkbox"
                defaultChecked
                className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
              />
              <span className="ml-2 text-sm text-gray-700">Auto-scan new files</span>
            </label>
          </div>
        </div>

        <div className="flex justify-end mt-6">
          <button className="btn-primary">
            <Save className="h-4 w-4 mr-2" />
            Save Configuration
          </button>
        </div>
      </div>

      {/* Danger Zone */}
      <div className="card p-6 border-danger-200">
        <h2 className="text-lg font-semibold text-danger-900 mb-6 flex items-center">
          <AlertTriangle className="h-5 w-5 mr-2" />
          Danger Zone
        </h2>
        
        <div className="space-y-4">
          <div className="flex items-center justify-between p-4 bg-danger-50 rounded-lg">
            <div>
              <p className="text-sm font-medium text-danger-900">Clear All Scan Results</p>
              <p className="text-xs text-danger-700">Remove all scan results and triggers from database</p>
            </div>
            <button className="btn-danger">
              Clear Results
            </button>
          </div>

          <div className="flex items-center justify-between p-4 bg-danger-50 rounded-lg">
            <div>
              <p className="text-sm font-medium text-danger-900">Reset All Settings</p>
              <p className="text-xs text-danger-700">Restore all settings to default values</p>
            </div>
            <button className="btn-danger">
              Reset Settings
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}