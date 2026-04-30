import React, { useState, useEffect } from 'react';
import { HashRouter as Router, Routes, Route } from 'react-router-dom';
import HomeScreen from './screens/HomeScreen';
import EditorScreen from './screens/EditorScreen';
import OCRScreen from './screens/OCRScreen';
import KnowledgeScreen from './screens/KnowledgeScreen';
import PdfWorkspaceScreen from './screens/PdfWorkspaceScreen';
import SettingsScreen from './screens/SettingsScreen';
import RecycleBinScreen from './screens/RecycleBinScreen';
import CloudStorageScreen from './screens/CloudStorageScreen';
import PermissionOnboarding from './components/PermissionOnboarding';
import AIAssistant from './components/AIAssistant';
import { isOnboardingComplete } from './services/storage';
import { auth, db } from './services/firebaseService';
import { onAuthStateChanged, User } from 'firebase/auth';
import { doc, getDocFromServer } from 'firebase/firestore';
import { Bot, Zap } from 'lucide-react';

export default function App() {
  const [onboardingDone, setOnboardingDone] = useState(true); 
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [showSplash, setShowSplash] = useState(true);

  useEffect(() => {
    // Show splash for at least 1.5 seconds
    const splashTimer = setTimeout(() => {
      setShowSplash(false);
    }, 1500);

    // Test Firestore connection
    const testConnection = async () => {
      try {
        await getDocFromServer(doc(db, 'test', 'connection'));
        console.log("Firestore connection verified.");
      } catch (error) {
        console.log("Firestore connection test completed.");
      }
    };
    testConnection();

    // Handle Auth
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      setAuthLoading(false);
    });
    return () => {
      clearTimeout(splashTimer);
      unsubscribe();
    };
  }, []);

  if (showSplash) {
    return (
      <div className="fixed inset-0 bg-slate-950 flex flex-col items-center justify-center z-[1000] overflow-hidden p-8">
        {/* Animated Background Rings - Larger */}
        <div className="absolute w-[1200px] h-[1200px] border border-blue-500/10 rounded-full animate-[ping_10s_linear_infinite]" />
        <div className="absolute w-[1000px] h-[1000px] border border-blue-500/5 rounded-full animate-[ping_15s_linear_infinite] delay-1000" />
        
        <div className="relative flex flex-col items-center gap-10 animate-in fade-in zoom-in duration-1000">
          <div className="w-56 h-56 bg-slate-900 rounded-[64px] p-8 shadow-[0_0_100px_rgba(37,99,235,0.3)] border-2 border-blue-500/30 flex items-center justify-center overflow-hidden group">
             <div className="relative">
               <Zap className="w-32 h-32 text-blue-500 animate-pulse" strokeWidth={3} />
               <div className="absolute inset-0 flex items-center justify-center">
                  <span className="text-white font-black text-4xl italic mt-2">AP</span>
               </div>
             </div>
          </div>
          
          <div className="text-center space-y-4">
            <h1 className="text-5xl font-black italic tracking-tighter text-white uppercase flex items-center justify-center gap-4">
              AP_NOTES <span className="not-italic text-sm bg-blue-600 text-white px-4 py-1.5 rounded-2xl shadow-xl shadow-blue-500/40">PRO</span>
            </h1>
            <p className="text-sm font-black text-blue-500 uppercase tracking-[0.8em] opacity-80 pl-[0.8em]">Next-Gen AI Workspace</p>
          </div>
        </div>

        <div className="absolute bottom-20 flex flex-col items-center gap-6">
           <div className="w-64 h-2 bg-slate-900 rounded-full overflow-hidden border border-white/5">
              <div className="h-full bg-blue-500 rounded-full animate-[loading_2s_ease-in-out_infinite]" />
           </div>
           <div className="flex flex-col items-center gap-1">
             <span className="text-sm font-black text-slate-400 uppercase tracking-[0.3em] pl-[0.3em]">Waking Up the Dragon</span>
             <span className="text-[10px] font-bold text-slate-600 uppercase tracking-widest">Powering Up Neural Engine...</span>
           </div>
        </div>

        {/* Emergency skip if stuck */}
        <button 
          onClick={() => setShowSplash(false)}
          className="absolute bottom-6 text-[10px] font-bold text-slate-700 uppercase tracking-widest hover:text-slate-500 transition-colors"
        >
          Skip Loading
        </button>

        <style>{`
          @keyframes loading {
            0% { transform: translateX(-100%); }
            100% { transform: translateX(200%); }
          }
        `}</style>
      </div>
    );
  }

  if (!onboardingDone) {
    return <PermissionOnboarding onComplete={() => setOnboardingDone(true)} />;
  }

  if (authLoading) {
    return (
      <div className="fixed inset-0 bg-slate-950 flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-blue-500/20 border-t-blue-500 rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <Router>
      <div className="bg-gray-100 min-h-screen font-sans selection:bg-blue-100">
        <Routes>
          <Route path="/" element={<HomeScreen />} />
          <Route path="/editor" element={<EditorScreen />} />
          <Route path="/editor/:id" element={<EditorScreen />} />
          <Route path="/ocr" element={<OCRScreen />} />
          <Route path="/knowledge" element={<KnowledgeScreen />} />
          <Route path="/pdf-workspace" element={<PdfWorkspaceScreen />} />
          <Route path="/settings" element={<SettingsScreen />} />
          <Route path="/recycle-bin" element={<RecycleBinScreen />} />
          <Route path="/cloud-storage" element={<CloudStorageScreen />} />
        </Routes>
        <AIAssistant />
      </div>
    </Router>
  );
}
