
import React, { useEffect, useState, useMemo } from 'react';
import Fuse from 'fuse.js';
import { 
  Plus, Camera as CameraIcon, Search, LayoutGrid, Download, 
  Network, Mic, Settings, FolderClosed, MoreVertical, TrendingUp,
  Menu, Trash2, Share2, FileClock, X, ChevronRight, PenLine, FileText, Lock,
  Zap, Save, Pin, Cloud, FileSpreadsheet, Presentation, FileCode, Sparkles, RefreshCw
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import NoteItem from '../components/NoteItem';
import { getNotes, Note, getFolders, Folder, createFolder, getDeletedNotes, softDeleteNote, saveNote, togglePinNote, moveNoteToFolder } from '../services/storage';
import { exportAllNotesToPDF } from '../services/pdfService';
import { smartSearch, recommendFolders } from '../services/aiService';
import { auth, db, loginWithGoogle } from '../services/firebaseService';
import { collection, query, where, onSnapshot, doc, updateDoc } from 'firebase/firestore';
import { onAuthStateChanged } from 'firebase/auth';

export default function HomeScreen() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [cloudNotes, setCloudNotes] = useState<Note[]>([]);
  const [folders, setFolders] = useState<Folder[]>([]);
  const [deletedCount, setDeletedCount] = useState(0);
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearchVisible, setIsSearchVisible] = useState(false);
  const [joinId, setJoinId] = useState('');
  const [selectedFolderId, setSelectedFolderId] = useState<string | null>(null);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isSmartSearchLoading, setIsSmartSearchLoading] = useState(false);
  const [isOrganizing, setIsOrganizing] = useState(false);
  const [smartSearchResultIds, setSmartSearchResultIds] = useState<string[] | null>(null);
  const [selectionMode, setSelectionMode] = useState(false);
  const [selectedNotes, setSelectedNotes] = useState<string[]>([]);
  const [quickNoteText, setQuickNoteText] = useState('');
  const [isQuickSaving, setIsQuickSaving] = useState(false);
  const navigate = useNavigate();

  const [user, setUser] = useState(auth.currentUser);

  useEffect(() => {
    loadData();
    const unsubscribeAuth = onAuthStateChanged(auth, (u) => {
      setUser(u);
    });
    return () => unsubscribeAuth();
  }, []);

  useEffect(() => {
    if (user) {
      // Query notes where user is owner
      const qOwner = query(collection(db, 'notes'), where('ownerId', '==', user.uid));
      const unsubscribeOwner = onSnapshot(qOwner, (snapshot) => {
        const ownerNotes = snapshot.docs.map(doc => doc.data() as Note);
        setCloudNotes(prev => {
           const others = prev.filter(n => n.ownerId !== user.uid);
           return [...others, ...ownerNotes];
        });
      }, (err) => console.error("Owner Notes sync error:", err));
      
      // Query notes where user is collaborator
      const qCollab = query(collection(db, 'notes'), where('collaborators', 'array-contains', user.uid));
      const unsubscribeCollab = onSnapshot(qCollab, (snapshot) => {
        const collabNotes = snapshot.docs.map(doc => doc.data() as Note);
        setCloudNotes(prev => {
           const others = prev.filter(n => !n.collaborators?.includes(user.uid));
           return [...others, ...collabNotes];
        });
      }, (err) => console.error("Collab Notes sync error:", err));
      
      return () => {
        unsubscribeOwner();
        unsubscribeCollab();
      };
    } else {
      setCloudNotes([]);
    }
  }, [user]);

  const loadData = async () => {
    const [notesData, foldersData, deletedData] = await Promise.all([
      getNotes(), 
      getFolders(),
      getDeletedNotes()
    ]);
    setNotes(notesData);
    setFolders(foldersData);
    setDeletedCount(deletedData.length);
  };

  const handleQuickSave = async () => {
    if (!quickNoteText.trim()) return;
    setIsQuickSaving(true);
    try {
      await saveNote(quickNoteText, `Fast Note ${new Date().toLocaleTimeString()}`);
      setQuickNoteText('');
      await loadData();
    } catch (e) {
      console.error(e);
    } finally {
      setIsQuickSaving(false);
    }
  };

  const handleExportArchive = () => {
    if (confirm("Export entire archive to one PDF?")) {
      exportAllNotesToPDF(notes);
    }
  };

  const handleCreateFolder = async () => {
    const name = prompt("Enter folder name:");
    if (name) {
      await createFolder(name);
      loadData();
    }
  };

  const toggleSelection = (id: string) => {
    setSelectedNotes(prev => 
      prev.includes(id) ? prev.filter(n => n !== id) : [...prev, id]
    );
  };

  const handleBulkDelete = async () => {
    if (confirm(`Move ${selectedNotes.length} notes to recycle bin?`)) {
      for (const id of selectedNotes) {
        await softDeleteNote(id);
      }
      setSelectedNotes([]);
      setSelectionMode(false);
      loadData();
    }
  };

  const handleBulkPin = async (pin: boolean) => {
    for (const id of selectedNotes) {
      const note = allNotesMerged.find(n => n.id === id);
      if (note && note.pinned !== pin) {
        await togglePinNote(id);
      }
    }
    setSelectedNotes([]);
    setSelectionMode(false);
    loadData();
  };

  const handleTogglePin = async (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    if (id.startsWith('collab_')) {
       const note = cloudNotes.find(n => n.id === id);
       if (note) {
          // Cloud update would be here, but for simplicity we use the existing service logic if updated to handle both
          togglePinNote(id); // I should update togglePinNote to handle collab
       }
    } else {
       await togglePinNote(id);
    }
    await loadData();
  };

  const allNotesMerged = [...notes, ...cloudNotes];
  
  const handleSmartSearch = async () => {
    if (!searchQuery.trim()) return;
    setIsSmartSearchLoading(true);
    try {
      const ids = await smartSearch(searchQuery, allNotesMerged.map(n => ({ id: n.id, title: n.title, text: n.text })));
      setSmartSearchResultIds(ids);
    } catch (err) {
      console.error(err);
    } finally {
      setIsSmartSearchLoading(false);
    }
  };

  const handleSmartOrganize = async () => {
    if (allNotesMerged.length < 2) {
      alert("Add more notes for AI to analyze organization!");
      return;
    }
    
    setIsOrganizing(true);
    try {
      // Show processing notification if possible or just use button state
      const recommendations = await recommendFolders(allNotesMerged.map(n => ({ id: n.id, title: n.title, text: n.text })));
      
      if (!recommendations || recommendations.length === 0) {
        alert("The AI couldn't find a better way to organize these notes yet.");
        return;
      }

      if (confirm(`AI suggests creating folders and moving ${recommendations.length} notes. Proceed?`)) {
          const currentFolders = await getFolders();
          for (const rec of recommendations) {
            let folder = currentFolders.find(f => f.name.toLowerCase() === rec.suggestedFolderName.toLowerCase());
            if (!folder) {
              folder = await createFolder(rec.suggestedFolderName);
              currentFolders.push(folder);
            }
            
            // If local note
            if (notes.some(n => n.id === rec.noteId)) {
              await moveNoteToFolder(rec.noteId, folder.id);
            } else {
              // If cloud note
              const noteRef = doc(db, 'notes', rec.noteId);
              await updateDoc(noteRef, { folderId: folder.id });
            }
          }
          await loadData();
          alert("Notes magically organized into folders!");
        }
    } catch (e) {
      console.error(e);
      alert("Failed to organize notes. Please try again.");
    } finally {
      setIsOrganizing(false);
    }
  };

  const filteredNotes = useMemo(() => {
    let result = allNotesMerged;

    if (smartSearchResultIds) {
      result = result.filter(n => smartSearchResultIds.includes(n.id));
      return result;
    }

    if (selectedFolderId) {
      result = result.filter(n => n.folderId === selectedFolderId);
    }

    if (searchQuery.trim()) {
      const fuse = new Fuse(result, {
        keys: [
          { name: 'title', weight: 0.7 },
          { name: 'text', weight: 0.3 },
          { name: 'tags', weight: 0.5 }
        ],
        threshold: 0.4,
        includeScore: true,
      });
      result = fuse.search(searchQuery).map(r => r.item);
    } else {
      result = result.sort((a, b) => {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        return b.createdAt - a.createdAt;
      });
    }

    return result;
  }, [allNotesMerged, searchQuery, selectedFolderId]);

  return (
    <Layout 
      title={selectionMode ? `${selectedNotes.length} selected` : "All notes"} 
      subtitle={selectionMode ? "" : new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}
      actions={
        selectionMode ? (
          <button onClick={() => { setSelectionMode(false); setSelectedNotes([]); }} className="text-blue-500 font-bold uppercase text-[10px]">Cancel</button>
        ) : (
          <div className="flex gap-2">
             <button onClick={() => navigate('/knowledge')} className="p-2 text-[var(--text-muted)] hover:text-blue-500 transition-colors">
                <Network className="w-5 h-5" />
             </button>
             <button onClick={() => navigate('/pdf-workspace')} className="p-2 text-[var(--text-muted)] hover:text-blue-500 transition-colors">
                <Download className="w-5 h-5" />
             </button>
             <button onClick={() => setSelectionMode(true)} className="p-2 text-[var(--text-muted)]">
                <LayoutGrid className="w-5 h-5" />
             </button>
          </div>
        )
      }
       hugeText={selectionMode ? "" : "ALL\nNOTES"}
      leftAction={
        <button onClick={() => setIsSidebarOpen(true)} className="p-2 -ml-2 text-[var(--text-main)]">
           <Menu className="w-6 h-6" />
        </button>
      }
    >
      <div className="mb-8 overflow-x-auto pb-2 scrollbar-hide">
        <div className="flex gap-3 px-1 min-w-max">
           {[
             { name: 'Word', icon: <FileText className="w-5 h-5" />, color: 'bg-blue-600', type: 'word' },
             { name: 'Excel', icon: <FileSpreadsheet className="w-5 h-5" />, color: 'bg-green-600', type: 'excel' },
             { name: 'PPT', icon: <Presentation className="w-5 h-5" />, color: 'bg-orange-600', type: 'ppt' },
             { name: 'Draft', icon: <FileCode className="w-5 h-5" />, color: 'bg-purple-600', type: 'draft' },
             { name: 'Scan', icon: <CameraIcon className="w-5 h-5" />, color: 'bg-slate-800', type: 'scan' },
           ].map((btn) => (
             <button 
               key={btn.name}
               onClick={() => btn.type === 'scan' ? navigate('/ocr') : navigate('/editor', { state: { type: btn.type } })}
               className="flex flex-col items-center gap-2 group"
             >
                <div className={`w-14 h-14 rounded-2xl ${btn.color} flex items-center justify-center text-white shadow-lg shadow-${btn.color}/20 group-hover:scale-105 transition-all`}>
                   {btn.icon}
                </div>
                <span className="text-[8px] font-black uppercase text-[var(--text-muted)] tracking-widest">{btn.name}</span>
             </button>
           ))}
        </div>
      </div>
      {/* Sidebar Drawer */}
      {isSidebarOpen && (
        <>
          <div 
            className="fixed inset-0 bg-black/40 backdrop-blur-sm z-[100] animate-in fade-in duration-300"
            onClick={() => setIsSidebarOpen(false)}
          />
          <div className="fixed top-0 left-0 bottom-0 w-[85%] max-w-[320px] bg-[var(--bg-app)] z-[101] shadow-2xl animate-in slide-in-from-left duration-300 flex flex-col">
            <div className="p-8 flex items-center justify-between">
               <div className="w-16 h-16 rounded-2xl bg-blue-600 flex items-center justify-center p-3 text-white font-black text-xl italic shadow-xl shadow-blue-500/20">
                  <Zap className="w-8 h-8" strokeWidth={3} />
               </div>
               <button onClick={() => navigate('/settings')} className="p-3 text-[var(--text-muted)] hover:bg-slate-800 rounded-2xl relative group">
                  <Settings className="w-8 h-8" />
                  <div className="absolute top-2 right-2 w-3 h-3 bg-blue-500 rounded-full animate-pulse border-2 border-slate-900" />
               </button>
            </div>
            
            <div className="px-8 pb-4 mb-6 border-b border-[var(--border-app)]">
               <div className="bg-blue-600/10 border border-blue-500/20 p-4 rounded-3xl flex items-center justify-between group active:scale-95 cursor-pointer" onClick={() => navigate('/settings')}>
                  <div className="flex items-center gap-3">
                     <Sparkles className="w-5 h-5 text-blue-500" />
                     <span className="text-[12px] font-black uppercase text-blue-500 tracking-widest">Active Plan</span>
                  </div>
                  <span className="text-[10px] font-black bg-blue-500 text-white px-3 py-1 rounded-lg uppercase tracking-tighter shadow-lg shadow-blue-500/30">PRO_OCR</span>
               </div>
            </div>
            
            <div className="flex-1 px-4 space-y-1">
              <button 
                onClick={() => { setSelectedFolderId(null); setIsSidebarOpen(false); }}
                className={`w-full flex items-center gap-8 p-6 rounded-[32px] transition-all ${!selectedFolderId ? 'bg-blue-600/10 text-blue-500' : 'text-[var(--text-main)]'}`}
              >
                <FileText className="w-8 h-8" />
                <span className="font-black text-2xl flex-1 text-left uppercase tracking-tight">All notes</span>
              </button>
              
              <button 
                onClick={() => { window.dispatchEvent(new CustomEvent('open-gemini-chat')); setIsSidebarOpen(false); }}
                className="w-full flex items-center gap-8 p-6 rounded-[32px] text-[var(--text-main)] hover:bg-blue-600/10 transition-all font-black group"
              >
                <div className="w-12 h-12 rounded-2xl bg-blue-500/10 flex items-center justify-center group-hover:bg-blue-500 transition-colors">
                  <Sparkles className="w-7 h-7 text-blue-500 group-hover:text-white" />
                </div>
                <span className="flex-1 text-left text-2xl uppercase tracking-tight">Ask Gemini AI</span>
              </button>

              <button className="w-full flex items-center gap-4 p-4 rounded-2xl text-[var(--text-main)] opacity-50 cursor-not-allowed">
                <Share2 className="w-5 h-5" />
                <span className="font-bold flex-1 text-left uppercase text-[10px]">Shared notes</span>
                <span className="text-[10px] bg-slate-800 px-2 py-0.5 rounded-md font-black">BETA</span>
              </button>

              <button 
                onClick={() => { navigate('/cloud-storage'); setIsSidebarOpen(false); }}
                className="w-full flex items-center gap-3 p-4 text-[var(--text-muted)] hover:text-[var(--text-main)] hover:bg-[var(--bg-button)] rounded-2xl transiton-all"
              >
                <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center group-hover:bg-blue-500 transition-colors">
                  <Cloud className="w-5 h-5 text-blue-500 group-hover:text-white" />
                </div>
                <span className="text-[10px] font-black uppercase tracking-widest">Cloud Storage</span>
              </button>

              <button 
                onClick={() => { navigate('/recycle-bin'); setIsSidebarOpen(false); }}
                className="w-full flex items-center gap-4 p-4 rounded-2xl text-[var(--text-main)] hover:bg-slate-800"
              >
                <Trash2 className="w-5 h-5" />
                <span className="font-bold flex-1 text-left">Recycle bin</span>
                <span className="text-sm font-bold opacity-40">{deletedCount}</span>
              </button>

              <div className="my-4 border-t border-[var(--border-app)] border-dashed mx-4" />

              <div className="flex items-center justify-between px-4 mb-2">
                 <div className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest flex items-center gap-2">
                    <FolderClosed className="w-4 h-4" /> Folders
                 </div>
              </div>

              {folders.map(folder => (
                <button 
                  key={folder.id}
                  onClick={() => { setSelectedFolderId(folder.id); setIsSidebarOpen(false); }}
                  className={`w-full flex items-center justify-between p-4 rounded-2xl transition-all ${selectedFolderId === folder.id ? 'bg-blue-600/10 text-blue-500' : 'text-[var(--text-main)]'}`}
                >
                  <span className="font-bold">{folder.name}</span>
                  <ChevronRight className="w-4 h-4 opacity-30" />
                </button>
              ))}

              <div className="my-4 border-t border-[var(--border-app)] border-dashed mx-4" />

              <div className="px-4 space-y-3">
                 <div className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest flex items-center gap-2">
                    <PenLine className="w-4 h-4" /> Join Collaboration
                 </div>
                 <div className="flex gap-2">
                    <input 
                      type="text" 
                      placeholder="NOTE_ID..."
                      className="flex-1 bg-[var(--bg-button)] p-3 rounded-xl border border-[var(--border-app)] text-[10px] font-bold text-[var(--text-main)] uppercase"
                      value={joinId}
                      onChange={(e) => setJoinId(e.target.value)}
                    />
                    <button 
                      onClick={() => {
                        if (joinId.trim()) navigate(`/editor/${joinId.trim()}`);
                      }}
                      className="w-10 h-10 bg-blue-600 text-white rounded-xl flex items-center justify-center hover:bg-blue-700 transition-all border border-blue-500/20"
                    >
                      <Plus className="w-4 h-4" />
                    </button>
                 </div>
                 {!auth.currentUser && (
                    <button 
                       onClick={loginWithGoogle}
                       className="w-full py-3 bg-[var(--bg-button)] text-[var(--text-main)] rounded-xl text-[8px] font-black uppercase tracking-widest border border-[var(--border-app)] hover:border-blue-500/30 transition-all"
                    >
                       Sign in to join
                    </button>
                 )}
              </div>

              <button 
                onClick={handleCreateFolder}
                className="w-full mt-4 bg-[var(--bg-button)] py-4 rounded-2xl text-[10px] font-black uppercase tracking-widest text-[var(--text-main)]"
              >
                Manage folders
              </button>
            </div>
          </div>
        </>
      )}

      <div className="flex-1 flex flex-col">
        <div className="flex items-center justify-between mb-6">
          <div className="text-[14px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em] flex items-center gap-2">
             <TrendingUp className="w-4 h-4 text-blue-500" /> Insight Active
          </div>
          <div className="flex gap-4">
             <button
               onClick={handleSmartOrganize}
               disabled={isOrganizing}
               className="p-2 bg-purple-500/10 text-purple-600 rounded-xl hover:bg-purple-500 hover:text-white transition-all flex items-center gap-2"
             >
               {isOrganizing ? <RefreshCw className="w-4 h-4 animate-spin" /> : <LayoutGrid className="w-4 h-4" />}
               <span className="text-[10px] font-black uppercase tracking-widest hidden sm:inline">Magic Organize</span>
             </button>
             <button
               onClick={() => window.dispatchEvent(new CustomEvent('open-gemini-chat'))}
               className="p-2 bg-blue-500/10 text-blue-500 rounded-xl hover:bg-blue-500 hover:text-white transition-all flex items-center gap-2"
             >
               <Sparkles className="w-4 h-4" />
               <span className="text-[10px] font-black uppercase tracking-widest hidden sm:inline">Ask AI</span>
             </button>
             {isSearchVisible ? (
               <div className="flex items-center gap-2 bg-slate-100 px-3 py-1.5 rounded-full animate-in slide-in-from-right-4">
                  <Search className="w-4 h-4 text-slate-400" />
                  <input 
                    type="text"
                    value={searchQuery}
                    onChange={(e) => {
                      setSearchQuery(e.target.value);
                      if (!e.target.value) setSmartSearchResultIds(null);
                    }}
                    onKeyDown={(e) => e.key === 'Enter' && handleSmartSearch()}
                    placeholder="Ask AI or search..."
                    autoFocus
                    className="bg-transparent border-none outline-none text-[10px] font-bold text-slate-700 uppercase w-32 sm:w-48"
                  />
                  <button 
                    onClick={handleSmartSearch}
                    disabled={isSmartSearchLoading}
                    className={`p-1 rounded-md transition-colors ${smartSearchResultIds ? 'bg-blue-500 text-white' : 'text-blue-500 hover:bg-blue-50'}`}
                  >
                    {isSmartSearchLoading ? <RefreshCw className="w-3 h-3 animate-spin" /> : <Sparkles className="w-3 h-3" />}
                  </button>
                  <button onClick={() => { setIsSearchVisible(false); setSearchQuery(''); setSmartSearchResultIds(null); }}>
                    <X className="w-4 h-4 text-slate-400" />
                  </button>
               </div>
             ) : (
               <Search onClick={() => setIsSearchVisible(true)} className="w-5 h-5 text-[var(--text-muted)] cursor-pointer hover:text-blue-500 transition-colors" />
             )}
             <TrendingUp className="w-5 h-5 text-[var(--text-muted)] cursor-pointer" />
             <Download onClick={handleExportArchive} className="w-5 h-5 text-[var(--text-muted)] cursor-pointer hover:text-blue-500 transition-colors" />
          </div>
        </div>

        {/* Fast Note Input */}
        {!selectionMode && (
          <div className="mb-8 group">
            <div className={`flex items-center gap-3 bg-[var(--bg-card)] border-2 transition-all p-2 rounded-3xl ${quickNoteText ? 'border-blue-500/50 shadow-lg shadow-blue-500/10' : 'border-[var(--border-app)]'}`}>
              <div className={`w-10 h-10 rounded-2xl flex items-center justify-center transition-colors ${quickNoteText ? 'bg-blue-600 text-white' : 'bg-slate-800 text-[var(--text-muted)]'}`}>
                <Zap className="w-5 h-5" />
              </div>
              <input 
                type="text" 
                placeholder="FAST NOTE: Type and save instantly..." 
                className="flex-1 bg-transparent border-none outline-none text-sm font-bold text-[var(--text-main)] placeholder:text-[var(--text-muted)] uppercase tracking-tight"
                value={quickNoteText}
                onChange={(e) => setQuickNoteText(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleQuickSave()}
              />
              {quickNoteText && (
                <button 
                  onClick={handleQuickSave}
                  disabled={isQuickSaving}
                  className="bg-blue-600 text-white px-4 py-2 rounded-2xl text-[10px] font-black uppercase tracking-widest hover:bg-blue-700 transition-all disabled:opacity-50"
                >
                  {isQuickSaving ? '...' : <Save className="w-4 h-4" />}
                </button>
              )}
            </div>
          </div>
        )}

        {filteredNotes.length === 0 ? (
          <div className="flex-1 flex flex-col items-center justify-center py-20 text-center">
          <div className="text-[12px] font-black text-[var(--text-main)] uppercase tracking-tighter mb-4 italic">No notes created yet</div>
          <p className="text-base font-bold text-[var(--text-muted)] uppercase tracking-widest max-w-[240px]">
            Tap the button below to start your first intelligent workspace.
          </p>
          </div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4 mb-8">
            {filteredNotes.slice(0, 10).map(note => (
              <div 
                key={note.id}
                onClick={() => selectionMode ? toggleSelection(note.id) : navigate(`/editor/${note.id}`)}
                className={`app-card p-5 h-48 bg-[var(--bg-card)] border-2 transition-all cursor-pointer relative ${selectionMode && selectedNotes.includes(note.id) ? 'border-orange-500 scale-[0.98]' : 'border-[var(--border-app)]'}`}
              >
                 {selectionMode && (
                   <div className={`absolute top-4 right-4 w-5 h-5 rounded-full border-2 flex items-center justify-center transition-all ${selectedNotes.includes(note.id) ? 'bg-orange-500 border-orange-500' : 'border-[var(--text-muted)]'}`}>
                      {selectedNotes.includes(note.id) && <X className="w-3 h-3 text-white" />}
                   </div>
                 )}
                 {!selectionMode && (
                   <button 
                     onClick={(e) => handleTogglePin(e, note.id)}
                     className={`absolute top-4 right-4 p-2 rounded-xl transition-all ${note.pinned ? 'text-blue-500 bg-blue-500/10' : 'text-[var(--text-muted)] hover:text-blue-500 hover:bg-slate-800'}`}
                   >
                     <Pin className={`w-4 h-4 ${note.pinned ? 'fill-current' : ''}`} />
                   </button>
                 )}
                 <div className="text-[10px] font-black text-[var(--text-muted)] uppercase mb-2">
                    {new Date(note.createdAt).toLocaleDateString()}
                 </div>
                 <h3 className="text-sm font-black text-[var(--text-main)] uppercase tracking-tight line-clamp-2 mb-1 pr-6">
                    {note.title}
                 </h3>
                 <p className="text-[10px] text-[var(--text-muted)] line-clamp-4 leading-relaxed">
                    {note.text}
                 </p>
                 <div className="absolute bottom-4 right-4 opacity-5 pointer-events-none">
                    <div className="text-blue-500 font-black text-4xl italic -rotate-12">NOTES</div>
                 </div>
              </div>
            ))}
          </div>
        )}

        <div className="space-y-3 pb-40">
          {filteredNotes.length > 10 && (
            <>
              <div className="text-[12px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-4 px-2">Archive List</div>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                 {filteredNotes.slice(10).map(note => (
                   <div 
                     key={note.id}
                     onClick={() => selectionMode ? toggleSelection(note.id) : navigate(`/editor/${note.id}`)}
                     className={selectionMode && selectedNotes.includes(note.id) ? 'opacity-60 scale-[0.98] transition-all' : ''}
                   >
                     <NoteItem note={note} onTogglePin={handleTogglePin} />
                   </div>
                 ))}
              </div>
            </>
          )}
        </div>
      </div>

      <div className="fixed bottom-32 right-8 flex items-center gap-6 z-30">
        <button 
          onClick={() => navigate('/ocr')}
          className="bg-[var(--bg-button)] text-[var(--text-main)] w-16 h-16 rounded-[24px] shadow-2xl flex items-center justify-center hover:scale-105 active:scale-95 transition-all border border-[var(--border-app)]"
          id="ocr-fab"
        >
          <CameraIcon className="w-7 h-7 text-blue-500" />
        </button>
        <button 
          onClick={() => navigate('/editor')}
          className="bg-blue-600 text-white w-16 h-16 rounded-[24px] shadow-2xl flex items-center justify-center hover:scale-105 active:scale-95 transition-all"
          id="add-fab"
        >
          <PenLine className="w-7 h-7" />
        </button>
      </div>

      {selectionMode && selectedNotes.length > 0 && (
        <div className="fixed bottom-0 left-0 right-0 h-20 bg-[var(--bg-card)] border-t border-[var(--border-app)] flex items-center justify-center gap-8 px-4 z-[60] animate-in slide-in-from-bottom duration-300 pb-[var(--safe-bottom)]">
          <div onClick={() => handleBulkPin(true)} className="flex flex-col items-center gap-1 text-[var(--text-muted)] hover:text-blue-500 cursor-pointer transition-colors pointer-events-auto">
             <Pin className="w-5 h-5" />
             <span className="text-[8px] font-black uppercase tracking-widest">Pin</span>
          </div>
          <div onClick={() => handleBulkPin(false)} className="flex flex-col items-center gap-1 text-[var(--text-muted)] hover:text-blue-500 cursor-pointer transition-colors pointer-events-auto">
             <Pin className="w-5 h-5 opacity-40" />
             <span className="text-[8px] font-black uppercase tracking-widest">Unpin</span>
          </div>
          <div className="flex flex-col items-center gap-1 text-[var(--text-muted)] hover:text-blue-500 cursor-pointer transition-colors">
             <Share2 className="w-5 h-5" />
             <span className="text-[8px] font-black uppercase tracking-widest">Share</span>
          </div>
          <div onClick={handleBulkDelete} className="flex flex-col items-center gap-1 text-red-500 hover:text-red-600 cursor-pointer transition-colors pointer-events-auto">
             <Trash2 className="w-5 h-5" />
             <span className="text-[8px] font-black uppercase tracking-widest">Delete</span>
          </div>
        </div>
      )}
    </Layout>
  );
}
