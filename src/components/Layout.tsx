
import React from 'react';
import { motion } from 'motion/react';
import { ChevronLeft, Wifi, Battery, Signal, LayoutGrid, Network, Download, Settings, Camera, PenLine } from 'lucide-react';
import { useNavigate, useLocation } from 'react-router-dom';

interface LayoutProps {
  children: React.ReactNode;
  title: string;
  subtitle?: string;
  showBack?: boolean;
  actions?: React.ReactNode;
  hugeText?: string;
  leftAction?: React.ReactNode;
  hideNav?: boolean;
}

export default function Layout({ children, title, subtitle, showBack, actions, hugeText, leftAction, hideNav }: LayoutProps) {
  const navigate = useNavigate();
  const location = useLocation();

  const navItems = [
    { label: 'Dash', icon: LayoutGrid, path: '/' },
    { label: 'Graph', icon: Network, path: '/knowledge' },
    { label: 'PDF', icon: Download, path: '/pdf-workspace' },
    { label: 'Cloud', icon: Settings, path: '/cloud-storage' },
  ];

  return (
    <div className="min-h-screen bg-[var(--bg-app)] flex flex-col font-sans overflow-hidden">
      <div className="w-full flex-1 bg-[var(--bg-card)] shadow-2xl relative overflow-hidden flex flex-col transition-colors duration-300">
        {/* Huge Decorative Background Text */}
        <div className="huge-bg-text">
          {hugeText || "NOTES\nSCAN"}
        </div>

        {/* Dragon Watermark */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-80 h-80 opacity-[0.03] pointer-events-none select-none z-0 flex items-center justify-center">
          <div className="text-blue-500 font-black text-6xl italic -rotate-12">NOTES</div>
        </div>

        {/* Status Bar simulation - only on web */}
        {!window.Capacitor && (
          <div className="h-10 px-8 flex justify-between items-center text-[10px] font-bold text-[var(--text-muted)] z-20">
            <span>{new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
            <div className="flex gap-2 items-center">
              <Signal className="w-3 h-3" />
              <Wifi className="w-3 h-3" />
              <Battery className="w-3 h-3 rotate-90" />
              <span>100%</span>
            </div>
          </div>
        )}

        {/* Header Content */}
        <header className={`relative z-20 px-8 pt-4 pb-2 ${window.Capacitor ? 'pt-[var(--safe-top)]' : ''}`}>
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-2">
              {leftAction ? leftAction : showBack && (
                <button 
                  onClick={() => navigate(-1)}
                  className="p-1 -ml-1 text-[var(--text-muted)] hover:text-[var(--text-main)] transition-colors"
                  id="back-button"
                >
                  <ChevronLeft className="w-6 h-6" />
                </button>
              )}
              <div className="flex items-center gap-3 text-left">
                {!leftAction && !showBack && (
                  <div className="w-10 h-10 overflow-hidden rounded-xl bg-slate-900 p-1.5 flex items-center justify-center shadow-[0_5px_15px_rgba(37,99,235,0.4)] border border-blue-500/50 group hover:scale-105 transition-transform cursor-pointer">
                    <div className="text-blue-500 font-black text-[10px] italic">AP</div>
                  </div>
                )}
                <div>
                  <h1 className="text-[20px] font-black tracking-tighter text-blue-500 uppercase italic leading-none" id="page-title">
                    AP_NOTES <span className="not-italic text-[10px] bg-blue-500 text-white px-2 py-0.5 rounded-md align-middle shadow-lg shadow-blue-500/30">PRO</span>
                  </h1>
                  <p className="text-[8px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em] mt-0.5 opacity-60">{title || subtitle || 'Professional Suite'}</p>
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2" id="header-actions">
              {actions}
            </div>
          </div>
          {subtitle && (
            <div className="text-[10px] font-extrabold text-blue-500 uppercase tracking-[0.2em]">
              {subtitle}
            </div>
          )}
        </header>

        {/* Main Content Scroll Area */}
        <main className="flex-1 overflow-y-auto px-8 relative z-10 scrollbar-hide">
          <motion.div
             key={location.pathname}
             initial={{ opacity: 0, scale: 0.98 }}
             animate={{ opacity: 1, scale: 1 }}
             exit={{ opacity: 0, scale: 0.98 }}
             transition={{ duration: 0.4, ease: [0.23, 1, 0.32, 1] }}
          >
            {children}
          </motion.div>
        </main>

        {/* Bottom Nav Section */}
        {!hideNav && (
          <nav className="h-20 bg-[var(--bg-card)] border-t border-[var(--border-app)] flex items-center justify-center gap-10 px-8 z-20 pb-[var(--safe-bottom)]">
            {navItems.map((item) => (
              <button
                key={item.path}
                onClick={() => navigate(item.path)}
                className={`flex flex-col items-center gap-1 transition-all ${
                  location.pathname === item.path ? 'text-blue-500 scale-110' : 'text-[var(--text-muted)]'
                }`}
              >
                <item.icon className={`w-5 h-5 ${location.pathname === item.path ? 'fill-current/10' : ''}`} />
                <span className="text-[8px] font-black uppercase tracking-widest">{item.label}</span>
                {location.pathname === item.path && (
                  <motion.div 
                    layoutId="active-navIndicator"
                    className="w-1 h-1 bg-blue-500 rounded-full mt-1"
                  />
                )}
              </button>
            ))}
          </nav>
        )}

        {/* Dynamic Footer indicator (mobile like) - only show if no nav or on specific screen */}
        {hideNav && (
          <div className="h-6 w-full flex justify-center items-end pb-2 opacity-20 z-20">
            <div className="w-32 h-1 bg-white rounded-full"></div>
          </div>
        )}
      </div>
    </div>
  );
}
