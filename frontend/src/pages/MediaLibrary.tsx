import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { 
  Search, 
  Filter, 
  AlertTriangle, 
  CheckCircle,
  Clock,
  FileText,
  Video
} from 'lucide-react';
import { resultsApi } from '../api';
import { FileWithResults } from '../types';

export default function MediaLibrary() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [severityFilter, setSeverityFilter] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');

  const { data, isLoading, error } = useQuery({
    queryKey: ['results', page, severityFilter, categoryFilter],
    queryFn: () => resultsApi.getResults({
      page,
      limit: 20,
      severity: severityFilter || undefined,
      category: categoryFilter || undefined,
    }),
  });

  const getSeverityIcon = (severity: string) => {
    switch (severity) {
      case 'severe': return <AlertTriangle className="h-4 w-4 text-danger-600" />;
      case 'moderate': return <AlertTriangle className="h-4 w-4 text-warning-600" />;
      case 'mild': return <AlertTriangle className="h-4 w-4 text-warning-400" />;
      default: return <CheckCircle className="h-4 w-4 text-success-600" />;
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'completed': return <CheckCircle className="h-4 w-4 text-success-600" />;
      case 'processing': return <Clock className="h-4 w-4 text-primary-600 animate-spin" />;
      case 'error': return <AlertTriangle className="h-4 w-4 text-danger-600" />;
      default: return <Clock className="h-4 w-4 text-gray-400" />;
    }
  };

  const getFileIcon = (fileType: string) => {
    if (fileType.match(/\.(srt|vtt)$/i)) {
      return <FileText className="h-5 w-5 text-blue-600" />;
    }
    return <Video className="h-5 w-5 text-purple-600" />;
  };

  const filteredFiles = data?.files.filter(file => 
    search === '' || file.filename.toLowerCase().includes(search.toLowerCase())
  );

  if (error) {
    return (
      <div className="text-center py-12">
        <AlertTriangle className="h-12 w-12 text-danger-500 mx-auto mb-4" />
        <h3 className="text-lg font-medium text-gray-900 mb-2">Error loading media library</h3>
        <p className="text-gray-600">Please try refreshing the page</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">Media Library</h1>
        <div className="text-sm text-gray-600">
          {data?.total || 0} files total
        </div>
      </div>

      {/* Filters */}
      <div className="card p-6">
        <div className="flex flex-col sm:flex-row gap-4">
          {/* Search */}
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search files..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-10 pr-4 py-2 w-full border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            />
          </div>

          {/* Severity Filter */}
          <div className="flex items-center space-x-2">
            <Filter className="h-4 w-4 text-gray-400" />
            <select
              value={severityFilter}
              onChange={(e) => setSeverityFilter(e.target.value)}
              className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            >
              <option value="">All Severities</option>
              <option value="severe">Severe</option>
              <option value="moderate">Moderate</option>
              <option value="mild">Mild</option>
              <option value="none">Clear</option>
            </select>
          </div>

          {/* Category Filter */}
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          >
            <option value="">All Categories</option>
            <option value="violence">Violence</option>
            <option value="sexual_assault">Sexual Assault</option>
            <option value="self_harm">Self Harm</option>
            <option value="substance_abuse">Substance Abuse</option>
            <option value="discrimination">Discrimination</option>
            <option value="child_abuse">Child Abuse</option>
          </select>
        </div>
      </div>

      {/* File List */}
      <div className="space-y-4">
        {isLoading ? (
          <div className="text-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto"></div>
            <p className="mt-4 text-gray-600">Loading media files...</p>
          </div>
        ) : filteredFiles?.length === 0 ? (
          <div className="text-center py-12">
            <FileText className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">No files found</h3>
            <p className="text-gray-600">Try adjusting your search or filters</p>
          </div>
        ) : (
          filteredFiles?.map((file: FileWithResults) => {
            const latestResult = file.scan_results?.[0];
            const highestSeverity = latestResult?.highest_severity || 'none';
            const triggerCount = latestResult?.total_triggers || 0;

            return (
              <Link
                key={file.id}
                to={`/media/${file.id}`}
                className="card p-4 hover:shadow-lg transition-shadow block"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-4 flex-1">
                    {getFileIcon(file.file_type)}
                    
                    <div className="flex-1 min-w-0">
                      <h3 className="text-sm font-medium text-gray-900 truncate">
                        {file.filename}
                      </h3>
                      <p className="text-xs text-gray-500 truncate">
                        {file.path}
                      </p>
                      <p className="text-xs text-gray-500">
                        {(file.file_size / 1024 / 1024).toFixed(1)} MB
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center space-x-4">
                    {/* Scan Status */}
                    <div className="flex items-center space-x-1">
                      {getStatusIcon(file.scan_status)}
                      <span className="text-xs text-gray-600 capitalize">
                        {file.scan_status.replace('_', ' ')}
                      </span>
                    </div>

                    {/* Severity & Triggers */}
                    {file.scan_status === 'completed' && (
                      <div className="flex items-center space-x-2">
                        <div className="flex items-center space-x-1">
                          {getSeverityIcon(highestSeverity)}
                          <span className={`severity-${highestSeverity}`}>
                            {highestSeverity}
                          </span>
                        </div>
                        
                        {triggerCount > 0 && (
                          <span className="px-2 py-1 bg-warning-100 text-warning-800 text-xs rounded-full">
                            {triggerCount} trigger{triggerCount !== 1 ? 's' : ''}
                          </span>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              </Link>
            );
          })
        )}
      </div>

      {/* Pagination */}
      {data && data.total_pages > 1 && (
        <div className="flex justify-center space-x-2">
          <button
            onClick={() => setPage(Math.max(1, page - 1))}
            disabled={page === 1}
            className="px-4 py-2 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
          >
            Previous
          </button>
          
          <span className="px-4 py-2 text-gray-600">
            Page {page} of {data.total_pages}
          </span>
          
          <button
            onClick={() => setPage(Math.min(data.total_pages, page + 1))}
            disabled={page === data.total_pages}
            className="px-4 py-2 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}