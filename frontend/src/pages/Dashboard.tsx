import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { 
  Files, 
  AlertTriangle, 
  CheckCircle, 
  Clock,
  TrendingUp,
  Activity
} from 'lucide-react';
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell
} from 'recharts';
import { statsApi, scannerApi } from '../api';

const SEVERITY_COLORS = {
  none: '#6b7280',
  mild: '#f59e0b',
  moderate: '#f97316',
  severe: '#dc2626'
};

export default function Dashboard() {
  const { data: overviewStats } = useQuery({
    queryKey: ['stats', 'overview'],
    queryFn: statsApi.getOverview,
  });

  const { data: categoryStats } = useQuery({
    queryKey: ['stats', 'categories'],
    queryFn: statsApi.getCategories,
  });

  const { data: timelineStats } = useQuery({
    queryKey: ['stats', 'timeline'],
    queryFn: statsApi.getTimeline,
  });

  const { data: scanStatus } = useQuery({
    queryKey: ['scanStatus'],
    queryFn: scannerApi.getStatus,
    refetchInterval: 5000,
  });

  // Process category stats for pie chart
  const categoryPieData = categoryStats?.reduce((acc, stat) => {
    const existingCategory = acc.find(item => item.name === stat.category);
    if (existingCategory) {
      existingCategory.value += stat.count;
    } else {
      acc.push({ name: stat.category, value: stat.count });
    }
    return acc;
  }, [] as Array<{ name: string; value: number }>);

  const statCards = [
    {
      title: 'Total Files',
      value: overviewStats?.total_files || 0,
      icon: Files,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
    },
    {
      title: 'Scanned Files',
      value: overviewStats?.scanned_files || 0,
      icon: CheckCircle,
      color: 'text-success-600',
      bgColor: 'bg-success-50',
    },
    {
      title: 'Total Triggers',
      value: overviewStats?.total_triggers || 0,
      icon: AlertTriangle,
      color: 'text-warning-600',
      bgColor: 'bg-warning-50',
    },
    {
      title: 'Avg Risk Score',
      value: overviewStats?.average_risk_score?.toFixed(1) || '0.0',
      icon: TrendingUp,
      color: 'text-primary-600',
      bgColor: 'bg-primary-50',
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <div className="flex items-center space-x-2 text-sm text-gray-600">
          <Activity className="h-4 w-4" />
          <span>
            Queue: {scanStatus?.queue_length || 0} files
          </span>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map((stat) => {
          const Icon = stat.icon;
          return (
            <div key={stat.title} className="card p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">{stat.title}</p>
                  <p className="text-2xl font-bold text-gray-900">{stat.value}</p>
                </div>
                <div className={`p-3 rounded-lg ${stat.bgColor}`}>
                  <Icon className={`h-6 w-6 ${stat.color}`} />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Scan Status */}
      {scanStatus && (
        <div className="card p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Scan Status</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {scanStatus.status_counts.map((status) => (
              <div key={status.scan_status} className="text-center">
                <div className="text-2xl font-bold text-gray-900">{status.count}</div>
                <div className="text-sm text-gray-600 capitalize">
                  {status.scan_status.replace('_', ' ')}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Timeline Chart */}
        <div className="card p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">
            Scanning Activity (Last 30 Days)
          </h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={timelineStats}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis 
                  dataKey="date" 
                  tick={{ fontSize: 12 }}
                  tickFormatter={(date) => new Date(date).toLocaleDateString()}
                />
                <YAxis tick={{ fontSize: 12 }} />
                <Tooltip 
                  labelFormatter={(date) => new Date(date).toLocaleDateString()}
                />
                <Bar dataKey="files_scanned" fill="#3b82f6" name="Files Scanned" />
                <Bar dataKey="triggers_found" fill="#f59e0b" name="Triggers Found" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Category Pie Chart */}
        <div className="card p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">
            Triggers by Category
          </h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={categoryPieData}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  label={({ name, percent }) => 
                    `${name} ${(percent * 100).toFixed(0)}%`
                  }
                >
                  {categoryPieData?.map((entry, index) => (
                    <Cell 
                      key={`cell-${index}`} 
                      fill={Object.values(SEVERITY_COLORS)[index % Object.values(SEVERITY_COLORS).length]} 
                    />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="card p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Recent Activity</h2>
        <div className="text-sm text-gray-600">
          {scanStatus?.last_activity ? (
            <p>Last scan completed: {new Date(scanStatus.last_activity).toLocaleString()}</p>
          ) : (
            <p>No recent scanning activity</p>
          )}
        </div>
      </div>
    </div>
  );
}