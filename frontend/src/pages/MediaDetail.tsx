import React from 'react';
import { useParams, Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { 
  ArrowLeft, 
  AlertTriangle, 
  Clock, 
  FileText,
  Video,
  RefreshCw
} from 'lucide-react';
import { resultsApi, triggersApi } from '../api';

export default function MediaDetail() {
  const { fileId } = useParams<{ fileId: string }>();

  const { data: file, isLoading: fileLoading } = useQuery({
    queryKey: ['file', fileId],
    queryFn: () => resultsApi.getFileResult(Number(fileId)),
    enabled: !!fileId,
  });

  const { data: triggers, isLoading: triggersLoading } = useQuery({
    queryKey: ['triggers', fileId],
    queryFn: () => triggersApi.getFileTriggers(Number(fileId)),
    enabled: !!fileId,
  });

  const getFileIcon = (fileType: string) => {
    if (fileType?.match(/\.(srt|vtt)$/i)) {
      return <FileText className="h-8 w-8 text-blue-600" />;
    }
    return <Video className="h-8 w-8 text-purple-600" />;
  };

  const formatTimestamp = (timestamp: string) => {
    const [hours, minutes, seconds] = timestamp.split(':');
    return `${hours}:${minutes}:${parseFloat(seconds).toFixed(1)}`;
  };

  if (fileLoading || triggersLoading) {
    return (
      <div className="text-center py-12">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto"></div>
        <p className="mt-4 text-gray-600">Loading file details...</p>
      </div>
    );
  }

  if (!file) {
    return (
      <div className="text-center py-12">
        <AlertTriangle className="h-12 w-12 text-danger-500 mx-auto mb-4" />
        <h3 className="text-lg font-medium text-gray-900 mb-2">File not found</h3>
        <Link to="/library" className="text-primary-600 hover:text-primary-700">
          Return to library
        </Link>
      </div>
    );
  }

  const latestResult = file.scan_results?.[0];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <Link 
            to="/library"
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <ArrowLeft className="h-5 w-5" />
          </Link>
          <div className="flex items-center space-x-3">
            {getFileIcon(file.file_type)}
            <div>
              <h1 className="text-2xl font-bold text-gray-900">{file.filename}</h1>
              <p className="text-gray-600">{file.path}</p>
            </div>
          </div>
        </div>

        <button className="btn-secondary">
          <RefreshCw className="h-4 w-4 mr-2" />
          Rescan
        </button>
      </div>

      {/* File Info */}
      <div className="card p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">File Information</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-600">File Size</label>
            <p className="text-sm text-gray-900">{(file.file_size / 1024 / 1024).toFixed(1)} MB</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-600">File Type</label>
            <p className="text-sm text-gray-900">{file.file_type}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-600">Last Modified</label>
            <p className="text-sm text-gray-900">
              {new Date(file.last_modified).toLocaleDateString()}
            </p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-600">Scan Status</label>
            <p className={`text-sm capitalize ${
              file.scan_status === 'completed' ? 'text-success-600' :
              file.scan_status === 'processing' ? 'text-primary-600' :
              file.scan_status === 'error' ? 'text-danger-600' :
              'text-gray-600'
            }`}>
              {file.scan_status.replace('_', ' ')}
            </p>
          </div>
        </div>
      </div>

      {/* Scan Results */}
      {latestResult && (
        <div className="card p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Scan Results</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            <div>
              <label className="block text-sm font-medium text-gray-600">Overall Risk Score</label>
              <p className="text-2xl font-bold text-gray-900">
                {latestResult.overall_risk_score.toFixed(1)}
              </p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-600">Highest Severity</label>
              <p className={`text-sm font-medium severity-${latestResult.highest_severity}`}>
                {latestResult.highest_severity}
              </p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-600">Total Triggers</label>
              <p className="text-2xl font-bold text-gray-900">{latestResult.total_triggers}</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-600">Processing Time</label>
              <p className="text-sm text-gray-900">{latestResult.processing_time_ms}ms</p>
            </div>
          </div>
        </div>
      )}

      {/* Triggers Timeline */}
      {triggers && triggers.length > 0 ? (
        <div className="card p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">
            Content Warnings ({triggers.length})
          </h2>
          <div className="space-y-4">
            {triggers.map((trigger) => (
              <div key={trigger.id} className="border-l-4 border-gray-200 pl-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3 mb-2">
                      <span className={`severity-${trigger.severity}`}>
                        {trigger.severity.toUpperCase()}
                      </span>
                      <span className="text-sm font-medium text-gray-900 capitalize">
                        {trigger.category.replace('_', ' ')}
                      </span>
                      <span className="text-sm text-gray-600">
                        {formatTimestamp(trigger.timestamp_start)} - {formatTimestamp(trigger.timestamp_end)}
                      </span>
                      <span className="text-sm text-gray-500">
                        Confidence: {(trigger.confidence_score * 100).toFixed(0)}%
                      </span>
                    </div>
                    
                    <div className="bg-gray-50 p-3 rounded-lg">
                      <p className="text-sm text-gray-900 mb-2">
                        <strong>Content:</strong> "{trigger.subtitle_text}"
                      </p>
                      
                      {trigger.context_before && (
                        <p className="text-xs text-gray-600 mb-1">
                          <strong>Before:</strong> "{trigger.context_before}"
                        </p>
                      )}
                      
                      {trigger.context_after && (
                        <p className="text-xs text-gray-600">
                          <strong>After:</strong> "{trigger.context_after}"
                        </p>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="card p-6">
          <div className="text-center py-8">
            <AlertTriangle className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">No triggers found</h3>
            <p className="text-gray-600">
              {file.scan_status === 'completed' 
                ? 'This file appears to be clear of concerning content.'
                : 'This file has not been scanned yet.'
              }
            </p>
          </div>
        </div>
      )}
    </div>
  );
}