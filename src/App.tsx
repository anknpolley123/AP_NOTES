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

import Logo from './components/Logo';

export default function App() {
  const [onboardingDone, setOnboardingDone] = useState(isOnboardingComplete()); 
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [showSplash, setShowSplash] = useState(true);

  useEffect(() => {
    // Show splash for at least 2 seconds
    const splashTimer = setTimeout(() => {
      console.log("App: Splash timer finished");
      setShowSplash(false);
    }, 4500); // 4.5s splash to give time for UI to settle

    // Test Firestore connection (Non-blocking)
    const testConnection = async () => {
      try {
        console.log("App: Testing DB connection...");
        await Promise.race([
          getDocFromServer(doc(db, "test", "connection")),
          new Promise((_, reject) => setTimeout(() => reject(new Error("Timeout")), 2000))
        ]);
        console.log("App: Auth & DB link OK");
      } catch (error) {
        console.log("App: DB Check complete (possibly offline/restricted)");
      }
    };
    testConnection();

    // Handle Auth
    const authTimeout = setTimeout(() => {
      console.warn("App: Auth timeout reached, forcing entry");
      setAuthLoading(false);
    }, 7000); 

    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      console.log("App: Auth state changed:", currentUser ? "User detected" : "Guest mode");
      setUser(currentUser);
      setAuthLoading(false);
      clearTimeout(authTimeout);
    }, (error) => {
      console.error("App: Auth state error:", error);
      setAuthLoading(false);
      clearTimeout(authTimeout);
    });
    
    return () => {
      clearTimeout(splashTimer);
      clearTimeout(authTimeout);
      unsubscribe();
    };
  }, []);

  if (showSplash) {
    return (
      <div className="fixed inset-0 bg-slate-950 flex flex-col items-center justify-center z-[1000] overflow-hidden p-8 gap-10 text-center select-none">
        <Logo size="xl" />
        
        <div className="space-y-4">
          <h1 className="text-5xl font-black italic tracking-tighter text-white uppercase flex items-center justify-center gap-4 animate-in fade-in slide-in-from-bottom-4 duration-1000">
            AP_NOTES
          </h1>
          <p className="text-sm font-black text-blue-500 uppercase tracking-[0.8em] opacity-80 pl-[0.8em] animate-in fade-in duration-1000 delay-300">AI_WORKSPACE</p>
        </div>

        <div className="mt-10 flex flex-col items-center gap-8">
           <div className="w-64 h-1.5 bg-slate-900 rounded-full overflow-hidden border border-white/5">
              <div className="h-full bg-blue-500 rounded-full animate-[loading_3s_ease-in-out_infinite]" />
           </div>
           
           <div className="flex flex-col items-center gap-2">
             <span className="text-[10px] font-black text-slate-500 uppercase tracking-[0.4em] pl-[0.4em]">System Core v1.2.4_Stable</span>
             <span className="text-[9px] font-bold text-slate-700 uppercase tracking-[0.2em] animate-pulse">Initializing Neural Engine...</span>
           </div>
        </div>

        {/* Fail-safe button after a few seconds */}
        <button 
          onClick={() => setShowSplash(false)}
          className="absolute bottom-12 text-[10px] font-black text-slate-700 uppercase tracking-widest hover:text-blue-500 transition-colors py-2 px-4 border border-white/5 rounded-full"
        >
          Skip Initialization
        </button>

        <style>{`
          @keyframes loading {
            0% { transform: translateX(-100%); }
            50% { transform: translateX(0%); }
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
