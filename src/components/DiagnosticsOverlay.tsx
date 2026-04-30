
import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Zap, Shield, Cpu, Activity, Server, Globe, Lock } from 'lucide-react';

interface DiagnosticsOverlayProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function DiagnosticsOverlay({ isOpen, onClose }: DiagnosticsOverlayProps) {
  const [loadingStep, setLoadingStep] = useState(0);
  const steps = [
    { label: 'Neural Engine initialized', icon: Cpu, status: 'Active v4.2.1' },
    { label: 'OCR Level 4 parity check', icon: Zap, status: '99.85% Precision' },
    { label: 'AES-256 Workspace encryption', icon: Shield, status: 'Active' },
    { label: 'Cloud-Sync mesh network', icon: Globe, status: 'Connected' },
    { label: 'Firebase Realtime relay', icon: Server, status: 'Secure' },
    { label: 'Local safe integrity', icon: Lock, status: 'Verified' },
  ];

  useEffect(() => {
    if (isOpen) {
      setLoadingStep(0);
      const interval = setInterval(() => {
        setLoadingStep(prev => (prev < steps.length ? prev + 1 : prev));
      }, 300);
      return () => clearInterval(interval);
    }
  }, [isOpen]);

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div 
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[1000] bg-slate-950/90 backdrop-blur-md flex items-center justify-center p-6"
        >
          <motion.div 
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="w-full max-w-md bg-slate-900 border border-blue-500/20 rounded-[40px] p-8 shadow-2xl relative overflow-hidden"
          >
            {/* Background scanner effect */}
            <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-blue-500 to-transparent animate-[scroll-y_3s_linear_infinite]" />
            
            <div className="flex items-center gap-4 mb-8">
               <div className="w-12 h-12 bg-blue-600 rounded-2xl flex items-center justify-center text-white shadow-lg shadow-blue-500/20">
                  <Activity className="w-6 h-6" />
               </div>
               <div>
                  <h2 className="text-xl font-black text-white uppercase italic tracking-tight">System Diagnostics</h2>
                  <p className="text-[10px] font-black text-blue-500 uppercase tracking-[0.3em] opacity-60 pl-[0.3em]">Neural Workspace Insight</p>
               </div>
            </div>

            <div className="space-y-4 mb-8">
               {steps.map((step, idx) => (
                 <motion.div 
                   key={idx}
                   initial={{ x: -20, opacity: 0 }}
                   animate={{ x: 0, opacity: idx < loadingStep ? 1 : 0.3 }}
                   className="flex items-center justify-between p-3 bg-slate-800/50 rounded-2xl border border-white/5"
                 >
                    <div className="flex items-center gap-3">
                       <step.icon className={`w-4 h-4 ${idx < loadingStep ? 'text-blue-500' : 'text-slate-600'}`} />
                       <span className="text-[11px] font-bold text-slate-300 uppercase tracking-widest">{step.label}</span>
                    </div>
                    {idx < loadingStep ? (
                      <span className="text-[9px] font-black text-blue-500 uppercase bg-blue-500/10 px-2 py-0.5 rounded-md">{step.status}</span>
                    ) : (
                      <div className="w-2 h-2 bg-slate-700 rounded-full animate-pulse" />
                    )}
                 </motion.div>
               ))}
            </div>

            <button 
              onClick={onClose}
              className="w-full py-4 bg-blue-600 text-white font-black uppercase text-xs tracking-[0.3em] rounded-2xl shadow-xl shadow-blue-500/30 active:scale-95 transition-all"
            >
              Close Diagnostics
            </button>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
