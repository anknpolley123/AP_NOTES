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

export default function App() {
  const [onboardingDone, setOnboardingDone] = useState(true); // Default to true as user "didn't ask for permissions/onboarding"
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [showSplash, setShowSplash] = useState(true);

  useEffect(() => {
    // Show splash for 2.5 seconds
    const splashTimer = setTimeout(() => {
      setShowSplash(false);
    }, 2500);

    // Test Firestore connection
    const testConnection = async () => {
      try {
        // Try reading a dummy public document. If it fails with permission-denied, it might be a config issue.
        // If it fails with not-found, that's actually a SUCCESS in terms of connection!
        await getDocFromServer(doc(db, 'test', 'connection'));
        console.log("Firestore connection verified.");
      } catch (error) {
        if(error instanceof Error) {
          if (error.message.includes('permission-denied')) {
            console.error("Firebase Permission Denied. Please ensure your firestore.rules are deployed.");
          } else if (error.message.includes('the client is offline')) {
            console.error("Firestore connection failed: Client is offline.");
          } else {
             // Other errors (like not-found) are generally fine as they confirm we reached the server
             console.log("Firestore connection test completed (document may not exist, which is fine).");
          }
        }
      }
    };
    testConnection();

    // Handle Auth
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      setAuthLoading(false);
    });
    return () => unsubscribe();
  }, []);

  if (showSplash) {
    return (
      <div className="fixed inset-0 bg-slate-950 flex flex-col items-center justify-center z-[1000] overflow-hidden">
        {/* Animated Background Rings */}
        <div className="absolute w-[800px] h-[800px] border border-blue-500/10 rounded-full animate-[ping_10s_linear_infinite]" />
        <div className="absolute w-[600px] h-[600px] border border-blue-500/5 rounded-full animate-[ping_15s_linear_infinite] delay-1000" />
        
        <div className="relative flex flex-col items-center gap-8 animate-in fade-in zoom-in duration-1000">
          <div className="w-48 h-48 bg-slate-900 rounded-[56px] p-6 shadow-[0_0_80px_rgba(37,99,235,0.2)] border border-blue-500/20 group hover:scale-105 transition-transform duration-700 flex items-center justify-center overflow-hidden">
             <div className="text-blue-500 font-extrabold text-6xl italic animate-pulse select-none">Notes</div>
          </div>
          
          <div className="text-center space-y-2">
            <h1 className="text-4xl font-black italic tracking-tighter text-white uppercase flex items-center gap-3">
              AP_NOTES <span className="not-italic text-sm bg-blue-600 text-white px-3 py-1 rounded-xl shadow-lg shadow-blue-500/30">PRO</span>
            </h1>
            <p className="text-xs font-black text-blue-500 uppercase tracking-[0.6em] opacity-80">Next-Gen AI Workspace</p>
          </div>
        </div>

        <div className="absolute bottom-12 flex flex-col items-center gap-4">
           <div className="w-48 h-1.5 bg-slate-900 rounded-full overflow-hidden border border-white/5">
              <div className="h-full bg-blue-500 rounded-full animate-[loading_2.5s_ease-in-out_infinite]" style={{ width: '40%' }} />
           </div>
           <span className="text-xs font-black text-slate-600 uppercase tracking-widest">Waking Up the Dragon...</span>
        </div>

        <style>{`
          @keyframes loading {
            0% { transform: translateX(-100%); }
            100% { transform: translateX(300%); }
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
