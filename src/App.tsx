import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
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
  const [onboardingDone, setOnboardingDone] = useState(isOnboardingComplete());
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);

  useEffect(() => {
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
