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
      setShowSplash(false);
    }, 2000);

    // Test Firestore connection (Non-blocking)
    const testConnection = async () => {
      try {
        // Only run test if we are not on a very restricted network or something
        await Promise.race([
          getDocFromServer(doc(db, 'test', 'connection')),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 3000))
        ]);
        console.log("Health check: OK");
      } catch (error) {
        console.log("Health check: Complete (possibly offline)");
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
      <div className="fixed inset-0 bg-slate-950 flex flex-col items-center justify-center z-[1000] overflow-hidden p-8 gap-10 text-center">
        <Logo size="xl" />
        
        <div className="space-y-4">
          <h1 className="text-5xl font-black italic tracking-tighter text-white uppercase flex items-center justify-center gap-4">
            AP_NOTES
          </h1>
          <p className="text-sm font-black text-blue-500 uppercase tracking-[0.8em] opacity-80 pl-[0.8em]">AI_WORKSPACE</p>
        </div>

        <div className="mt-10 flex flex-col items-center gap-6">
           <div className="w-60 h-1.5 bg-slate-900 rounded-full overflow-hidden border border-white/5">
              <div className="h-full bg-blue-500 rounded-full animate-[loading_2s_ease-in-out_infinite]" />
           </div>
           <div className="flex flex-col items-center gap-1">
             <span className="text-[10px] font-black text-slate-500 uppercase tracking-[0.4em] pl-[0.4em]">System Core v1.2.4_Stable</span>
           </div>
        </div>

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
