import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { 
  Home, 
  Folder, 
  Settings, 
  AlertTriangle,
  Play,
  Pause,
  Activity
} from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { scannerApi } from '../api';

interface LayoutProps {
  children: React.ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const location = useLocation();

  const { data: scanStatus } = useQuery({
    queryKey: ['scanStatus'],
    queryFn: scannerApi.getStatus,
    refetchInterval: 5000,
  });

  const navItems = [
    { path: '/', icon: Home, label: 'Dashboard' },
    { path: '/library', icon: Folder, label: 'Media Library' },
    { path: '/settings', icon: Settings, label: 'Settings' },
  ];

  const isActive = (path: string) => location.pathname === path;

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <AlertTriangle className="h-8 w-8 text-primary-600 mr-3" />
              <h1 className="text-xl font-bold text-gray-900">
                Content Warning Scanner
              </h1>
            </div>

            {/* Status indicator */}
            <div className="flex items-center space-x-4">
              {scanStatus && (
                <div className="flex items-center space-x-2 text-sm text-gray-600">
                  <Activity className="h-4 w-4" />
                  <span>Queue: {scanStatus.queue_length}</span>
                  <span className="text-gray-400">|</span>
                  <span>
                    Last scan: {scanStatus.last_activity 
                      ? new Date(scanStatus.last_activity).toLocaleTimeString()
                      : 'Never'
                    }
                  </span>
                </div>
              )}
            </div>
          </div>
        </div>
      </header>

      <div className="flex">
        {/* Sidebar */}
        <nav className="bg-white w-64 min-h-screen shadow-sm">
          <div className="p-6">
            <ul className="space-y-2">
              {navItems.map((item) => {
                const Icon = item.icon;
                return (
                  <li key={item.path}>
                    <Link
                      to={item.path}
                      className={`flex items-center px-4 py-2 rounded-lg transition-colors ${
                        isActive(item.path)
                          ? 'bg-primary-50 text-primary-700 border border-primary-200'
                          : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                      }`}
                    >
                      <Icon className="h-5 w-5 mr-3" />
                      {item.label}
                    </Link>
                  </li>
                );
              })}
            </ul>

            {/* Quick actions */}
            <div className="mt-8 pt-6 border-t border-gray-200">
              <h3 className="text-sm font-medium text-gray-900 mb-3">Quick Actions</h3>
              <div className="space-y-2">
                <button className="flex items-center w-full px-4 py-2 text-sm text-success-700 bg-success-50 rounded-lg hover:bg-success-100 transition-colors">
                  <Play className="h-4 w-4 mr-2" />
                  Start Scan
                </button>
                <button className="flex items-center w-full px-4 py-2 text-sm text-warning-700 bg-warning-50 rounded-lg hover:bg-warning-100 transition-colors">
                  <Pause className="h-4 w-4 mr-2" />
                  Pause Scan
                </button>
              </div>
            </div>
          </div>
        </nav>

        {/* Main content */}
        <main className="flex-1 p-8">
          {children}
        </main>
      </div>
    </div>
  );
}